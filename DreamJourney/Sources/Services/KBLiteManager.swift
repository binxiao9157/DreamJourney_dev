import Foundation

// MARK: - KBLiteManager

/// Lite 版知识库中央管理器 — 单例
///
/// 职责：
/// 1. JSON 持久化（kb_graph.json）
/// 2. LLM 知识提取（调用 DeepSeekService）
/// 3. 实体合并去重
/// 4. 关键词检索
/// 5. 组装上下文文本（供 system_prompt 注入）
final class KBLiteManager {

    // MARK: - Singleton

    static let shared = KBLiteManager()

    private init() { load() }

    // MARK: - Constants

    /// 每类实体数量上限（超出后不再新增，防止 JSON 文件膨胀）
    private let maxPeople = 200
    private let maxPlaces = 100
    private let maxEvents = 100
    private let maxFacts = 500
    private static let genericKinshipNames: Set<String> = [
        "爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
        "爸爸", "妈妈", "父亲", "母亲", "老伴", "老公", "老婆",
        "哥哥", "姐姐", "弟弟", "妹妹", "叔叔", "阿姨", "舅舅", "姑姑",
        "儿子", "女儿", "孙子", "孙女", "老师", "师傅", "同学", "战友"
    ]

    // MARK: - Properties

    /// 内存中的知识图谱
    private(set) var graph = KBLiteGraph()

    /// 读写锁，保护 graph 的并发访问
    private let graphLock = NSLock()

    /// 是否正在进行提取（避免并发）
    private var isExtracting = false

    /// 提取队列（串行）
    private let extractQueue = DispatchQueue(label: "com.dreamjourney.kblite.extract")

    /// 后端同步队列（串行，保存后防抖同步）
    private let backendSyncQueue = DispatchQueue(label: "com.dreamjourney.kblite.backendSync")
    private var pendingBackendSyncWorkItem: DispatchWorkItem?
    private var didAttemptBackendBootstrapForUserId: String?
    private var isFetchingBackendSnapshot = false

    /// 是否已输出过容量警告
    private var didWarnCapacity = false

    // MARK: - Thread-Safe Graph Access

    /// 线程安全地读取 graph
    func readGraph<T>(_ block: (KBLiteGraph) -> T) -> T {
        graphLock.lock()
        defer { graphLock.unlock() }
        return block(graph)
    }

    /// 线程安全地修改 graph（修改后自动保存并发送通知）
    func writeGraph(_ block: (inout KBLiteGraph) -> Void) {
        graphLock.lock()
        block(&graph)
        graphLock.unlock()
        save()
    }

    func reloadForCurrentUser(bootstrapFromBackend: Bool = true) {
        pendingBackendSyncWorkItem?.cancel()
        didAttemptBackendBootstrapForUserId = nil
        isFetchingBackendSnapshot = false

        graphLock.lock()
        graph = KBLiteGraph()
        graphLock.unlock()

        load()
        if bootstrapFromBackend {
            bootstrapFromBackendIfNeeded()
        }
    }

    func clearForLoggedOutUser() {
        pendingBackendSyncWorkItem?.cancel()
        didAttemptBackendBootstrapForUserId = nil
        isFetchingBackendSnapshot = false

        graphLock.lock()
        graph = KBLiteGraph()
        graphLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
        }
    }

    // MARK: - File Path

    private var graphFilePath: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kbDir = docs.appendingPathComponent("knowledge_base")
        try? FileManager.default.createDirectory(at: kbDir, withIntermediateDirectories: true)
        let userId = UserManager.shared.currentUser?.id ?? "default"
        let userFile = kbDir.appendingPathComponent("kb_graph_\(userId).json")

        // 向后兼容：旧文件存在但用户专属文件不存在时，自动迁移
        let legacyFile = kbDir.appendingPathComponent("kb_graph.json")
        if !FileManager.default.fileExists(atPath: userFile.path) &&
            FileManager.default.fileExists(atPath: legacyFile.path) {
            do {
                try FileManager.default.copyItem(at: legacyFile, to: userFile)
                print("[KBLite] 已将旧知识库迁移到用户专属文件: \(userFile.lastPathComponent)")
            } catch {
                print("[KBLite] 旧知识库迁移失败: \(error.localizedDescription)")
            }
        }

        return userFile
    }

    // MARK: - Persistence

    private func save(scheduleBackendSync shouldScheduleBackendSync: Bool = true) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        graph.lastUpdated = Date()
        guard let data = try? encoder.encode(graph) else {
            print("[KBLite] ❌ JSON 编码失败")
            return
        }
        do {
            try data.write(to: graphFilePath, options: .atomic)
            print("[KBLite] 💾 知识库已保存: \(graph.people.count)人, \(graph.places.count)地, \(graph.events.count)事, \(graph.facts.count)实")
        } catch {
            print("[KBLite] ❌ 保存失败: \(error.localizedDescription)")
        }
        // 同步到 App Group 共享容器（供 Widget 读取）
        writeToAppGroup()
        // 通知 UI 数据已更新
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
        }
        if shouldScheduleBackendSync {
            scheduleBackendSync()
        }
    }

    private func scheduleBackendSync() {
#if MEMORY_PRIVACY_INTEGRATION_VERIFY
        return
#else
        guard DreamJourneyBackendClient.shared.isConfigured else { return }
        guard let userId = UserManager.shared.currentUser?.id else { return }

        backendSyncQueue.async { [weak self] in
            guard let self else { return }
            self.pendingBackendSyncWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.syncToBackend(userId: userId)
            }
            self.pendingBackendSyncWorkItem = workItem
            self.backendSyncQueue.asyncAfter(deadline: .now() + 2.0, execute: workItem)
        }
#endif
    }

    private func syncToBackend(userId: String) {
#if MEMORY_PRIVACY_INTEGRATION_VERIFY
        return
#else
        guard let graphJSON = exportJSON(surface: .backendSync), !graphJSON.isEmpty else {
            return
        }
        DreamJourneyBackendClient.shared.syncKnowledgeBase(userId: userId, graphJSON: graphJSON) { result in
            switch result {
            case .success(let response):
                print("[KBLite] ☁️ 后端同步完成: \(response.counts.people)人, \(response.counts.places)地, \(response.counts.events)事, \(response.counts.facts)实")
            case .failure(let error):
                print("[KBLite] ⚠️ 后端同步失败（不影响本地）: \(error.localizedDescription)")
            }
        }
#endif
    }

    func bootstrapFromBackendIfNeeded(force: Bool = false, completion: @escaping (Bool) -> Void = { _ in }) {
#if MEMORY_PRIVACY_INTEGRATION_VERIFY
        completion(false)
#else
        guard DreamJourneyBackendClient.shared.isConfigured else {
            completion(false)
            return
        }
        guard let userId = UserManager.shared.currentUser?.id else {
            completion(false)
            return
        }

        backendSyncQueue.async { [weak self] in
            guard let self else { return }
            guard force || self.didAttemptBackendBootstrapForUserId != userId else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            guard !self.isFetchingBackendSnapshot else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.didAttemptBackendBootstrapForUserId = userId
            self.isFetchingBackendSnapshot = true

            DreamJourneyBackendClient.shared.fetchKnowledgeBaseSnapshot(userId: userId) { [weak self] result in
                guard let self else { return }
                self.backendSyncQueue.async {
                    self.isFetchingBackendSnapshot = false
                }
                switch result {
                case .success(let response):
                    let didApply = self.applyRemoteSnapshotIfUseful(response.graph)
                    DispatchQueue.main.async { completion(didApply) }
                case .failure(let error):
                    print("[KBLite] ⚠️ 后端知识库快照拉取失败（不影响本地）: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(false) }
                }
            }
        }
#endif
    }

    @discardableResult
    func applyRemoteSnapshotIfUseful(_ remoteSnapshot: KBLiteGraph) -> Bool {
        let remote = sanitizedIncomingGraph(remoteSnapshot)
        guard !remote.people.isEmpty || !remote.places.isEmpty || !remote.events.isEmpty || !remote.facts.isEmpty else {
            return false
        }

        var didChange = false
        graphLock.lock()
        didChange = mergeRemotePeople(remote.people) || didChange
        didChange = mergeRemotePlaces(remote.places) || didChange
        didChange = mergeRemoteEvents(remote.events) || didChange
        didChange = mergeRemoteFacts(remote.facts) || didChange
        if remote.sessionCount > graph.sessionCount {
            graph.sessionCount = remote.sessionCount
            didChange = true
        }
        graphLock.unlock()

        if didChange {
            save(scheduleBackendSync: false)
            print("[KBLite] ☁️ 已合并后端知识库快照")
        }
        return didChange
    }

    private func mergeRemotePeople(_ remotePeople: [KBPerson]) -> Bool {
        var didChange = false
        for remote in remotePeople {
            guard Self.shouldPersistPerson(
                name: remote.name,
                aliases: remote.aliases,
                traits: remote.traits,
                briefBio: remote.briefBio
            ) else { continue }

            if let idx = graph.people.firstIndex(where: {
                $0.id == remote.id ||
                    ($0.name == remote.name &&
                     KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: remote.privacyMetadata))
            }) {
                var person = graph.people[idx]
                if appendUnique(remote.aliases.filter { $0 != person.name }, to: &person.aliases) { didChange = true }
                if appendUnique(remote.traits, to: &person.traits) { didChange = true }
                if appendUnique(remote.relatedPersonIds, to: &person.relatedPersonIds) { didChange = true }
                if appendUnique(remote.sourceSessionIds, to: &person.sourceSessionIds) { didChange = true }
                if person.relation == nil, let relation = remote.relation {
                    person.relation = relation
                    didChange = true
                }
                if person.briefBio == nil, let briefBio = remote.briefBio {
                    person.briefBio = briefBio
                    didChange = true
                }
                if remote.updatedAt > person.updatedAt {
                    person.updatedAt = remote.updatedAt
                    didChange = true
                }
                graph.people[idx] = person
            } else if graph.people.count < maxPeople {
                graph.people.append(remote)
                didChange = true
            }
        }
        return didChange
    }

    private func mergeRemotePlaces(_ remotePlaces: [KBPlace]) -> Bool {
        var didChange = false
        for remote in remotePlaces where remote.name.count >= 2 {
            if let idx = graph.places.firstIndex(where: {
                $0.id == remote.id ||
                    ($0.name == remote.name &&
                     KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: remote.privacyMetadata))
            }) {
                var place = graph.places[idx]
                if place.category == nil, let category = remote.category {
                    place.category = category
                    didChange = true
                }
                if place.description == nil, let description = remote.description {
                    place.description = description
                    didChange = true
                }
                if place.latitude == nil, let latitude = remote.latitude {
                    place.latitude = latitude
                    didChange = true
                }
                if place.longitude == nil, let longitude = remote.longitude {
                    place.longitude = longitude
                    didChange = true
                }
                if appendUnique(remote.relatedPersonIds, to: &place.relatedPersonIds) { didChange = true }
                if appendUnique(remote.sourceSessionIds, to: &place.sourceSessionIds) { didChange = true }
                graph.places[idx] = place
            } else if graph.places.count < maxPlaces {
                graph.places.append(remote)
                didChange = true
            }
        }
        return didChange
    }

    private func mergeRemoteEvents(_ remoteEvents: [KBEvent]) -> Bool {
        var didChange = false
        for remote in remoteEvents where !remote.title.isEmpty {
            if let idx = graph.events.firstIndex(where: {
                $0.id == remote.id ||
                    ($0.title == remote.title &&
                     $0.year == remote.year &&
                     KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: remote.privacyMetadata))
            }) {
                var event = graph.events[idx]
                if event.description == nil, let description = remote.description {
                    event.description = description
                    didChange = true
                }
                if event.year == nil, let year = remote.year {
                    event.year = year
                    didChange = true
                }
                if event.month == nil, let month = remote.month {
                    event.month = month
                    didChange = true
                }
                if event.locationId == nil, let locationId = remote.locationId {
                    event.locationId = locationId
                    didChange = true
                }
                if event.memoirId == nil, let memoirId = remote.memoirId {
                    event.memoirId = memoirId
                    didChange = true
                }
                if appendUnique(remote.participantIds, to: &event.participantIds) { didChange = true }
                if appendUnique(remote.mediaIds, to: &event.mediaIds) { didChange = true }
                if appendUnique(remote.sourceSessionIds, to: &event.sourceSessionIds) { didChange = true }
                graph.events[idx] = event
            } else if graph.events.count < maxEvents {
                graph.events.append(remote)
                didChange = true
            }
        }
        return didChange
    }

    private func mergeRemoteFacts(_ remoteFacts: [KBFact]) -> Bool {
        var didChange = false
        for remote in remoteFacts where remote.statement.count >= 4 {
            if let idx = graph.facts.firstIndex(where: {
                $0.id == remote.id ||
                    ($0.statement == remote.statement &&
                     KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: remote.privacyMetadata))
            }) {
                var fact = graph.facts[idx]
                if fact.confidence != remote.confidence, fact.confidence != "confirmed" {
                    fact.confidence = remote.confidence
                    didChange = true
                }
                if appendUnique(remote.relatedPersonIds, to: &fact.relatedPersonIds) { didChange = true }
                if appendUnique(remote.relatedPlaceIds, to: &fact.relatedPlaceIds) { didChange = true }
                if appendUnique(remote.relatedEventIds, to: &fact.relatedEventIds) { didChange = true }
                if appendUnique(remote.sourceSessionIds, to: &fact.sourceSessionIds) { didChange = true }
                graph.facts[idx] = fact
            } else if graph.facts.count < maxFacts {
                graph.facts.append(remote)
                didChange = true
            }
        }
        return didChange
    }

    @discardableResult
    private func appendUnique<T: Equatable>(_ values: [T], to target: inout [T]) -> Bool {
        var didChange = false
        for value in values where !target.contains(value) {
            target.append(value)
            didChange = true
        }
        return didChange
    }

    /// 将事件数据写入 App Group 共享容器，供 Widget Extension 读取
    private func writeToAppGroup() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.dreamjourney.shared"
        ) else { return }
        let widgetFile = containerURL.appendingPathComponent("kb_widget_data.json")
        let widgetGraph = KBLitePrivacyScopePolicy.sanitizedGraph(graph, for: .widget)
        // 只写入 events（Widget 只需要事件数据）
        let widgetEvents = widgetGraph.events.map { e -> [String: Any] in
            var dict: [String: Any] = [
                "id": e.id,
                "title": e.title
            ]
            dict["description"] = e.description ?? ""
            dict["year"] = e.year ?? 0
            dict["month"] = e.month ?? 0
            return dict
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ["events": widgetEvents]) else { return }
        try? data.write(to: widgetFile, options: .atomic)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: graphFilePath.path) else {
            print("[KBLite] 📂 知识库文件不存在，使用空图谱")
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: graphFilePath)
            var loaded = try decoder.decode(KBLiteGraph.self, from: data)
            let removedLegacySeedCount = removeLegacyOrLowQualityEntities(from: &loaded)
            graph = loaded
            if removedLegacySeedCount > 0 {
                save()
                print("[KBLite] removed legacy seed entities: \(removedLegacySeedCount)")
            }
            print("[KBLite] 📂 已加载知识库: v\(loaded.version), \(loaded.people.count)人, \(loaded.places.count)地, \(loaded.events.count)事, \(loaded.facts.count)实, 共\(loaded.sessionCount)次会话")

            // 后台预热语义缓存
            DispatchQueue.global(qos: .utility).async {
                KBLiteSemanticSearch.shared.warmCache(
                    people: self.graph.people,
                    places: self.graph.places,
                    events: self.graph.events,
                    facts: self.graph.facts
                )
            }
        } catch {
            print("[KBLite] ⚠️ 知识库加载失败: \(error.localizedDescription)，使用空图谱")
            // 备份损坏文件
            let backupPath = graphFilePath.appendingPathExtension("corrupted")
            try? FileManager.default.moveItem(at: graphFilePath, to: backupPath)
            print("[KBLite] 📦 已备份损坏文件到: \(backupPath.lastPathComponent)")
        }
    }

    func sanitizedIncomingGraph(_ incoming: KBLiteGraph) -> KBLiteGraph {
        var sanitized = incoming
        _ = removeLegacyOrLowQualityEntities(from: &sanitized)
        return sanitized
    }

    private func removeLegacyOrLowQualityEntities(from graph: inout KBLiteGraph) -> Int {
        let beforeCount = graph.people.count + graph.places.count + graph.events.count + graph.facts.count
        let roadshowPeople = Set(graph.people.filter { $0.id.hasPrefix("roadshow_") }.map(\.id))
        let roadshowPlaces = Set(graph.places.filter { $0.id.hasPrefix("roadshow_") }.map(\.id))
        let roadshowEvents = Set(graph.events.filter { $0.id.hasPrefix("roadshow_") }.map(\.id))
        let genericPeople = Set(graph.people.filter(Self.isGenericKinshipOnly).map(\.id))
        let legacyRoadshowPeople = Set(graph.people.filter { Self.isLegacyRoadshowText($0.searchableText) }.map(\.id))
        let legacyRoadshowPlaces = Set(graph.places.filter { Self.isLegacyRoadshowText($0.searchableText) }.map(\.id))
        let legacyRoadshowEvents = Set(graph.events.filter { Self.isLegacyRoadshowText($0.searchableText) }.map(\.id))
        let removedPeople = roadshowPeople.union(genericPeople).union(legacyRoadshowPeople)
        let removedPlaces = roadshowPlaces.union(legacyRoadshowPlaces)
        let removedEvents = roadshowEvents.union(legacyRoadshowEvents)

        graph.people.removeAll { person in
            person.id.hasPrefix("roadshow_") ||
                Self.isGenericKinshipOnly(person) ||
                Self.isLegacyRoadshowText(person.searchableText)
        }
        graph.places.removeAll { place in
            place.id.hasPrefix("roadshow_") ||
                Self.isLegacyRoadshowText(place.searchableText) ||
                place.relatedPersonIds.contains(where: { removedPeople.contains($0) })
        }
        graph.events.removeAll { event in
            event.id.hasPrefix("roadshow_") ||
                Self.isLegacyRoadshowText(event.searchableText) ||
                event.locationId.map { removedPlaces.contains($0) } == true ||
                event.participantIds.contains(where: { removedPeople.contains($0) })
        }
        graph.facts.removeAll { fact in
            fact.id.hasPrefix("roadshow_") ||
                Self.isLegacyRoadshowText(fact.statement) ||
                fact.relatedPersonIds.contains(where: { removedPeople.contains($0) }) ||
                fact.relatedEventIds.contains(where: { removedEvents.contains($0) })
        }

        let afterCount = graph.people.count + graph.places.count + graph.events.count + graph.facts.count
        return beforeCount - afterCount
    }

    static func isGenericKinshipDisplayName(_ name: String) -> Bool {
        genericKinshipNames.contains(normalizedEntityName(name))
    }

    private static func isGenericKinshipOnly(_ person: KBPerson) -> Bool {
        isGenericKinshipDisplayName(person.name)
    }

    private static func isLegacyRoadshowText(_ text: String) -> Bool {
        let markers = [
            "路演", "roadshow", "外滩留下的合影记忆",
            "路演样例", "路演数据", "路演占位"
        ]
        return markers.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func shouldPersistPerson(
        name: String,
        aliases: [String],
        traits: [String],
        briefBio: String?
    ) -> Bool {
        let normalizedName = normalizedEntityName(name)
        guard !normalizedName.isEmpty else { return false }
        if isGenericKinshipDisplayName(normalizedName) {
            return false
        }
        return true
    }

    private static func normalizedEntityName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedQuickExtractEntity(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }


    // MARK: - Public API: Stats

    /// 获取知识库统计
    var stats: String {
        "\(graph.people.count)人 · \(graph.places.count)地 · \(graph.events.count)事 · \(graph.facts.count)实 · 共\(graph.sessionCount)次会话"
    }

    /// 是否为空
    var isEmpty: Bool {
        graph.people.isEmpty && graph.places.isEmpty && graph.events.isEmpty && graph.facts.isEmpty
    }

    // MARK: - Public API: Knowledge Extraction

    /// 从对话 transcript 提取知识（异步，不阻塞 UI）
    /// - Parameters:
    ///   - turns: 本轮对话记录
    ///   - sessionId: 会话序号
    ///   - completion: 提取完成后回调（主线程），参数为新增实体数
    func extractFromTranscript(
        turns: [ConversationTurn],
        sessionId: Int,
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        guard !turns.isEmpty else {
            print("[KBLite] ⚠️ 空 transcript，跳过提取")
            completion(0)
            return
        }
        let localTurns = KBLitePrivacyScopePolicy.localExtractableTurns(from: turns)
        let remoteTurns = KBLitePrivacyScopePolicy.remoteExtractableTurns(from: turns)
        let localPrivacyMetadata = KBLitePrivacyScopePolicy.derivedEntityMetadata(from: localTurns)
        let remotePrivacyMetadata = KBLitePrivacyScopePolicy.derivedEntityMetadata(from: remoteTurns)
        let previouslyProcessedSessionCount = graph.sessionCount

        // 提取频率控制：每 3 次会话才触发一次 LLM 提取（节省成本）
        // 第 1 次、第 10 次、以及距离上次提取超过 24 小时的会话强制执行
        let shouldForceExtract = previouslyProcessedSessionCount == 0
            || (sessionId - previouslyProcessedSessionCount >= 3)
            || (Date().timeIntervalSince(graph.lastUpdated) > 86400)

        // 确定性本地沉淀先落库，确保明确姓名、地点、年份和事件不依赖 LLM 是否抽到。
        let deterministicCount = quickExtract(
            turns: localTurns,
            sessionId: sessionId,
            privacyMetadata: localPrivacyMetadata
        )
        if deterministicCount > 0 {
            graph.sessionCount = max(graph.sessionCount, sessionId)
            save()
        }

        guard shouldForceExtract else {
            print("[KBLite] ⏭️ 提取频率控制：跳过会话#\(sessionId)，上次提取#\(previouslyProcessedSessionCount)")
            if deterministicCount == 0 {
                graph.sessionCount = max(graph.sessionCount, sessionId)
                save()
            }
            completion(deterministicCount)
            return
        }

        guard !remoteTurns.isEmpty else {
            print("[KBLite] 🔒 无可远端提取 transcript，跳过 LLM，仅执行本地快速提取")
            if deterministicCount == 0 {
                graph.sessionCount = max(graph.sessionCount, sessionId)
                save()
            }
            completion(deterministicCount)
            return
        }

        extractQueue.async { [weak self] in
            guard let self = self else { return }

            guard !self.isExtracting else {
                print("[KBLite] ⏳ 上一次提取尚未完成，跳过")
                DispatchQueue.main.async { completion(0) }
                return
            }

            self.isExtracting = true
            print("[KBLite] 🔍 开始 LLM 知识提取 (会话#\(sessionId), \(remoteTurns.count)/\(turns.count)轮可远端)")

            // 组装 transcript 文本
            let transcript = remoteTurns.map { t in
                let role = t.role == "user" ? "长辈" : "寻梦环游"
                return "[\(role)]: \(t.text)"
            }.joined(separator: "\n")

            // 构建已有知识摘要（减少重复提取）
            let existingSummary = self.buildExistingSummary(surface: .remoteExtraction)

            // 构造提取 prompt
            let prompt = self.buildExtractionPrompt(transcript: transcript, existingSummary: existingSummary)

            // 调用 DeepSeek
            DeepSeekService.shared.extractKnowledge(prompt: prompt) { [weak self] result in
                guard let self = self else { return }
                self.isExtracting = false

                switch result {
                case .success(let extractionResult):
                    let llmAddedCount = self.mergeExtractionResult(
                        extractionResult,
                        sessionId: sessionId,
                        privacyMetadata: remotePrivacyMetadata
                    )
                    let addedCount = deterministicCount + llmAddedCount
                    self.graph.sessionCount = max(self.graph.sessionCount, sessionId)
                    self.save()
                    print("[KBLite] ✅ 知识提取完成: 新增 \(addedCount) 实体")
                    DispatchQueue.main.async { completion(addedCount) }

                case .failure(let error):
                    print("[KBLite] ⚠️ LLM 提取失败: \(error.localizedDescription)，保留本地确定性沉淀")
                    self.graph.sessionCount = max(self.graph.sessionCount, sessionId)
                    self.save()
                    DispatchQueue.main.async { completion(deterministicCount) }
                }
            }
        }
    }

    /// 本地正则快速提取（LLM 不可用时的 fallback）
    /// 复用 ConversationMemoryManager 的维度提取逻辑，但存入知识库
    private func quickExtract(
        turns: [ConversationTurn],
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        let userTexts = turns.filter { $0.role == "user" }.map { $0.text }
        let allText = userTexts.joined(separator: " ")

        var addedCount = 0

        // 本地快速抽取不再把“妈妈/爷爷”这类单独称谓入库；等待 LLM 抽到具体姓名或更完整人物信息。

        addedCount += quickExtractConcretePeople(from: allText, sessionId: sessionId, privacyMetadata: privacyMetadata)
        addedCount += quickExtractExplicitFacts(from: userTexts, sessionId: sessionId, privacyMetadata: privacyMetadata)

        // 提取地点
        let cities = ["北京", "上海", "广州", "深圳", "杭州", "南京", "苏州",
                      "成都", "重庆", "武汉", "长沙", "西安", "天津", "青岛",
                      "绍兴", "越城区", "仓桥直街", "西湖", "西湖边",
                      "东北", "四川", "湖南", "湖北", "浙江", "广东", "江西", "安徽", "河南", "山东"]
        for city in cities {
            if allText.contains(city) {
                addedCount += upsertQuickPlace(
                    name: city,
                    category: inferPlaceCategory(from: allText, place: city),
                    description: nil,
                    sessionId: sessionId,
                    privacyMetadata: privacyMetadata
                )
            }
        }

        for place in extractPlacePhrases(from: allText) {
            addedCount += upsertQuickPlace(
                name: place.name,
                category: place.category,
                description: place.description,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("照相馆") {
            let title = allText.contains("小照相馆") ? "开小照相馆" : "开照相馆"
            addedCount += upsertQuickEvent(
                title: title,
                description: sentenceContaining(["照相馆"], in: userTexts) ?? "提到开过照相馆",
                year: extractYear(near: "照相馆", in: allText),
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("开过一家") && !allText.contains("照相馆") {
            addedCount += upsertQuickEvent(
                title: "开店",
                description: sentenceContaining(["开过一家"], in: userTexts) ?? "提到开过一家店",
                year: extractYear(near: "开过一家", in: allText),
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("住在") {
            addedCount += upsertQuickEvent(
                title: "居住经历",
                description: sentenceContaining(["住在"], in: userTexts) ?? "提到居住经历",
                year: extractYear(near: "住在", in: allText),
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("我叫") {
            addedCount += upsertQuickFact(
                statement: sentenceContaining(["我叫"], in: userTexts) ?? allText,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("妻子") || allText.contains("丈夫") || allText.contains("老伴") {
            addedCount += upsertQuickFact(
                statement: sentenceContaining(["妻子", "丈夫", "老伴"], in: userTexts) ?? allText,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("住在") {
            addedCount += upsertQuickFact(
                statement: sentenceContaining(["住在"], in: userTexts) ?? allText,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        if allText.contains("照相馆") {
            addedCount += upsertQuickFact(
                statement: sentenceContaining(["照相馆"], in: userTexts) ?? allText,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        let yearMatches = regexMatches(pattern: "(19\\d{2}|20\\d{2})年", in: allText)
        for match in yearMatches {
            guard let yearText = match.first else { continue }
            addedCount += upsertQuickFact(
                statement: sentenceContaining([yearText], in: userTexts) ?? "\(yearText)被用户明确提及",
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        // 提取事件
        let eventKeywords = ["结婚", "上学", "工作", "退休", "当兵", "搬家",
                             "生孩子", "做饭", "种地", "打工", "赶集", "学手艺", "出国", "下海"]
        for kw in eventKeywords {
            if allText.contains(kw) {
                addedCount += upsertQuickEvent(
                    title: kw,
                    description: sentenceContaining([kw], in: userTexts),
                    year: extractYear(near: kw, in: allText),
                    sessionId: sessionId,
                    privacyMetadata: privacyMetadata
                )
            }
        }

        print("[KBLite] 📝 正则快速提取: 新增 \(addedCount) 实体")
        return addedCount
    }

#if MEMORY_PRIVACY_INTEGRATION_VERIFY
    @discardableResult
    func verifyQuickExtract(
        turns: [ConversationTurn],
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        quickExtract(turns: turns, sessionId: sessionId, privacyMetadata: privacyMetadata)
    }
#endif

    private func quickExtractConcretePeople(
        from text: String,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        var addedCount = 0
        for name in regexMatches(pattern: "我叫([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", in: text).compactMap({ $0.first }) {
            addedCount += upsertQuickPerson(
                name: name,
                relation: "本人",
                traits: [],
                briefBio: "\(name)是用户在对话中明确自述的姓名。",
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }

        let relationPatterns: [(pattern: String, relation: String)] = [
            ("妻子([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", "妻子"),
            ("丈夫([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", "丈夫"),
            ("老伴([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", "老伴"),
            ("父亲([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", "父亲"),
            ("母亲([\\u4e00-\\u9fa5]{2,4}?)(?:在|和|，|。|,|\\s|$)", "母亲")
        ]
        for item in relationPatterns {
            for name in regexMatches(pattern: item.pattern, in: text).compactMap({ $0.first }) {
                addedCount += upsertQuickPerson(
                    name: name,
                    relation: item.relation,
                    traits: [],
                    briefBio: "\(name)在对话中被提及为\(item.relation)。",
                    sessionId: sessionId,
                    privacyMetadata: privacyMetadata
                )
            }
        }
        return addedCount
    }

    private func quickExtractExplicitFacts(
        from texts: [String],
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        let keywords = ["我叫", "住在", "妻子", "丈夫", "老伴", "照相馆", "开过", "开了", "工作", "结婚"]
        var addedCount = 0
        for sentence in splitMemorySentences(from: texts) {
            guard keywords.contains(where: { sentence.contains($0) }) ||
                    regexMatches(pattern: "(19\\d{2}|20\\d{2})年", in: sentence).isEmpty == false else {
                continue
            }
            addedCount += upsertQuickFact(
                statement: sentence,
                sessionId: sessionId,
                privacyMetadata: privacyMetadata
            )
        }
        return addedCount
    }

    private func upsertQuickPerson(
        name rawName: String,
        relation: String?,
        traits: [String],
        briefBio: String?,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        let name = Self.normalizedQuickExtractEntity(rawName)
        guard Self.shouldPersistPerson(name: name, aliases: [], traits: traits, briefBio: briefBio) else {
            return 0
        }
        let now = Date()
        if let existing = findMatchingPerson(name: name, aliases: [], privacyMetadata: privacyMetadata),
           let idx = graph.people.firstIndex(where: { $0.id == existing.id }) {
            var person = graph.people[idx]
            if person.relation == nil { person.relation = relation }
            if person.briefBio == nil { person.briefBio = briefBio }
            for trait in traits where !person.traits.contains(trait) {
                person.traits.append(trait)
            }
            if !person.sourceSessionIds.contains(sessionId) {
                person.sourceSessionIds.append(sessionId)
            }
            person.updatedAt = now
            person.privacyMetadata = person.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            graph.people[idx] = person
            return 0
        }

        guard graph.people.count < maxPeople else { return 0 }
        graph.people.append(
            KBPerson(
                id: UUID().uuidString,
                name: name,
                aliases: [],
                relation: relation,
                traits: traits,
                briefBio: briefBio,
                sourceSessionIds: [sessionId],
                createdAt: now,
                updatedAt: now,
                privacyMetadata: privacyMetadata
            )
        )
        return 1
    }

    private func upsertQuickPlace(
        name rawName: String,
        category: String?,
        description: String?,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        let name = Self.normalizedQuickExtractEntity(rawName)
        guard name.count >= 2 else { return 0 }
        if let existing = graph.places.first(where: {
            $0.name == name && KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
        }),
           let idx = graph.places.firstIndex(where: { $0.id == existing.id }) {
            var place = graph.places[idx]
            if place.category == nil { place.category = category }
            if place.description == nil { place.description = description }
            if !place.sourceSessionIds.contains(sessionId) {
                place.sourceSessionIds.append(sessionId)
            }
            place.privacyMetadata = place.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            graph.places[idx] = place
            return 0
        }

        guard graph.places.count < maxPlaces else { return 0 }
        graph.places.append(
            KBPlace(
                id: UUID().uuidString,
                name: name,
                category: category,
                description: description,
                sourceSessionIds: [sessionId],
                privacyMetadata: privacyMetadata
            )
        )
        return 1
    }

    private func upsertQuickEvent(
        title rawTitle: String,
        description: String?,
        year: Int?,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        let title = Self.normalizedQuickExtractEntity(rawTitle)
        guard !title.isEmpty else { return 0 }
        if let idx = graph.events.firstIndex(where: {
            KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
                && ($0.title == title || $0.title.contains(title) || title.contains($0.title))
        }) {
            var event = graph.events[idx]
            if event.description == nil { event.description = description }
            if event.year == nil { event.year = year }
            if !event.sourceSessionIds.contains(sessionId) {
                event.sourceSessionIds.append(sessionId)
            }
            event.privacyMetadata = event.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            graph.events[idx] = event
            return 0
        }

        guard graph.events.count < maxEvents else { return 0 }
        graph.events.append(
            KBEvent(
                id: UUID().uuidString,
                title: title,
                description: description,
                year: year,
                sourceSessionIds: [sessionId],
                privacyMetadata: privacyMetadata
            )
        )
        return 1
    }

    private func upsertQuickFact(
        statement rawStatement: String,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        let statement = Self.normalizedQuickExtractEntity(rawStatement)
        guard statement.count >= 4 else { return 0 }
        if let idx = graph.facts.firstIndex(where: {
            KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
                && ($0.statement == statement ||
                    ($0.statement.count >= 10 && statement.count >= 10 &&
                     ($0.statement.contains(statement) || statement.contains($0.statement))))
        }) {
            var fact = graph.facts[idx]
            if !fact.sourceSessionIds.contains(sessionId) {
                fact.sourceSessionIds.append(sessionId)
            }
            fact.privacyMetadata = fact.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            graph.facts[idx] = fact
            return 0
        }

        guard graph.facts.count < maxFacts else { return 0 }
        graph.facts.append(
            KBFact(
                id: UUID().uuidString,
                statement: statement,
                confidence: "high",
                sourceSessionIds: [sessionId],
                privacyMetadata: privacyMetadata
            )
        )
        return 1
    }

    private func extractPlacePhrases(from text: String) -> [(name: String, category: String?, description: String?)] {
        var results: [(String, String?, String?)] = []
        for match in regexMatches(pattern: "住在([^。！？,，；;\\n]{2,24})", in: text) {
            guard let raw = match.first else { continue }
            let place = raw
                .replacingOccurrences(of: "的", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            if place.count >= 2 {
                results.append((place, "lived", "用户明确提到曾住在这里。"))
            }
        }
        for match in regexMatches(pattern: "在([^。！？,，；;\\n]{2,18})(开过|开了|经营|工作|上班)", in: text) {
            guard let raw = match.first else { continue }
            let place = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            if place.count >= 2 {
                results.append((place, "worked", "用户明确提到在这里有工作或经营经历。"))
            }
        }
        return results
    }

    private func inferPlaceCategory(from text: String, place: String) -> String? {
        if text.contains("住在\(place)") || text.contains("\(place)住") {
            return "lived"
        }
        if text.contains("\(place)边开") || text.contains("\(place)开") || text.contains("\(place)工作") {
            return "worked"
        }
        return nil
    }

    private func sentenceContaining(_ keywords: [String], in texts: [String]) -> String? {
        splitMemorySentences(from: texts).first { sentence in
            keywords.contains { sentence.contains($0) }
        }
    }

    private func splitMemorySentences(from texts: [String]) -> [String] {
        texts.flatMap { text in
            text.components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n"))
        }
        .map { Self.normalizedQuickExtractEntity($0) }
        .filter { !$0.isEmpty }
    }

    private func extractYear(near keyword: String, in text: String) -> Int? {
        let sentences = splitMemorySentences(from: [text])
        let target = sentences.first { $0.contains(keyword) } ?? text
        guard let yearText = regexMatches(pattern: "(19\\d{2}|20\\d{2})年", in: target).first?.first else {
            return nil
        }
        return Int(yearText)
    }

    private func regexMatches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
        }
    }

    // MARK: - Private: Prompt Building

    /// 构建已有知识摘要（供 LLM prompt 使用）
    private func buildExistingSummary(surface: MemoryUseSurface = .prompt) -> String {
        let people = graph.people.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) &&
                !Self.isGenericKinshipDisplayName($0.name)
        }
        let places = graph.places.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }
        let events = graph.events.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }
        let facts = graph.facts.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }

        if people.isEmpty && places.isEmpty && events.isEmpty {
            return "（暂无已有知识）"
        }

        var lines: [String] = []

        if !people.isEmpty {
            lines.append("已知人物：")
            for p in people.prefix(15) {
                let traits = p.traits.isEmpty ? "" : "（\(p.traits.joined(separator: "、"))）"
                lines.append("  - \(p.name)\(traits)")
            }
        }

        if !places.isEmpty {
            lines.append("已知地点：\(places.prefix(10).map { $0.name }.joined(separator: "、"))")
        }

        if !events.isEmpty {
            lines.append("已知事件：\(events.prefix(10).map { $0.title }.joined(separator: "、"))")
        }

        if !facts.isEmpty {
            let recentFacts = facts.sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            lines.append("最近事实：")
            for f in recentFacts.prefix(5) {
                lines.append("  - \(f.statement)")
            }
        }

        let result = lines.joined(separator: "\n")
        // 限制 prompt 长度
        if result.count > 800 {
            return String(result.prefix(800)) + "\n..."
        }
        return result
    }

    /// 构建知识提取 prompt
    private func buildExtractionPrompt(transcript: String, existingSummary: String) -> String {
        return """
你是一个家庭记忆提取器。从以下对话中提取**本轮新出现的**信息。

【已有知识】（避免重复提取，只提取新信息）
\(existingSummary)

【本轮对话】
\(transcript)

请输出**严格的 JSON**（不要任何其他文字，不要 markdown 代码块标记）：
{
  "people": [
    {
      "name": "称呼或姓名",
      "aliases": ["其他称呼1", "其他称呼2"],
      "relation": "与用户的关系",
      "traits": ["特征1", "特征2"],
      "briefBio": "一两句话简介",
      "sourceTurnIndices": [对话行号]
    }
  ],
  "places": [
    {
      "name": "地点名",
      "category": "hometown/lived/visited/worked",
      "latitude": null,
      "longitude": null,
      "description": "简短描述",
      "relatedPeople": ["关联人物名"],
      "sourceTurnIndices": [对话行号]
    }
  ],
  "events": [
    {
      "title": "事件简短标题",
      "description": "详细描述",
      "year": null,
      "month": null,
      "location": "地点名",
      "participants": ["参与人物名"],
      "sourceTurnIndices": [对话行号]
    }
  ],
  "facts": [
    {
      "statement": "一句事实陈述",
      "confidence": "high/medium/low",
      "relatedPeople": [],
      "relatedPlaces": [],
      "relatedEvents": [],
      "sourceTurnIndices": [对话行号]
    }
  ]
}

【规则】
1. 只提取**本轮新出现**的信息，已有知识中已涵盖的不要重复。
2. confidence: 用户明确陈述 = "high"，推测/模糊 = "medium"，不确定 = "low"。
3. aliases: 收集对方在对话中出现过的所有称呼方式。
4. traits: 从行为和描述中提取特征词（如"手艺人"、"爱喝酒"、"当过兵"）。
5. briefBio: 用 1-2 句话简短总结此人（基于本轮对话）。
6. json 中所有的中文key前后不可以有空格
7. 如果本轮没有新信息，输出空数组。
8. 不要输出任何 JSON 之外的文字。
"""
    }

    // MARK: - Private: Entity Merging

    /// 将 LLM 提取结果合并到知识图谱
    /// - Returns: 新增实体数量
    private func mergeExtractionResult(
        _ result: KBExtractionResult,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        var addedCount = 0
        let now = Date()

        // 容量检查
        checkCapacity()

        // 1. 合并人物
        for ep in result.people {
            guard Self.shouldPersistPerson(
                name: ep.name,
                aliases: ep.aliases,
                traits: ep.traits,
                briefBio: ep.briefBio
            ) else {
                continue
            }
            let matched = findMatchingPerson(
                name: ep.name,
                aliases: ep.aliases,
                privacyMetadata: privacyMetadata
            )
            if let existing = matched {
                // 更新已有人物
                if let idx = graph.people.firstIndex(where: { $0.id == existing.id }) {
                    var p = graph.people[idx]

                    // 合并别名（取并集）
                    for alias in ep.aliases where !p.aliases.contains(alias) && alias != p.name {
                        p.aliases.append(alias)
                    }

                    // 合并 traits（取并集）
                    for trait in ep.traits where !p.traits.contains(trait) {
                        p.traits.append(trait)
                    }

                    // 补充关系
                    if p.relation == nil, let rel = ep.relation {
                        p.relation = rel
                    }

                    // 补充简介
                    if p.briefBio == nil, let bio = ep.briefBio {
                        p.briefBio = bio
                    }

                    // 记录来源
                    if !p.sourceSessionIds.contains(sessionId) {
                        p.sourceSessionIds.append(sessionId)
                    }
                    p.updatedAt = now
                    p.privacyMetadata = p.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
                    graph.people[idx] = p
                    print("[KBLite] 🔄 合并人物: \(p.name)")
                }
            } else {
                // 新增人物
                let person = KBPerson(
                    id: UUID().uuidString,
                    name: ep.name,
                    aliases: ep.aliases,
                    relation: ep.relation,
                    traits: ep.traits,
                    briefBio: ep.briefBio,
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now,
                    privacyMetadata: privacyMetadata
                )
                graph.people.append(person)
                addedCount += 1
                print("[KBLite] ➕ 新增人物: \(ep.name)")
            }
        }

        // 2. 合并地点
        for ep in result.places {
            let matched = findMatchingPlace(name: ep.name, privacyMetadata: privacyMetadata)
            if let existing = matched {
                if let idx = graph.places.firstIndex(where: { $0.id == existing.id }) {
                    var p = graph.places[idx]
                    if p.description == nil, let desc = ep.description { p.description = desc }
                    if p.category == nil, let cat = ep.category { p.category = cat }
                    if !p.sourceSessionIds.contains(sessionId) { p.sourceSessionIds.append(sessionId) }
                    p.privacyMetadata = p.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
                    graph.places[idx] = p
                    print("[KBLite] 🔄 合并地点: \(p.name)")
                }
            } else {
                let place = KBPlace(
                    id: UUID().uuidString,
                    name: ep.name,
                    category: ep.category,
                    latitude: ep.latitude,
                    longitude: ep.longitude,
                    description: ep.description,
                    sourceSessionIds: [sessionId],
                    privacyMetadata: privacyMetadata
                )
                graph.places.append(place)
                addedCount += 1
                print("[KBLite] ➕ 新增地点: \(ep.name)")
            }
        }

        // 3. 合并事件
        for ee in result.events {
            let existing = graph.events.first {
                $0.title == ee.title
                    && KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
            }
            if let existing = existing {
                if let idx = graph.events.firstIndex(where: { $0.id == existing.id }) {
                    var e = graph.events[idx]
                    if e.description == nil, let desc = ee.description { e.description = desc }
                    if e.year == nil, let y = ee.year { e.year = y }
                    if !e.sourceSessionIds.contains(sessionId) { e.sourceSessionIds.append(sessionId) }
                    e.privacyMetadata = e.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
                    graph.events[idx] = e
                    print("[KBLite] 🔄 合并事件: \(e.title)")
                }
            } else {
                let event = KBEvent(
                    id: UUID().uuidString,
                    title: ee.title,
                    description: ee.description,
                    year: ee.year,
                    month: ee.month,
                    sourceSessionIds: [sessionId],
                    privacyMetadata: privacyMetadata
                )
                graph.events.append(event)
                addedCount += 1
                print("[KBLite] ➕ 新增事件: \(ee.title)")
            }
        }

        // 4. 合并事实（按 statement 去重）
        for ef in result.facts {
            let stmt = ef.statement.trimmingCharacters(in: .whitespaces)
            guard !stmt.isEmpty else { continue }

            // 检查是否已存在相同或高度相似的事实
            let duplicateIndex = graph.facts.firstIndex { existing in
                KBLitePrivacyScopePolicy.canMerge(existing: existing.privacyMetadata, incoming: privacyMetadata)
                    && (existing.statement == stmt ||
                        (existing.statement.count >= 10 && stmt.count >= 10 &&
                         (existing.statement.contains(stmt) || stmt.contains(existing.statement))))
            }

            if let duplicateIndex {
                if !graph.facts[duplicateIndex].sourceSessionIds.contains(sessionId) {
                    graph.facts[duplicateIndex].sourceSessionIds.append(sessionId)
                }
                graph.facts[duplicateIndex].privacyMetadata = graph.facts[duplicateIndex]
                    .privacyMetadata
                    .mergingSourceRefs(from: privacyMetadata)
            } else {
                let fact = KBFact(
                    id: UUID().uuidString,
                    statement: stmt,
                    confidence: ef.confidence ?? "high",
                    sourceSessionIds: [sessionId],
                    privacyMetadata: privacyMetadata
                )
                graph.facts.append(fact)
                addedCount += 1
                print("[KBLite] ➕ 新增事实: \(stmt.prefix(40))...")
            }
        }

        return addedCount
    }

    // MARK: - Private: Matching

    /// 查找匹配的人物（按名字、别名）
    private func findMatchingPerson(
        name: String,
        aliases: [String],
        privacyMetadata: MemoryPrivacyMetadata? = nil
    ) -> KBPerson? {
        let allNames = [name] + aliases
        let people = graph.people.filter {
            guard let privacyMetadata else { return true }
            return KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
        }

        // 1. 完全匹配名字
        if let match = people.first(where: { allNames.contains($0.name) }) {
            return match
        }

        // 2. 匹配别名
        if let match = people.first(where: { p in
            p.aliases.contains(where: { alias in allNames.contains(alias) })
        }) {
            return match
        }

        // 3. 模糊匹配（包含关系）
        if name.count >= 2 {
            for p in people {
                let searchText = [p.name] + p.aliases
                for text in searchText {
                    if text.contains(name) || name.contains(text) {
                        return p
                    }
                }
            }
        }

        return nil
    }

    /// 查找匹配的地点（按名字）
    private func findMatchingPlace(
        name: String,
        privacyMetadata: MemoryPrivacyMetadata? = nil
    ) -> KBPlace? {
        let places = graph.places.filter {
            guard let privacyMetadata else { return true }
            return KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
        }
        if let match = places.first(where: { $0.name == name }) {
            return match
        }
        // 包含关系匹配（"外滩" ⊂ "上海外滩"）
        for place in places {
            if place.name.contains(name) || name.contains(place.name) {
                return place
            }
        }
        return nil
    }

    // MARK: - Public API: Search

    /// 混合检索：语义搜索（iOS 17+）+ 关键词 fallback
    /// - Parameter query: 用户当前说的内容
    /// - Returns: 匹配的实体集合
    func search(query: String) -> KBSearchResult {
        guard !query.isEmpty else { return KBSearchResult() }

        // 尝试语义搜索（iOS 17+），失败或不可用则 fallback 关键词
        if KBLiteSemanticSearch.shared.isAvailable {
            let semantic = KBLiteSemanticSearch.shared.semanticSearch(
                query: query,
                people: graph.people,
                places: graph.places,
                events: graph.events,
                facts: graph.facts
            )
            if !semantic.isEmpty {
                return semantic
            }
        }

        // Fallback: 关键词匹配
        return keywordSearch(query: query)
    }

    /// 关键词检索（原始实现，作为语义搜索的 fallback）
    private func keywordSearch(query: String) -> KBSearchResult {
        var result = KBSearchResult()

        // 使用 NSLinguisticTagger 做中文分词
        let keywords = tokenizeChinese(query)

        print("[KBLite] 🔍 检索: \"\(query)\" → 关键词: \(keywords)")

        // 人物匹配
        result.people = graph.people.filter { person in
            guard !Self.isGenericKinshipDisplayName(person.name) else { return false }
            let searchTarget = person.searchableText
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 地点匹配
        result.places = graph.places.filter { place in
            let searchTarget = place.searchableText
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 事件匹配
        result.events = graph.events.filter { event in
            let searchTarget = event.searchableText + " " + event.formattedDate
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 事实匹配
        result.facts = graph.facts.filter { fact in
            keywords.contains { kw in
                fact.statement.contains(kw)
            }
        }

        print("[KBLite] 🔍 检索结果: \(result.totalCount) 条 (人:\(result.people.count) 地:\(result.places.count) 事:\(result.events.count) 实:\(result.facts.count))")
        return result
    }

    /// 中文分词（使用系统 NSLinguisticTagger）
    private func tokenizeChinese(_ text: String) -> [String] {
        var tokens: [String] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        tagger.enumerateTags(
            in: NSRange(text.startIndex..., in: text),
            scheme: .tokenType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { _, range, _, _ in
            if let substring = Range(range, in: text) {
                let token = String(text[substring])
                // 过滤单字词和纯数字
                if token.count >= 2 && !token.allSatisfy({ $0.isNumber }) {
                    tokens.append(token)
                }
            }
        }

        // 分词失败时，切分 2-3 字片段作为 fallback
        if tokens.isEmpty {
            var i = text.startIndex
            while i < text.endIndex {
                let end = text.index(i, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                let token = String(text[i..<end])
                tokens.append(token)
                i = end
            }
        }

        return tokens
    }

    // MARK: - Public API: Context Building

    /// 构建可注入 system_prompt 的知识库上下文
    /// - Parameters:
    ///   - query: 用户当前说的话（触发检索），nil 时返回最近摘要
    ///   - maxItems: 每类实体最多返回条数
    /// - Returns: 上下文字符串，空字符串表示无可用上下文
    func buildContextString(query: String?, maxItems: Int = 5) -> String {
        var parts: [String] = []

        // 有 query → 检索相关知识
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            var result = search(query: q)
            result.people = result.people.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }
            result.places = result.places.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }
            result.events = result.events.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }
            result.facts = result.facts.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }

            if !result.people.isEmpty {
                let summaries: [String] = result.people.prefix(maxItems).map { p in
                    var line = "\(p.name)"
                    if let rel = p.relation { line += "（\(rel)）" }
                    if !p.traits.isEmpty { line += "，特征：\(p.traits.joined(separator: "、"))" }

                    // 附上关联事实
                    let relatedFacts = KBLitePrivacyScopePolicy.relatedFacts(
                        in: graph,
                        relatedPersonId: p.id,
                        surface: .prompt
                    )
                    if !relatedFacts.isEmpty {
                        let factsText = relatedFacts.prefix(3).map { $0.statement }.joined(separator: "；")
                        line += "。已知：\(factsText)"
                    } else if let bio = p.briefBio {
                        line += "。简介：\(bio)"
                    }
                    return line
                }
                parts.append("【相关人物】\n" + summaries.joined(separator: "\n"))
            }

            if !result.places.isEmpty {
                let summaries: [String] = result.places.prefix(maxItems).map { p in
                    var line = p.name
                    if let cat = p.category { line += "（\(cat)）" }
                    if let desc = p.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关地点】\n" + summaries.joined(separator: "\n"))
            }

            if !result.events.isEmpty {
                let summaries: [String] = result.events.prefix(maxItems).map { e in
                    var line = e.title
                    let date = e.formattedDate
                    if !date.isEmpty { line += "（\(date)）" }
                    if let desc = e.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关事件】\n" + summaries.joined(separator: "\n"))
            }

            if !result.facts.isEmpty {
                let factsText = result.facts.prefix(maxItems).map { "· \($0.statement)" }.joined(separator: "\n")
                parts.append("【相关事实】\n" + factsText)
            }
        }

        // 无 query 或检索结果为空 → 提供最近摘要
        if parts.isEmpty {
            let recentPeople = graph.people
                .filter {
                    PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) &&
                        !Self.isGenericKinshipDisplayName($0.name)
                }
                .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            if !recentPeople.isEmpty {
                let names = recentPeople.prefix(5).map { $0.name }.joined(separator: "、")
                parts.append("【已知人物】您提到过：\(names)等")
            }

            let recentEvents = graph.events
                .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }
                .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            if !recentEvents.isEmpty {
                let titles = recentEvents.prefix(5).map { e in
                    let d = e.formattedDate
                    return d.isEmpty ? e.title : "\(d)\(e.title)"
                }.joined(separator: "、")
                parts.append("【已知事件】\(titles)")
            }
        }

        if parts.isEmpty { return "" }

        return "\n\n=== 用户知识库 ===\n" + parts.joined(separator: "\n\n") +
               "\n请自然地引用上述已知信息，让长辈感受到你记得他/她说过的事。不要逐条播报。"
    }

    // MARK: - Public API: Image Analysis

    /// 将从图片分析描述中提取的知识加入知识库
    /// - Parameters:
    ///   - result: 图片分析结果
    ///   - sessionId: 当前会话序号
    func ingestImageAnalysis(
        _ result: KBImageAnalysisResult,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        var addedCount = 0
        var updatedExisting = false
        let now = Date()

        // 场景 → 地点
        if !result.scene.isEmpty {
            let existing = findMatchingPlace(name: result.scene, privacyMetadata: privacyMetadata)
            if let existing,
               let idx = graph.places.firstIndex(where: { $0.id == existing.id }) {
                if !graph.places[idx].sourceSessionIds.contains(sessionId) {
                    graph.places[idx].sourceSessionIds.append(sessionId)
                }
                graph.places[idx].privacyMetadata = graph.places[idx]
                    .privacyMetadata
                    .mergingSourceRefs(from: privacyMetadata)
                updatedExisting = true
            } else {
                let place = KBPlace(
                    id: UUID().uuidString,
                    name: result.scene,
                    description: result.description,
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    privacyMetadata: privacyMetadata
                )
                graph.places.append(place)
                addedCount += 1
            }
        }

        // 检测到的人物 → 尝试添加
        for personDesc in result.detectedPeople {
            let name = extractPersonNameFromDescription(personDesc)
            guard Self.shouldPersistPerson(name: name, aliases: [], traits: [], briefBio: nil) else {
                continue
            }
            let existing = findMatchingPerson(name: name, aliases: [], privacyMetadata: privacyMetadata)
            if let existing,
               let idx = graph.people.firstIndex(where: { $0.id == existing.id }) {
                if !graph.people[idx].sourceSessionIds.contains(sessionId) {
                    graph.people[idx].sourceSessionIds.append(sessionId)
                }
                graph.people[idx].privacyMetadata = graph.people[idx]
                    .privacyMetadata
                    .mergingSourceRefs(from: privacyMetadata)
                updatedExisting = true
            } else {
                let person = KBPerson(
                    id: UUID().uuidString,
                    name: name,
                    aliases: [],
                    relation: nil,
                    traits: [],
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now,
                    privacyMetadata: privacyMetadata
                )
                graph.people.append(person)
                addedCount += 1
            }
        }

        if addedCount > 0 || updatedExisting {
            graph.lastUpdated = now
            save()
            print("[KBLite] 🖼️ 图片分析入库: 新增 \(addedCount) 实体")
        }
    }

    /// 从图片人物描述中提取可能的姓名
    private func extractPersonNameFromDescription(_ desc: String) -> String {
        let normalized = Self.normalizedQuickExtractEntity(desc)
        guard !Self.isGenericKinshipDisplayName(normalized) else { return "" }
        guard !Self.genericKinshipNames.contains(where: { normalized.contains($0) }) else { return "" }
        return normalized.count <= 6 ? normalized : String(normalized.prefix(6))
    }

    // MARK: - Boundary Protection

    /// 容量检查：超过上限时清理旧实体
    private func checkCapacity() {
        if graph.facts.count > maxFacts {
            let toRemove = graph.facts.count - maxFacts + 50
            let sorted = graph.facts.sorted { ($0.sourceSessionIds.first ?? 0) < ($1.sourceSessionIds.first ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.facts.removeAll { removed.contains($0.id) }
            warnCapacity("事实", removed: toRemove)
        }
        if graph.people.count > maxPeople {
            let toRemove = graph.people.count - maxPeople + 10
            let sorted = graph.people.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.facts.removeAll { fact in
                fact.relatedPersonIds.contains(where: { removed.contains($0) })
            }
            graph.people.removeAll { removed.contains($0.id) }
            warnCapacity("人物", removed: toRemove)
        }
        if graph.places.count > maxPlaces {
            let toRemove = graph.places.count - maxPlaces + 10
            let sorted = graph.places.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.places.removeAll { removed.contains($0.id) }
            warnCapacity("地点", removed: toRemove)
        }
        if graph.events.count > maxEvents {
            let toRemove = graph.events.count - maxEvents + 10
            let sorted = graph.events.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.events.removeAll { removed.contains($0.id) }
            warnCapacity("事件", removed: toRemove)
        }
    }

    private func warnCapacity(_ type: String, removed: Int) {
        if !didWarnCapacity {
            didWarnCapacity = true
            print("[KBLite] ⚠️ 知识库容量告警：\(type)超出上限，已清理 \(removed) 条旧记录")
            print("[KBLite] ⚠️ 当前: 人\(graph.people.count)/\(maxPeople) 地\(graph.places.count)/\(maxPlaces) 事\(graph.events.count)/\(maxEvents) 实\(graph.facts.count)/\(maxFacts)")
        }
    }

    // MARK: - External Save Notification

    /// 外部模块（如 MultiUser）修改图谱后调用此方法持久化
    func notifyGraphUpdated() {
        save()
    }

    func sanitizedGraph(for surface: MemoryUseSurface, familyMemberID: String? = nil) -> KBLiteGraph {
        readGraph { graph in
            var sanitized = KBLitePrivacyScopePolicy.sanitizedGraph(graph, for: surface, familyMemberID: familyMemberID)
            let removedPeopleIDs = Set(sanitized.people.filter { Self.isGenericKinshipDisplayName($0.name) }.map(\.id))
            guard !removedPeopleIDs.isEmpty else { return sanitized }
            sanitized.people.removeAll { removedPeopleIDs.contains($0.id) }
            sanitized.events = sanitized.events.map { event in
                var event = event
                event.participantIds = event.participantIds.filter { !removedPeopleIDs.contains($0) }
                return event
            }
            sanitized.facts = sanitized.facts.map { fact in
                var fact = fact
                fact.relatedPersonIds = fact.relatedPersonIds.filter { !removedPeopleIDs.contains($0) }
                return fact
            }
            return sanitized
        }
    }

    // MARK: - Maintenance

    /// 重置知识库（调试用 / 用户主动清除）
    func reset(syncToBackend: Bool = true) {
        graph = KBLiteGraph()
        didWarnCapacity = false
        save(scheduleBackendSync: syncToBackend)
        print("[KBLite] 🔄 知识库已重置")
    }

    /// 导出知识库为 JSON 字符串。默认走用户外发导出 surface，避免泄漏本地完整图谱。
    func exportJSON(surface: MemoryUseSurface = .export, familyMemberID: String? = nil) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let exportGraph = sanitizedGraph(for: surface, familyMemberID: familyMemberID)
        guard let data = try? encoder.encode(exportGraph) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从 JSON 字符串导入知识库（合并模式）
    @discardableResult
    func importJSON(_ jsonString: String) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? decoder.decode(KBLiteGraph.self, from: data) else {
            print("[KBLite] ❌ 导入失败：JSON 解析错误")
            return false
        }
        let imported = sanitizedIncomingGraph(decoded)
        var addedCount = 0
        for person in imported.people {
            guard !Self.isGenericKinshipDisplayName(person.name) else { continue }
            if findMatchingPerson(
                name: person.name,
                aliases: person.aliases,
                privacyMetadata: person.privacyMetadata
            ) == nil {
                graph.people.append(person)
                addedCount += 1
            }
        }
        for place in imported.places {
            if findMatchingPlace(name: place.name, privacyMetadata: place.privacyMetadata) == nil {
                graph.places.append(place)
                addedCount += 1
            }
        }
        for event in imported.events {
            if graph.events.first(where: {
                $0.title == event.title
                    && KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: event.privacyMetadata)
            }) == nil {
                graph.events.append(event)
                addedCount += 1
            }
        }
        for fact in imported.facts {
            if !graph.facts.contains(where: {
                $0.statement == fact.statement
                    && KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: fact.privacyMetadata)
            }) {
                graph.facts.append(fact)
                addedCount += 1
            }
        }
        graph.lastUpdated = Date()
        save()
        print("[KBLite] 📥 导入完成: 新增 \(addedCount) 实体")
        return true
    }

    // MARK: - Public API: Archive Material Metadata

    @discardableResult
    func ingestArchiveTextMaterialMetadata(
        archiveItemID rawArchiveItemID: String,
        title rawTitle: String,
        note rawNote: String,
        materialKind rawMaterialKind: String,
        capturedAt: Date,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        guard privacyMetadata.scope != .privateOnly else { return 0 }
        let archiveItemID = Self.normalizedQuickExtractEntity(rawArchiveItemID)
        let title = Self.normalizedQuickExtractEntity(rawTitle)
        let note = Self.normalizedQuickExtractEntity(rawNote)
        let materialKind = Self.normalizedQuickExtractEntity(rawMaterialKind)
        guard !archiveItemID.isEmpty, !title.isEmpty else { return 0 }

        let sourceRef = MemorySourceRef(
            kind: .memoryArchiveItem,
            id: archiveItemID,
            title: title,
            capturedAt: capturedAt
        )
        let resolvedMetadata = Self.metadataByAppending(sourceRef: sourceRef, to: privacyMetadata)
        let kindText = materialKind.isEmpty ? "文字素材" : materialKind
        let statement: String
        if note.isEmpty {
            statement = "记忆档案馆保存\(kindText)《\(title)》。"
        } else {
            statement = "记忆档案馆保存\(kindText)《\(title)》：\(Self.metadataSummary(note))。"
        }

        let metadataCount = upsertArchiveMetadataFact(
            statement: statement,
            sourceRef: sourceRef,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata,
            logPrefix: "📝 档案文字元信息入库",
            logTitle: title
        )
        let personaCount = linkArchivePersonaFactIfNeeded(
            title: title,
            note: note,
            materialKind: kindText,
            sourceRef: sourceRef,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata
        )
        return metadataCount + personaCount
    }

    @discardableResult
    func ingestArchivePhotoAnalysisMetadata(
        archiveItemID rawArchiveItemID: String,
        title rawTitle: String,
        analysis: KBImageAnalysisResult,
        capturedAt: Date,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        guard privacyMetadata.scope != .privateOnly else { return 0 }
        let archiveItemID = Self.normalizedQuickExtractEntity(rawArchiveItemID)
        let title = Self.normalizedQuickExtractEntity(rawTitle)
        guard !archiveItemID.isEmpty, !title.isEmpty else { return 0 }

        let sourceRef = MemorySourceRef(
            kind: .memoryArchiveItem,
            id: archiveItemID,
            title: title,
            capturedAt: capturedAt
        )
        let resolvedMetadata = Self.metadataByAppending(sourceRef: sourceRef, to: privacyMetadata)
        let summary = Self.metadataSummary(analysis.description)
        var details = [String]()
        if !analysis.scene.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append("场景：\(Self.metadataSummary(analysis.scene))")
        }
        if let decade = analysis.estimatedDecade {
            details.append("年代：\(decade)年代")
        }
        if !analysis.detectedPeople.isEmpty {
            details.append("人物：\(analysis.detectedPeople.prefix(5).joined(separator: "、"))")
        }
        let suffix = details.isEmpty ? "" : "（\(details.joined(separator: "；"))）"
        let statement = "记忆档案馆照片《\(title)》分析摘要：\(summary)\(suffix)。"

        return upsertArchiveMetadataFact(
            statement: statement,
            sourceRef: sourceRef,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata,
            logPrefix: "🖼️ 档案照片元信息入库",
            logTitle: title
        )
    }

    @discardableResult
    func ingestArchiveVoiceSampleMetadata(
        title rawTitle: String,
        note rawNote: String?,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly),
        targetPersonName: String? = nil,
        targetPersonId: String? = nil
    ) -> Int {
        guard privacyMetadata.scope != .privateOnly else { return 0 }
        let title = Self.normalizedQuickExtractEntity(rawTitle)
        guard !title.isEmpty else { return 0 }

        let note = Self.normalizedQuickExtractEntity(rawNote ?? "")
        let statement: String
        if note.isEmpty {
            statement = "记忆档案馆保存语音样本《\(title)》。"
        } else {
            statement = "记忆档案馆保存语音样本《\(title)》：\(note)。"
        }

        let targetPerson = upsertArchiveVoiceTargetPersonIfNeeded(
            targetPersonName: targetPersonName,
            targetPersonId: targetPersonId,
            sessionId: sessionId,
            privacyMetadata: privacyMetadata
        )

        if let idx = graph.facts.firstIndex(where: {
            KBLitePrivacyScopePolicy.canMerge(existing: $0.privacyMetadata, incoming: privacyMetadata)
                && $0.statement.contains("语音样本")
                && $0.statement.contains("《\(title)》")
        }) {
            var fact = graph.facts[idx]
            if !fact.sourceSessionIds.contains(sessionId) {
                fact.sourceSessionIds.append(sessionId)
            }
            fact.privacyMetadata = fact.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            if let targetPerson, !fact.relatedPersonIds.contains(targetPerson.id) {
                fact.relatedPersonIds.append(targetPerson.id)
            }
            graph.facts[idx] = fact
            save()
            return 0
        }

        guard graph.facts.count < maxFacts else { return 0 }
        graph.facts.append(
            KBFact(
                id: UUID().uuidString,
                statement: statement,
                confidence: "confirmed",
                relatedPersonIds: targetPerson.map { [$0.id] } ?? [],
                sourceSessionIds: [sessionId],
                privacyMetadata: privacyMetadata
            )
        )
        save()
        print("[KBLite] 🎙️ 语音样本元信息入库: \(title)")
        return 1
    }

    private func upsertArchiveVoiceTargetPersonIfNeeded(
        targetPersonName: String?,
        targetPersonId: String?,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> KBPerson? {
        if let targetPersonId,
           let existing = graph.people.first(where: { $0.id == targetPersonId }) {
            return existing
        }

        guard let rawName = targetPersonName else { return nil }
        let name = Self.normalizedQuickExtractEntity(rawName)
        guard !name.isEmpty,
              name.count >= 2,
              name.count <= 6,
              !Self.isGenericKinshipDisplayName(name),
              !Self.genericKinshipNames.contains(where: { name.contains($0) }) else {
            return nil
        }

        _ = upsertQuickPerson(
            name: name,
            relation: nil,
            traits: ["已导入声纹语音样本"],
            briefBio: nil,
            sessionId: sessionId,
            privacyMetadata: privacyMetadata
        )
        return findMatchingPerson(name: name, aliases: [], privacyMetadata: privacyMetadata)
    }

    @discardableResult
    func ingestTimeMailboxLetterMetadata(
        letterId: String,
        recipientName rawRecipientName: String,
        title rawTitle: String,
        deliverAt: Date,
        createdAt: Date,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) -> Int {
        guard privacyMetadata.scope != .privateOnly else { return 0 }
        let cleanLetterId = Self.normalizedQuickExtractEntity(letterId)
        let recipientName = Self.normalizedQuickExtractEntity(rawRecipientName)
        let title = Self.normalizedQuickExtractEntity(rawTitle)
        guard !cleanLetterId.isEmpty, !recipientName.isEmpty else { return 0 }

        let displayTitle = title.isEmpty ? "未命名信件" : title
        let deliverText = Self.metadataDateFormatter.string(from: deliverAt)
        let statement = "时空信箱封存给\(recipientName)的信《\(displayTitle)》，计划于\(deliverText)投递。"
        let sourceRef = MemorySourceRef(
            kind: .timeMailboxLetter,
            id: cleanLetterId,
            title: displayTitle,
            capturedAt: createdAt
        )
        let resolvedMetadata = Self.metadataByAppending(sourceRef: sourceRef, to: privacyMetadata)

        if let idx = graph.facts.firstIndex(where: { fact in
            fact.privacyMetadata.sourceRefs.contains(where: { Self.isSameSourceRef($0, sourceRef) }) ||
                (KBLitePrivacyScopePolicy.canMerge(existing: fact.privacyMetadata, incoming: resolvedMetadata)
                 && fact.statement.contains("时空信箱")
                 && fact.statement.contains("《\(displayTitle)》")
                 && fact.statement.contains(recipientName))
        }) {
            var fact = graph.facts[idx]
            if !fact.sourceSessionIds.contains(graph.sessionCount + 1) {
                fact.sourceSessionIds.append(graph.sessionCount + 1)
            }
            if !fact.privacyMetadata.sourceRefs.contains(sourceRef) {
                fact.privacyMetadata = Self.metadataByAppending(sourceRef: sourceRef, to: fact.privacyMetadata)
            }
            graph.facts[idx] = fact
            save()
            return 0
        }

        guard graph.facts.count < maxFacts else { return 0 }
        graph.facts.append(
            KBFact(
                id: UUID().uuidString,
                statement: statement,
                confidence: "confirmed",
                sourceSessionIds: [graph.sessionCount + 1],
                privacyMetadata: resolvedMetadata
            )
        )
        save()
        print("[KBLite] ✉️ 时空信箱元信息入库: \(displayTitle)")
        return 1
    }

    private func upsertArchiveMetadataFact(
        statement: String,
        sourceRef: MemorySourceRef,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata,
        logPrefix: String,
        logTitle: String
    ) -> Int {
        if let idx = graph.facts.firstIndex(where: { fact in
            fact.privacyMetadata.sourceRefs.contains(where: { Self.isSameSourceRef($0, sourceRef) })
        }) {
            var fact = graph.facts[idx]
            if !fact.sourceSessionIds.contains(sessionId) {
                fact.sourceSessionIds.append(sessionId)
            }
            fact.privacyMetadata = fact.privacyMetadata.mergingSourceRefs(from: privacyMetadata)
            graph.facts[idx] = fact
            save()
            return 0
        }

        guard graph.facts.count < maxFacts else { return 0 }
        graph.facts.append(
            KBFact(
                id: UUID().uuidString,
                statement: statement,
                confidence: "confirmed",
                sourceSessionIds: [sessionId],
                privacyMetadata: privacyMetadata
            )
        )
        save()
        print("[KBLite] \(logPrefix): \(logTitle)")
        return 1
    }

    private func linkArchivePersonaFactIfNeeded(
        title: String,
        note: String,
        materialKind: String,
        sourceRef: MemorySourceRef,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata
    ) -> Int {
        guard Self.isPersonaMaterialKind(materialKind),
              let personName = Self.inferredArchivePersonaName(fromTitle: title, materialKind: materialKind) else {
            return 0
        }

        let traits = Self.archivePersonaTraits(from: note, materialKind: materialKind)
        let personAddedCount = upsertQuickPerson(
            name: personName,
            relation: nil,
            traits: traits,
            briefBio: nil,
            sessionId: sessionId,
            privacyMetadata: privacyMetadata
        )

        guard let person = findMatchingPerson(name: personName, aliases: [], privacyMetadata: privacyMetadata),
              let factIndex = graph.facts.firstIndex(where: { fact in
                  fact.privacyMetadata.sourceRefs.contains(where: { Self.isSameSourceRef($0, sourceRef) })
              }) else {
            graph.lastUpdated = Date()
            save()
            return personAddedCount
        }

        var fact = graph.facts[factIndex]
        if !fact.relatedPersonIds.contains(person.id) {
            fact.relatedPersonIds.append(person.id)
            graph.facts[factIndex] = fact
        }
        graph.lastUpdated = Date()
        save()
        return personAddedCount
    }

    private static let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    private static func metadataSummary(_ value: String, maxLength: Int = 120) -> String {
        let trimmed = normalizedQuickExtractEntity(value)
        guard trimmed.count > maxLength else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<endIndex]) + "..."
    }

    private static func isPersonaMaterialKind(_ materialKind: String) -> Bool {
        materialKind.contains("性格") || materialKind.contains("口头禅") || materialKind.contains("人格")
    }

    private static func inferredArchivePersonaName(fromTitle title: String, materialKind: String) -> String? {
        guard isPersonaMaterialKind(materialKind) || isPersonaMaterialKind(title) else { return nil }
        var candidate = normalizedQuickExtractEntity(title)
        let suffixes = [
            "的性格描述", "性格描述", "的性格", "性格",
            "的口头禅", "口头禅",
            "的人格线索", "人格线索", "的人格", "人格"
        ]
        for suffix in suffixes where candidate.hasSuffix(suffix) {
            candidate.removeLast(suffix.count)
            break
        }
        candidate = normalizedQuickExtractEntity(candidate.replacingOccurrences(of: "关于", with: ""))
        guard candidate.count >= 2, candidate.count <= 6 else { return nil }
        guard isLikelyChineseName(candidate) else { return nil }
        guard !isGenericKinshipDisplayName(candidate) else { return nil }
        guard !genericKinshipNames.contains(where: { candidate.contains($0) }) else { return nil }
        return candidate
    }

    private static func archivePersonaTraits(from note: String, materialKind: String) -> [String] {
        let summary = metadataSummary(note, maxLength: 80)
        guard !summary.isEmpty else { return [] }
        if materialKind.contains("口头禅") {
            return ["口头禅：\(summary)"]
        }

        let separators = CharacterSet(charactersIn: "，。！？；、,!?;")
        let fragments = summary
            .components(separatedBy: separators)
            .map { fragment -> String in
                var value = normalizedQuickExtractEntity(fragment)
                for prefix in ["她", "他", "老人", "长辈"] where value.hasPrefix(prefix) {
                    value.removeFirst(prefix.count)
                }
                return normalizedQuickExtractEntity(value)
            }
            .filter { $0.count >= 2 && $0.count <= 12 }
        return Array(fragments.prefix(4))
    }

    private static func isLikelyChineseName(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
        }
    }

    private static func metadataByAppending(
        sourceRef: MemorySourceRef,
        to metadata: MemoryPrivacyMetadata
    ) -> MemoryPrivacyMetadata {
        var sourceRefs = metadata.sourceRefs
        if !sourceRefs.contains(where: { isSameSourceRef($0, sourceRef) }) {
            sourceRefs.append(sourceRef)
        }
        return MemoryPrivacyMetadata(
            scope: metadata.scope,
            sourceRefs: sourceRefs,
            createdBySurface: metadata.createdBySurface,
            createdAt: metadata.createdAt,
            familyVisibility: metadata.familyVisibility
        )
    }

    private static func isSameSourceRef(_ lhs: MemorySourceRef, _ rhs: MemorySourceRef) -> Bool {
        lhs.kind == rhs.kind && lhs.id == rhs.id
    }

    /// 生成包含知识库上下文的增强开场白提示
    func buildGreetingHint() -> String {
        if isEmpty { return "" }
        var hints: [String] = []
        let recentPeople = graph.people
            .filter {
                PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt)
                    && (!$0.traits.isEmpty || $0.briefBio != nil)
            }
            .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            .prefix(3)
        if !recentPeople.isEmpty {
            let peopleHints = recentPeople.map { p in
                var h = p.name
                if !p.traits.isEmpty { h += "（\(p.traits.prefix(2).joined(separator: "、"))）" }
                return h
            }
            hints.append("记得：\(peopleHints.joined(separator: "、"))")
        }
        let recentEvents = graph.events
            .filter {
                PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt)
                    && $0.year != nil
            }
            .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            .prefix(2)
        if !recentEvents.isEmpty {
            let eventHints = recentEvents.map { e in "\(e.formattedDate)\(e.title)" }
            hints.append("事件：\(eventHints.joined(separator: "、"))")
        }
        return hints.isEmpty ? "" : hints.joined(separator: "。")
    }
}
