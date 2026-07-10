import Foundation

// MARK: - KBLiteManager

/// Lite 版知识库中央管理器 — 单例
///
/// 职责：
/// 1. JSON 持久化（kb_graph.json）
/// 2. 后端优先知识提取（本地规则作为离线降级）
/// 3. 实体合并去重
/// 4. 关键词检索
/// 5. 组装上下文文本（供 system_prompt 注入）
final class KBLiteManager {

    // MARK: - Singleton

    static let shared = KBLiteManager()

    private init() {
        loadedUserId = Self.normalizedUserId(UserManager.shared.currentUser?.id)
        graph = loadGraph(for: loadedUserId)
        warmSemanticCache(for: graph)
        writeToAppGroup(graph: graph)
    }

    // MARK: - Constants

    /// 每类实体数量上限（超出后不再新增，防止 JSON 文件膨胀）
    private let maxPeople = 200
    private let maxPlaces = 100
    private let maxEvents = 100
    private let maxFacts = 500

    // MARK: - Properties

    /// 内存中的知识图谱
    private(set) var graph = KBLiteGraph()

    /// 当前内存图谱所属用户。登出态使用独立占位值，绝不沿用上一用户图谱。
    private(set) var loadedUserId = KBLiteManager.signedOutUserId

    /// 用户切换代次，用于丢弃旧用户尚未返回的异步提取结果。
    private var userGeneration = UUID()

    /// 读写锁，保护 graph 的并发访问
    private let graphLock = NSLock()

    /// 是否正在进行提取（避免并发）
    private var isExtracting = false

    /// 提取队列（串行）
    private let extractQueue = DispatchQueue(label: "com.dreamjourney.kblite.extract")

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

    // MARK: - File Path

    private static let signedOutUserId = "signed-out"

    private static func normalizedUserId(_ userId: String?) -> String {
        let value = userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? signedOutUserId : value
    }

    private func graphFilePath(for userId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kbDir = docs.appendingPathComponent("knowledge_base")
        try? FileManager.default.createDirectory(at: kbDir, withIntermediateDirectories: true)
        let userFile = kbDir.appendingPathComponent("kb_graph_\(userId).json")

        // 旧文件只允许迁移一次，避免复制给后续登录的每个用户。
        let legacyFile = kbDir.appendingPathComponent("kb_graph.json")
        if userId != Self.signedOutUserId &&
            !FileManager.default.fileExists(atPath: userFile.path) &&
            FileManager.default.fileExists(atPath: legacyFile.path) {
            do {
                try FileManager.default.moveItem(at: legacyFile, to: userFile)
                print("[KBLite] 已将旧知识库迁移到用户专属文件: \(userFile.lastPathComponent)")
            } catch {
                print("[KBLite] 旧知识库迁移失败: \(error.localizedDescription)")
            }
        }

        return userFile
    }

    // MARK: - Persistence

    private func save() {
        graphLock.lock()
        graph.lastUpdated = Date()
        let graphSnapshot = graph
        let userId = loadedUserId
        graphLock.unlock()

        guard userId != Self.signedOutUserId else {
            print("[KBLite] 登出态不持久化知识图谱")
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(graphSnapshot) else {
            print("[KBLite] ❌ JSON 编码失败")
            return
        }
        do {
            try data.write(to: graphFilePath(for: userId), options: .atomic)
            print("[KBLite] 💾 知识库已保存: \(graphSnapshot.people.count)人, \(graphSnapshot.places.count)地, \(graphSnapshot.events.count)事, \(graphSnapshot.facts.count)实")
        } catch {
            print("[KBLite] ❌ 保存失败: \(error.localizedDescription)")
        }
        // 同步到 App Group 共享容器（供 Widget 读取）
        writeToAppGroup(graph: graphSnapshot)
        // 通知 UI 数据已更新
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
            KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "graphSaved")
        }
    }

    /// 将事件数据写入 App Group 共享容器，供 Widget Extension 读取
    private func writeToAppGroup(graph: KBLiteGraph) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.dreamjourney.shared"
        ) else { return }
        let widgetFile = containerURL.appendingPathComponent("kb_widget_data.json")
        // 只写入 events（Widget 只需要事件数据）
        let widgetEvents = graph.events.map { e -> [String: Any] in
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

    private func loadGraph(for userId: String) -> KBLiteGraph {
        guard userId != Self.signedOutUserId else {
            return KBLiteGraph()
        }
        let filePath = graphFilePath(for: userId)
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("[KBLite] 📂 知识库文件不存在，使用空图谱")
            return KBLiteGraph()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: filePath)
            let loaded = try decoder.decode(KBLiteGraph.self, from: data)
            print("[KBLite] 📂 已加载知识库: v\(loaded.version), \(loaded.people.count)人, \(loaded.places.count)地, \(loaded.events.count)事, \(loaded.facts.count)实, 共\(loaded.sessionCount)次会话")
            return loaded
        } catch {
            print("[KBLite] ⚠️ 知识库加载失败: \(error.localizedDescription)，使用空图谱")
            // 备份损坏文件
            let backupPath = filePath.appendingPathExtension("corrupted")
            try? FileManager.default.moveItem(at: filePath, to: backupPath)
            print("[KBLite] 📦 已备份损坏文件到: \(backupPath.lastPathComponent)")
            return KBLiteGraph()
        }
    }

    private func warmSemanticCache(for graph: KBLiteGraph) {
        DispatchQueue.global(qos: .utility).async {
            KBLiteSemanticSearch.shared.warmCache(
                people: graph.people,
                places: graph.places,
                events: graph.events,
                facts: graph.facts
            )
        }
    }

    /// 在进程内切换知识所有者；旧用户异步结果会因 generation 不匹配而被丢弃。
    func switchUser(to userId: String?) {
        let normalized = Self.normalizedUserId(userId)
        var loadedGraph: KBLiteGraph?
        extractQueue.sync {
            graphLock.lock()
            defer { graphLock.unlock() }
            guard normalized != loadedUserId else { return }
            loadedUserId = normalized
            userGeneration = UUID()
            graph = loadGraph(for: normalized)
            didWarnCapacity = false
            isExtracting = false
            loadedGraph = graph
        }
        guard let loadedGraph else { return }
        warmSemanticCache(for: loadedGraph)
        // Widget 共享快照必须随用户切换（包括登出空图谱）同步替换，
        // 否则 Widget 可能继续展示上一用户的知识。
        writeToAppGroup(graph: loadedGraph)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
        }
        print("[KBLite] 已切换知识所有者: \(normalized)")
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

        graphLock.lock()
        let ownerUserId = loadedUserId
        let extractionGeneration = userGeneration
        let lastBackendExtractionSessionId = graph.lastBackendExtractionSessionId
        let lastBackendExtractionAt = graph.lastBackendExtractionAt
        graphLock.unlock()

        guard ownerUserId != Self.signedOutUserId else {
            print("[KBLite] 登出态跳过知识提取")
            completion(0)
            return
        }

        // 后端精提取使用独立水位；本地轻量提取仍可推进总 sessionCount。
        let shouldForceExtract: Bool
        if let lastBackendExtractionSessionId, let lastBackendExtractionAt {
            shouldForceExtract = sessionId - lastBackendExtractionSessionId >= 3
                || Date().timeIntervalSince(lastBackendExtractionAt) > 86400
        } else {
            shouldForceExtract = true
        }

        guard shouldForceExtract else {
            print("[KBLite] ⏭️ 后端提取频率控制：会话#\(sessionId)使用本地轻量提取")
            extractQueue.async { [weak self] in
                self?.finishExtraction(
                    result: nil,
                    turns: turns,
                    sessionId: sessionId,
                    ownerUserId: ownerUserId,
                    generation: extractionGeneration,
                    fallbackReason: "frequencyControlled",
                    completion: completion
                )
            }
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
            print("[KBLite] 🔍 开始后端知识提取 (会话#\(sessionId), \(turns.count)轮)")

            // 旧后端只读取 transcript；兼容字段同样只携带用户证据，避免 assistant 回灌。
            let transcript = turns.filter { $0.role == "user" }.map { turn in
                "[长辈]: \(turn.text)"
            }.joined(separator: "\n")

            self.graphLock.lock()
            let existingSummary = self.buildExistingSummary()
            self.graphLock.unlock()

            guard DreamJourneyBackendClient.shared.isKnowledgeSyncConfigured else {
                self.finishExtraction(
                    result: nil,
                    turns: turns,
                    sessionId: sessionId,
                    ownerUserId: ownerUserId,
                    generation: extractionGeneration,
                    fallbackReason: "backendNotConfigured",
                    completion: completion
                )
                return
            }

            DreamJourneyBackendClient.shared.extractKnowledge(
                userId: ownerUserId,
                transcript: transcript,
                turns: turns,
                existingSummary: existingSummary,
                sessionId: sessionId
            ) { [weak self] result in
                self?.extractQueue.async {
                    let extraction: KBExtractionResult?
                    let fallbackReason: String?
                    switch result {
                    case .success(let value):
                        extraction = value
                        fallbackReason = nil
                    case .failure(let error):
                        extraction = nil
                        fallbackReason = error.localizedDescription
                    }
                    self?.finishExtraction(
                        result: extraction,
                        turns: turns,
                        sessionId: sessionId,
                        ownerUserId: ownerUserId,
                        generation: extractionGeneration,
                        fallbackReason: fallbackReason,
                        completion: completion
                    )
                }
            }
        }
    }

    private func finishExtraction(
        result: KBExtractionResult?,
        turns: [ConversationTurn],
        sessionId: Int,
        ownerUserId: String,
        generation: UUID,
        fallbackReason: String?,
        completion: @escaping (Int) -> Void
    ) {
        graphLock.lock()
        guard loadedUserId == ownerUserId, userGeneration == generation else {
            graphLock.unlock()
            print("[KBLite] 丢弃旧用户知识提取结果 user=\(ownerUserId)")
            DispatchQueue.main.async { completion(0) }
            return
        }

        let addedCount: Int
        if let result {
            addedCount = mergeExtractionResult(result, sessionId: sessionId)
            graph.lastBackendExtractionSessionId = max(
                graph.lastBackendExtractionSessionId ?? 0,
                sessionId
            )
            graph.lastBackendExtractionAt = Date()
        } else {
            addedCount = quickExtract(turns: turns, sessionId: sessionId)
        }
        graph.sessionCount = max(graph.sessionCount, sessionId)
        graphLock.unlock()
        isExtracting = false
        save()

        if let fallbackReason {
            print("[KBLite] ⚠️ 后端提取降级为本地规则 reason=\(fallbackReason)")
        } else {
            print("[KBLite] ✅ 后端知识提取完成: 新增 \(addedCount) 实体")
        }
        DispatchQueue.main.async {
            KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "extractionCompleted")
            completion(addedCount)
        }
    }

    /// 本地正则快速提取（LLM 不可用时的 fallback）
    /// 复用 ConversationMemoryManager 的维度提取逻辑，但存入知识库
    private func quickExtract(turns: [ConversationTurn], sessionId: Int) -> Int {
        let userTexts = turns.filter { $0.role == "user" }.map { $0.text }
        let allText = userTexts.joined(separator: " ")

        var addedCount = 0

        // 提取人物
        let peopleKeywords = ["爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
                              "爸爸", "妈妈", "父亲", "母亲", "老伴", "老公", "老婆",
                              "哥哥", "姐姐", "弟弟", "妹妹", "叔叔", "阿姨", "舅舅", "姑姑",
                              "儿子", "女儿", "孙子", "孙女", "老师", "师傅", "同学", "战友"]
        for kw in peopleKeywords {
            if allText.contains(kw) {
                let existing = graph.people.first { $0.name == kw || $0.aliases.contains(kw) }
                if existing == nil {
                    var person = KBPerson(id: UUID().uuidString, name: kw, aliases: [], relation: nil,
                                          traits: [], sourceSessionIds: [sessionId],
                                          createdAt: Date(), updatedAt: Date())
                    person.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    graph.people.append(person)
                    addedCount += 1
                } else {
                    // 更新 sessionId
                    if let idx = graph.people.firstIndex(where: { $0.id == existing!.id }) {
                        if !graph.people[idx].sourceSessionIds.contains(sessionId) {
                            graph.people[idx].sourceSessionIds.append(sessionId)
                            graph.people[idx].updatedAt = Date()
                        }
                        if graph.people[idx].privacyMetadata == nil {
                            graph.people[idx].privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                        }
                    }
                }
            }
        }

        // 提取地点
        let cities = ["北京", "上海", "广州", "深圳", "杭州", "南京", "苏州",
                      "成都", "重庆", "武汉", "长沙", "西安", "天津", "青岛",
                      "东北", "四川", "湖南", "湖北", "广东", "江西", "安徽", "河南", "山东"]
        for city in cities {
            if allText.contains(city) {
                let existing = graph.places.first { $0.name == city }
                if existing == nil {
                    var place = KBPlace(id: UUID().uuidString, name: city, sourceSessionIds: [sessionId])
                    place.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    graph.places.append(place)
                    addedCount += 1
                }
            }
        }

        // 提取事件
        let eventKeywords = ["结婚", "上学", "工作", "退休", "当兵", "搬家",
                             "生孩子", "做饭", "种地", "打工", "赶集", "学手艺", "出国", "下海"]
        for kw in eventKeywords {
            if allText.contains(kw) {
                let existing = graph.events.first { $0.title.contains(kw) }
                if existing == nil {
                    var event = KBEvent(id: UUID().uuidString, title: kw, sourceSessionIds: [sessionId])
                    event.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    graph.events.append(event)
                    addedCount += 1
                }
            }
        }

        print("[KBLite] 📝 正则快速提取: 新增 \(addedCount) 实体")
        return addedCount
    }

    private func knowledgePrivacyMetadata(
        sessionId: Int,
        kind: String = "conversationSession",
        title: String = "对话来源"
    ) -> KBPrivacyMetadata {
        .generationAllowed(
            kind: kind,
            id: "session-\(sessionId)",
            title: title
        )
    }

    // MARK: - Private: Prompt Building

    /// 构建已有知识摘要（供 LLM prompt 使用）
    private func buildExistingSummary() -> String {
        if graph.people.isEmpty && graph.places.isEmpty && graph.events.isEmpty {
            return "（暂无已有知识）"
        }

        var lines: [String] = []

        if !graph.people.isEmpty {
            lines.append("已知人物：")
            for p in graph.people.prefix(15) {
                let traits = p.traits.isEmpty ? "" : "（\(p.traits.joined(separator: "、"))）"
                lines.append("  - \(p.name)\(traits)")
            }
        }

        if !graph.places.isEmpty {
            lines.append("已知地点：\(graph.places.prefix(10).map { $0.name }.joined(separator: "、"))")
        }

        if !graph.events.isEmpty {
            lines.append("已知事件：\(graph.events.prefix(10).map { $0.title }.joined(separator: "、"))")
        }

        if !graph.facts.isEmpty {
            let recentFacts = graph.facts.sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
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
    private func mergeExtractionResult(_ result: KBExtractionResult, sessionId: Int) -> Int {
        var addedCount = 0
        let now = Date()

        // 容量检查
        checkCapacity()

        // 1. 合并人物
        for ep in result.people {
            let matched = findMatchingPerson(name: ep.name, aliases: ep.aliases)
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
                    if p.privacyMetadata == nil {
                        p.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    }
                    p.updatedAt = now
                    graph.people[idx] = p
                    print("[KBLite] 🔄 合并人物: \(p.name)")
                }
            } else {
                // 新增人物
                var person = KBPerson(
                    id: UUID().uuidString,
                    name: ep.name,
                    aliases: ep.aliases,
                    relation: ep.relation,
                    traits: ep.traits,
                    briefBio: ep.briefBio,
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now
                )
                person.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                graph.people.append(person)
                addedCount += 1
                print("[KBLite] ➕ 新增人物: \(ep.name)")
            }
        }

        // 2. 合并地点
        for ep in result.places {
            let matched = findMatchingPlace(name: ep.name)
            if let existing = matched {
                if let idx = graph.places.firstIndex(where: { $0.id == existing.id }) {
                    var p = graph.places[idx]
                    if p.description == nil, let desc = ep.description { p.description = desc }
                    if p.category == nil, let cat = ep.category { p.category = cat }
                    if !p.sourceSessionIds.contains(sessionId) { p.sourceSessionIds.append(sessionId) }
                    if p.privacyMetadata == nil {
                        p.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    }
                    graph.places[idx] = p
                    print("[KBLite] 🔄 合并地点: \(p.name)")
                }
            } else {
                var place = KBPlace(
                    id: UUID().uuidString,
                    name: ep.name,
                    category: ep.category,
                    latitude: ep.latitude,
                    longitude: ep.longitude,
                    description: ep.description,
                    sourceSessionIds: [sessionId]
                )
                place.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                graph.places.append(place)
                addedCount += 1
                print("[KBLite] ➕ 新增地点: \(ep.name)")
            }
        }

        // 3. 合并事件
        for ee in result.events {
            let existing = graph.events.first { $0.title == ee.title }
            if let existing = existing {
                if let idx = graph.events.firstIndex(where: { $0.id == existing.id }) {
                    var e = graph.events[idx]
                    if e.description == nil, let desc = ee.description { e.description = desc }
                    if e.year == nil, let y = ee.year { e.year = y }
                    if !e.sourceSessionIds.contains(sessionId) { e.sourceSessionIds.append(sessionId) }
                    if e.privacyMetadata == nil {
                        e.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                    }
                    graph.events[idx] = e
                    print("[KBLite] 🔄 合并事件: \(e.title)")
                }
            } else {
                var event = KBEvent(
                    id: UUID().uuidString,
                    title: ee.title,
                    description: ee.description,
                    year: ee.year,
                    month: ee.month,
                    sourceSessionIds: [sessionId]
                )
                event.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
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
            let isDuplicate = graph.facts.contains { existing in
                existing.statement == stmt ||
                (existing.statement.count >= 10 && stmt.count >= 10 &&
                 (existing.statement.contains(stmt) || stmt.contains(existing.statement)))
            }

            if !isDuplicate {
                var fact = KBFact(
                    id: UUID().uuidString,
                    statement: stmt,
                    confidence: ef.confidence ?? "high",
                    sourceSessionIds: [sessionId]
                )
                fact.privacyMetadata = knowledgePrivacyMetadata(sessionId: sessionId)
                graph.facts.append(fact)
                addedCount += 1
                print("[KBLite] ➕ 新增事实: \(stmt.prefix(40))...")
            }
        }

        return addedCount
    }

    // MARK: - Private: Matching

    /// 查找匹配的人物（按名字、别名）
    private func findMatchingPerson(name: String, aliases: [String]) -> KBPerson? {
        let allNames = [name] + aliases

        // 1. 完全匹配名字
        if let match = graph.people.first(where: { allNames.contains($0.name) }) {
            return match
        }

        // 2. 匹配别名
        if let match = graph.people.first(where: { p in
            p.aliases.contains(where: { alias in allNames.contains(alias) })
        }) {
            return match
        }

        // 3. 模糊匹配（包含关系）
        if name.count >= 2 {
            for p in graph.people {
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
    private func findMatchingPlace(name: String) -> KBPlace? {
        if let match = graph.places.first(where: { $0.name == name }) {
            return match
        }
        // 包含关系匹配（"外滩" ⊂ "上海外滩"）
        for place in graph.places {
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
        buildContextString(query: query, maxItems: maxItems, generationAllowedOnly: false)
    }

    /// 构建允许发送给生成服务的上下文。缺少显式授权元数据的旧数据不会离开设备。
    func buildGenerationAllowedContextString(query: String?, maxItems: Int = 5) -> String {
        let expectedUserId = Self.normalizedUserId(UserManager.shared.currentUser?.id)
        guard loadedUserId == expectedUserId else {
            print(
                "[KBLite] 跳过生成上下文：知识所有者不匹配 " +
                "loaded=\(loadedUserId) expected=\(expectedUserId)"
            )
            return ""
        }
        return buildContextString(query: query, maxItems: maxItems, generationAllowedOnly: true)
    }

    private func buildContextString(
        query: String?,
        maxItems: Int,
        generationAllowedOnly: Bool
    ) -> String {
        var parts: [String] = []
        let graphSnapshot = readGraph { $0 }
        let canGenerateEntity: (KBPrivacyMetadata?) -> Bool = { metadata in
            !generationAllowedOnly || KnowledgeGenerationPolicy.allowsEntity(
                privacyScope: metadata?.scope
            )
        }
        let canGenerateFact: (KBFact) -> Bool = { fact in
            !generationAllowedOnly || KnowledgeGenerationPolicy.allowsFact(
                privacyScope: fact.privacyMetadata?.scope,
                confidence: fact.confidence
            )
        }

        // 有 query → 检索相关知识
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            let result = search(query: q)
            let people = result.people.filter { canGenerateEntity($0.privacyMetadata) }
            let places = result.places.filter { canGenerateEntity($0.privacyMetadata) }
            let events = result.events.filter { canGenerateEntity($0.privacyMetadata) }
            let facts = result.facts.filter(canGenerateFact)

            if !people.isEmpty {
                let summaries: [String] = people.prefix(maxItems).map { p in
                    var line = "\(p.name)"
                    if let rel = p.relation { line += "（\(rel)）" }
                    if !p.traits.isEmpty { line += "，特征：\(p.traits.joined(separator: "、"))" }

                    // 附上关联事实
                    let relatedFacts = graphSnapshot.facts.filter {
                        $0.relatedPersonIds.contains(p.id) && canGenerateFact($0)
                    }
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

            if !places.isEmpty {
                let summaries: [String] = places.prefix(maxItems).map { p in
                    var line = p.name
                    if let cat = p.category { line += "（\(cat)）" }
                    if let desc = p.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关地点】\n" + summaries.joined(separator: "\n"))
            }

            if !events.isEmpty {
                let summaries: [String] = events.prefix(maxItems).map { e in
                    var line = e.title
                    let date = e.formattedDate
                    if !date.isEmpty { line += "（\(date)）" }
                    if let desc = e.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关事件】\n" + summaries.joined(separator: "\n"))
            }

            if !facts.isEmpty {
                let factsText = facts.prefix(maxItems).map { "· \($0.statement)" }.joined(separator: "\n")
                parts.append("【相关事实】\n" + factsText)
            }
        }

        // 无 query 或检索结果为空 → 提供最近摘要
        if parts.isEmpty {
            let recentPeople = graphSnapshot.people
                .filter { canGenerateEntity($0.privacyMetadata) }
                .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            if !recentPeople.isEmpty {
                let names = recentPeople.prefix(5).map { $0.name }.joined(separator: "、")
                parts.append("【已知人物】您提到过：\(names)等")
            }

            let recentEvents = graphSnapshot.events
                .filter { canGenerateEntity($0.privacyMetadata) }
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
    func ingestImageAnalysis(_ result: KBImageAnalysisResult, sessionId: Int) {
        var addedCount = 0
        let now = Date()

        // 场景 → 地点
        if !result.scene.isEmpty {
            let existing = findMatchingPlace(name: result.scene)
            if existing == nil {
                var place = KBPlace(
                    id: UUID().uuidString,
                    name: result.scene,
                    description: result.description,
                    sourceSessionIds: [sessionId],
                    createdAt: now
                )
                place.privacyMetadata = knowledgePrivacyMetadata(
                    sessionId: sessionId,
                    kind: "archiveImageAnalysis",
                    title: "档案素材"
                )
                graph.places.append(place)
                addedCount += 1
            }
        }

        // 检测到的人物 → 尝试添加
        for personDesc in result.detectedPeople {
            // 尝试从描述中提取名字（如 "爷爷"、"奶奶"）
            let name = extractPersonNameFromDescription(personDesc)
            let existing = findMatchingPerson(name: name, aliases: [])
            if existing == nil {
                var person = KBPerson(
                    id: UUID().uuidString,
                    name: name,
                    aliases: [],
                    relation: nil,
                    traits: [],
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now
                )
                person.privacyMetadata = knowledgePrivacyMetadata(
                    sessionId: sessionId,
                    kind: "archiveImageAnalysis",
                    title: "档案素材"
                )
                graph.people.append(person)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            graph.lastUpdated = now
            save()
            print("[KBLite] 🖼️ 图片分析入库: 新增 \(addedCount) 实体")
        }
    }

    /// 从图片人物描述中提取可能的姓名
    private func extractPersonNameFromDescription(_ desc: String) -> String {
        // 尝试匹配常见称谓
        let knownRelations = ["爷爷", "奶奶", "外公", "外婆", "爸爸", "妈妈",
                             "老伴", "儿子", "女儿", "孙子", "孙女"]
        for rel in knownRelations {
            if desc.contains(rel) { return rel }
        }
        // 无法提取具体名字，返回简短描述
        return desc.count <= 6 ? desc : String(desc.prefix(6))
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

    // MARK: - Maintenance

    /// 重置知识库（调试用 / 用户主动清除）
    func reset() {
        graph = KBLiteGraph()
        didWarnCapacity = false
        save()
        print("[KBLite] 🔄 知识库已重置")
    }

    /// 导出知识库为 JSON 字符串（用于备份/分享）
    func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(graph) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func exportGraphDictionary() -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        graphLock.lock()
        let snapshot = graph
        graphLock.unlock()
        guard let data = try? encoder.encode(snapshot),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    /// 应用后端 change feed 的最新完整图谱。
    /// 本机无未同步变更时以后端为准（包括可同步实体的删除），但始终保留
    /// localOnly/旧版无授权元数据的本地实体；本机有变更时按 ID 保留本机版本，
    /// 同时吸收后端新增实体，随后由 coordinator 以新 revision 提交合并结果。
    @discardableResult
    func applySyncedGraph(
        _ dictionary: [String: Any],
        preservingLocalChanges: Bool
    ) -> Bool {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return false
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(KBLiteGraph.self, from: data) else {
            return false
        }
        graphLock.lock()
        if preservingLocalChanges {
            let local = graph
            graph = KBLiteGraph(
                version: max(local.version, imported.version),
                lastUpdated: Date(),
                sessionCount: max(local.sessionCount, imported.sessionCount),
                lastBackendExtractionSessionId: local.lastBackendExtractionSessionId,
                lastBackendExtractionAt: local.lastBackendExtractionAt,
                people: preferLocalByID(remote: imported.people, local: local.people, id: { $0.id }),
                places: preferLocalByID(remote: imported.places, local: local.places, id: { $0.id }),
                events: preferLocalByID(remote: imported.events, local: local.events, id: { $0.id }),
                facts: preferLocalByID(remote: imported.facts, local: local.facts, id: { $0.id })
            )
        } else {
            let local = graph
            graph = KBLiteGraph(
                version: max(local.version, imported.version),
                lastUpdated: Date(),
                sessionCount: max(local.sessionCount, imported.sessionCount),
                lastBackendExtractionSessionId: local.lastBackendExtractionSessionId,
                lastBackendExtractionAt: local.lastBackendExtractionAt,
                people: preferLocalByID(
                    remote: imported.people,
                    local: local.people.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                places: preferLocalByID(
                    remote: imported.places,
                    local: local.places.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                events: preferLocalByID(
                    remote: imported.events,
                    local: local.events.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                facts: preferLocalByID(
                    remote: imported.facts,
                    local: local.facts.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                )
            )
        }
        graph.lastUpdated = Date()
        graphLock.unlock()
        save()
        return true
    }

    private func preferLocalByID<T>(
        remote: [T],
        local: [T],
        id: (T) -> String
    ) -> [T] {
        var localByID: [String: T] = [:]
        local.forEach { localByID[id($0)] = $0 }
        let remoteIDs = Set(remote.map(id))
        let mergedRemote = remote.map { localByID[id($0)] ?? $0 }
        return mergedRemote + local.filter { !remoteIDs.contains(id($0)) }
    }

    private func isRemotelySyncable(_ metadata: KBPrivacyMetadata?) -> Bool {
        guard let scope = metadata?.scope else { return false }
        return scope == "generationAllowed" || scope == "familyCircle"
    }

    /// 从 JSON 字符串导入知识库（合并模式）
    @discardableResult
    func importJSON(_ jsonString: String) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = jsonString.data(using: .utf8),
              let imported = try? decoder.decode(KBLiteGraph.self, from: data) else {
            print("[KBLite] ❌ 导入失败：JSON 解析错误")
            return false
        }
        graphLock.lock()
        let addedCount = mergeGraph(imported)
        graph.lastUpdated = Date()
        graphLock.unlock()
        save()
        print("[KBLite] 📥 导入完成: 新增 \(addedCount) 实体")
        return true
    }

    private func mergeGraph(_ imported: KBLiteGraph) -> Int {
        var addedCount = 0
        for person in imported.people {
            if findMatchingPerson(name: person.name, aliases: person.aliases) == nil {
                graph.people.append(person)
                addedCount += 1
            }
        }
        for place in imported.places {
            if findMatchingPlace(name: place.name) == nil {
                graph.places.append(place)
                addedCount += 1
            }
        }
        for event in imported.events {
            if graph.events.first(where: { $0.title == event.title }) == nil {
                graph.events.append(event)
                addedCount += 1
            }
        }
        for fact in imported.facts {
            if !graph.facts.contains(where: { $0.statement == fact.statement }) {
                graph.facts.append(fact)
                addedCount += 1
            }
        }
        return addedCount
    }

    /// 生成包含知识库上下文的增强开场白提示
    func buildGreetingHint() -> String {
        if isEmpty { return "" }
        var hints: [String] = []
        let recentPeople = graph.people
            .filter { !$0.traits.isEmpty || $0.briefBio != nil }
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
            .filter { $0.year != nil }
            .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            .prefix(2)
        if !recentEvents.isEmpty {
            let eventHints = recentEvents.map { e in "\(e.formattedDate)\(e.title)" }
            hints.append("事件：\(eventHints.joined(separator: "、"))")
        }
        return hints.isEmpty ? "" : hints.joined(separator: "。")
    }
}
