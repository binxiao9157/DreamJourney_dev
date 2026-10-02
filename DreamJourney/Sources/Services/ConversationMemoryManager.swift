import CryptoKit
import Foundation

// MARK: - 数据模型

/// 单轮对话记录
struct ConversationTurn: Codable {
    let role: String     // "user" / "ai"
    let text: String
    let timestamp: Date
}

/// 回忆录四维度摘要（核心数据结构）
/// 所有摘要和开场白都围绕这四个维度组织
struct MemorySummary: Codable {
    var time: String = ""       // 时间：如"1968年"、"小时候"、"退休那几年"
    var place: String = ""      // 地点：如"杭州西湖边"、"老家四川"
    var person: String = ""     // 人物：如"爷爷"、"老伴"、"张老师"
    var event: String = ""      // 事件：如"结婚"、"在工厂上班"、"学做饭"

    /// 是否至少包含一个有意义的维度
    var hasAnyDimension: Bool {
        !time.isEmpty || !place.isEmpty || !person.isEmpty || !event.isEmpty
    }

    /// 有意义的维度数量
    var dimensionCount: Int {
        [!time.isEmpty, !place.isEmpty, !person.isEmpty, !event.isEmpty].filter { $0 }.count
    }

    /// 是否具备足够的上下文来生成关联开场白（至少2个维度）
    var isRichEnough: Bool {
        dimensionCount >= 2
    }

    /// 生成一句话自然摘要（用于开场白和记忆上下文）
    /// 示例："小时候在老家跟爷爷一起做饭"
    func toNaturalSentence() -> String {
        var parts: [String] = []
        if !time.isEmpty { parts.append(time) }
        if !place.isEmpty { parts.append(place) }
        if !person.isEmpty { parts.append("跟\(person)") }
        if !event.isEmpty { parts.append(event) }

        if parts.isEmpty { return "" }

        // 根据维度组合生成自然语句
        if !time.isEmpty && !place.isEmpty && !person.isEmpty && !event.isEmpty {
            return "\(time)在\(place)跟\(person)\(event)"
        }
        if !time.isEmpty && !place.isEmpty && !event.isEmpty {
            return "\(time)在\(place)\(event)"
        }
        if !time.isEmpty && !person.isEmpty && !event.isEmpty {
            return "\(time)跟\(person)\(event)"
        }
        if !place.isEmpty && !person.isEmpty && !event.isEmpty {
            return "在\(place)跟\(person)\(event)"
        }
        // 两维度
        if !time.isEmpty && !event.isEmpty {
            return "\(time)\(event)"
        }
        if !place.isEmpty && !event.isEmpty {
            return "在\(place)\(event)"
        }
        if !person.isEmpty && !event.isEmpty {
            return "跟\(person)\(event)"
        }
        if !time.isEmpty && !place.isEmpty {
            return "\(time)在\(place)的事"
        }
        if !time.isEmpty && !person.isEmpty {
            return "\(time)跟\(person)的事"
        }
        if !place.isEmpty && !person.isEmpty {
            return "在\(place)跟\(person)的事"
        }
        // 单维度
        if !event.isEmpty { return event }
        if !time.isEmpty { return "\(time)的事" }
        if !place.isEmpty { return "在\(place)的事" }
        if !person.isEmpty { return "跟\(person)的事" }
        return ""
    }
}

/// 对话记忆（跨会话持久化）
struct ConversationMemory: Codable {
    var lastSessionDate: Date = Date()
    var lastSummary: MemorySummary = MemorySummary()  // 上次对话的四维度摘要
    var sessionCount: Int = 0                          // 累计对话次数
    var recentTranscript: [ConversationTurn] = []      // 最近一次对话记录（最多保留20轮）

    // 兼容旧数据迁移
    var mentionedPeople: [String] = []
    var mentionedPlaces: [String] = []
    var mentionedFoods: [String] = []
    var lastTopic: String = ""
    var recentTopics: [String] = []
}

private struct ConversationStorageLease: Equatable {
    let accountLease: AccountLease
    let scope: ConversationStorageScope
    let runtimeGeneration: UUID

    static func == (lhs: ConversationStorageLease, rhs: ConversationStorageLease) -> Bool {
        lhs.scope == rhs.scope
            && lhs.accountLease.subjectId == rhs.accountLease.subjectId
            && lhs.accountLease.vaultId == rhs.accountLease.vaultId
            && lhs.accountLease.generation == rhs.accountLease.generation
            && lhs.accountLease.generationId == rhs.accountLease.generationId
            && lhs.accountLease.authorityEpoch == rhs.accountLease.authorityEpoch
            && lhs.runtimeGeneration == rhs.runtimeGeneration
    }
}

// MARK: - ConversationMemoryManager

/// 对话记忆管理器 - 围绕时间/地点/人物/事件四维度提取摘要
final class ConversationMemoryManager {

    static let shared = ConversationMemoryManager()
    private init() {
        let center = NotificationCenter.default
        lifecycleObservationTokens = [
            center.addObserver(forName: .djUserDidLogin, object: nil, queue: .main) { [weak self] _ in
                self?.refreshForCurrentContext()
            },
            center.addObserver(forName: .djUserDidLogout, object: nil, queue: .main) { [weak self] _ in
                self?.unmountAndDiscardPendingTranscript(reason: "logout")
            },
            center.addObserver(forName: .djPrivateAccessDidSuspend, object: nil, queue: .main) { [weak self] _ in
                self?.unmountAndDiscardPendingTranscript(reason: "privateAccessSuspended")
            },
        ]
        refreshForCurrentContext()
    }

    // MARK: - Public

    /// 当前持久化的记忆
    private(set) var currentMemory = ConversationMemory()

    /// 当前会话的临时对话记录
    private var currentTranscript: [ConversationTurn] = []
    private var loadedStorageLease: ConversationStorageLease?
    private var transcriptStorageLease: ConversationStorageLease?
    private var runtimeGeneration = UUID()
    private var lifecycleObservationTokens: [NSObjectProtocol] = []
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let localStorage = ConversationLocalStorage.shared

    func refreshForCurrentContext() {
        guard let lease = currentConversationStorageLease,
              isCurrentConversationStorageLease(lease, at: .request) else {
            unmountAndDiscardPendingTranscript(reason: "noActiveAccountLease")
            return
        }
        guard loadedStorageLease != lease else { return }
        if !currentTranscript.isEmpty {
            print("[Memory] discarded pending transcript after account/persona scope changed")
        }
        currentTranscript = []
        transcriptStorageLease = nil
        loadedStorageLease = lease
        currentMemory = localStorage.mount(scope: lease.scope) { [weak self] in
            self?.isCurrentConversationStorageLease(lease, at: .commit) == true
        }
        let summary = currentMemory.lastSummary
        PrivacySafeDiagnostics.log(
            subsystem: "Memory",
            event: "ownerScopedMemoryMounted",
            counts: [
                "sessionCount": currentMemory.sessionCount,
                "summaryDimensionCount": summary.dimensionCount,
            ]
        )
    }

    /// 获取当前会话的对话记录（用于回忆录生成等）
    func getCurrentTranscript() -> [ConversationTurn] {
        refreshForCurrentContext()
        if !currentTranscript.isEmpty {
            return currentTranscript
        }
        return currentMemory.recentTranscript
    }

    // MARK: - 记录对话

    func recordUserTurn(text: String) {
        guard recordTurn(role: "user", text: text) else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "Memory",
            event: "conversationTurnRecorded",
            states: ["role": "user"],
            counts: ["textUTF8ByteCount": text.utf8.count]
        )
    }

    func recordAITurn(text: String) {
        guard recordTurn(role: "ai", text: text) else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "Memory",
            event: "conversationTurnRecorded",
            states: ["role": "assistant"],
            counts: ["textUTF8ByteCount": text.utf8.count]
        )
    }

    /// 对话结束时调用：提取四维度摘要并持久化
    func endSession() {
        guard !currentTranscript.isEmpty,
              let sessionLease = transcriptStorageLease,
              loadedStorageLease == sessionLease,
              isCurrentConversationStorageLease(sessionLease, at: .commit) else {
            if !currentTranscript.isEmpty {
                print("[Memory] rejected stale transcript commit")
                currentTranscript = []
                transcriptStorageLease = nil
            }
            return
        }

        // 提取四维度摘要
        var updatedMemory = currentMemory
        updatedMemory.lastSummary = extractFourDimensionSummary()

        // 更新元数据
        updatedMemory.lastSessionDate = Date()
        updatedMemory.sessionCount += 1
        updatedMemory.recentTranscript = Array(currentTranscript.suffix(20))

        // 清理旧字段
        updatedMemory.mentionedPeople = []
        updatedMemory.mentionedPlaces = []
        updatedMemory.mentionedFoods = []
        updatedMemory.lastTopic = ""
        updatedMemory.recentTopics = []

        // 持久化
        do {
            try localStorage.save(
                memory: updatedMemory,
                scope: sessionLease.scope
            ) { [weak self] in
                self?.isCurrentConversationStorageLease(sessionLease, at: .commit) == true
            }
        } catch {
            PrivacySafeDiagnostics.log(
                subsystem: "Memory",
                event: "ownerScopedMemorySaveFailed",
                states: ["failure": "storageFailure"]
            )
            return
        }
        guard isCurrentConversationStorageLease(sessionLease, at: .commit) else {
            currentTranscript = []
            transcriptStorageLease = nil
            return
        }
        currentMemory = updatedMemory

        // 捕获 transcript 快照（清空前）
        let transcriptSnapshot = currentTranscript
        let sessionId = updatedMemory.sessionCount
        let knowledgeAuthorization = KBLiteManager.captureCurrentPersonaAuthorizationSnapshot()
        let accountLease = sessionLease.accountLease

        // 清空当前会话临时记录
        currentTranscript = []
        transcriptStorageLease = nil

        let summary = updatedMemory.lastSummary
        PrivacySafeDiagnostics.log(
            subsystem: "Memory",
            event: "conversationSummaryPersisted",
            counts: [
                "sessionCount": updatedMemory.sessionCount,
                "summaryDimensionCount": summary.dimensionCount,
                "transcriptTurnCount": transcriptSnapshot.count,
            ]
        )

        // 【KBLite】触发 LLM 知识提取（异步，不阻塞 UI）
        DispatchQueue.global(qos: .utility).async { [accountLeaseRuntime] in
            guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                print("[Memory] skipped stale transcript knowledge extraction")
                return
            }
            KBLiteManager.shared.extractFromTranscript(
                turns: transcriptSnapshot,
                sessionId: sessionId,
                authorizationSnapshot: knowledgeAuthorization
            ) { addedCount in
                if addedCount > 0 {
                    print("[Memory] 🧠 知识库新增 \(addedCount) 实体")
                }
            }
        }
    }

    @discardableResult
    func purgeLocalDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        let targetsMountedScope = loadedStorageLease.map {
            Self.isSameAccountLeaseGeneration($0.accountLease, accountLease)
        } == true
        guard targetsMountedScope
                || accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }
        localStorage.purge(accountLease: accountLease)
        if loadedStorageLease?.accountLease.subjectId == accountLease.subjectId,
           loadedStorageLease?.accountLease.vaultId == accountLease.vaultId {
            unmountAndDiscardPendingTranscript(reason: "accountDeletion")
        }
        return true
    }

    /// Unmounts conversation runtime using the lifecycle operation's captured old scope.
    /// Owner-scoped files remain locked for recovery except during an explicit account deletion.
    @discardableResult
    func teardownForAccountLifecycle(
        context: AccountLifecycleContext
    ) -> AccountLifecycleModuleResult {
        performSynchronouslyOnMain {
            if let oldAccountLease = context.oldAccountLease,
               let mountedAccountLease = loadedStorageLease?.accountLease,
               !Self.isSameAccountLeaseGeneration(mountedAccountLease, oldAccountLease) {
                return .completed(
                    .failed,
                    remainingLocalData: true,
                    detailCode: "conversationTeardownScopeMismatch"
                )
            }

            switch context.event {
            case .accountDeletion:
                guard let oldAccountLease = context.oldAccountLease else {
                    unmountAndDiscardPendingTranscript(reason: "accountDeletionMissingLease")
                    return .completed(
                        .failed,
                        remainingLocalData: true,
                        detailCode: "conversationDeletionLeaseUnavailable"
                    )
                }
                guard purgeLocalDataForAccountDeletion(accountLease: oldAccountLease) else {
                    unmountAndDiscardPendingTranscript(reason: "accountDeletionPurgeFailed")
                    return .completed(
                        .failed,
                        remainingLocalData: true,
                        detailCode: "conversationDeletionPurgeFailed"
                    )
                }
                return .completed(
                    .purged,
                    remainingLocalData: false,
                    detailCode: "conversationDeletionPurged"
                )

            case .coldStartRecovery:
                unmountAndDiscardPendingTranscript(reason: "coldStartRecovery")
                return .completed(
                    .unmounted,
                    remainingLocalData: true,
                    detailCode: "conversationColdStartUnmounted"
                )

            case .switchAccount:
                unmountAndDiscardPendingTranscript(reason: "switchAccount")
                return .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "conversationSwitchRetainedLocked"
                )

            case .logout:
                unmountAndDiscardPendingTranscript(reason: "logout")
                return .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "conversationLogoutRetainedLocked"
                )

            case .privateSuspension:
                unmountAndDiscardPendingTranscript(reason: "privateSuspension")
                return .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "conversationSuspensionRetainedLocked"
                )
            }
        }
    }

    // MARK: - 四维度摘要提取

    /// 从对话中提取时间/地点/人物/事件四维度摘要
    private func extractFourDimensionSummary() -> MemorySummary {
        let userTexts = currentTranscript
            .filter { $0.role == "user" }
            .map { $0.text }
        let userAllText = userTexts.joined(separator: " ")

        var summary = MemorySummary()

        // 1. 提取时间
        summary.time = extractTime(from: userAllText)

        // 2. 提取地点
        summary.place = extractPlace(from: userAllText)

        // 3. 提取人物
        summary.person = extractPerson(from: userAllText)

        // 4. 提取事件
        summary.event = extractEvent(from: userAllText, userTexts: userTexts)

        return summary
    }

    // MARK: - 时间提取

    /// 从文本中提取时间描述
    private func extractTime(from text: String) -> String {
        // 检查精确年份
        if let regex = try? NSRegularExpression(pattern: "(\\d{3,4})年"),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 0), in: text) {
                return String(text[range])  // 如"1968年"
            }
        }

        // 模糊时间关键词（按优先级）
        let timeKeywords = [
            "小时候", "年轻时候", "年轻那会儿", "年轻时",
            "上学那会儿", "刚工作那会儿", "结婚那会儿",
            "以前", "那时候", "那会儿",
            "退休前", "退休以后", "退休后",
            "过年", "过节", "中秋节", "端午节",
        ]
        for keyword in timeKeywords {
            if text.contains(keyword) {
                return keyword
            }
        }

        return ""
    }

    // MARK: - 地点提取

    /// 从文本中提取地点描述
    private func extractPlace(from text: String) -> String {
        // 精确城市名
        let cities = [
            "北京", "上海", "广州", "深圳", "杭州", "南京", "苏州",
            "成都", "重庆", "武汉", "长沙", "西安", "天津", "青岛",
            "东北", "四川", "湖南", "湖北", "广东", "江西", "安徽", "河南", "山东",
        ]
        for city in cities {
            if text.contains(city) {
                // 尝试提取更完整的地名
                return extractContextAround(keyword: city, in: text, prefixLen: 2, suffixLen: 1)
            }
        }

        // 模糊地点
        let placeKeywords = [
            "老家", "老房子", "村里", "乡下",
            "学校", "工厂", "部队", "医院",
        ]
        for keyword in placeKeywords {
            if text.contains(keyword) {
                return extractContextAround(keyword: keyword, in: text, prefixLen: 2, suffixLen: 1)
            }
        }

        return ""
    }

    // MARK: - 人物提取

    /// 从文本中提取人物描述
    private func extractPerson(from text: String) -> String {
        let peopleKeywords = [
            "爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
            "爸爸", "妈妈", "父亲", "母亲",
            "老伴", "老公", "老婆", "丈夫", "妻子",
            "哥哥", "姐姐", "弟弟", "妹妹",
            "叔叔", "阿姨", "舅舅", "姑姑",
            "儿子", "女儿", "孙子", "孙女",
            "老师", "师傅", "邻居", "同学", "战友",
        ]
        for keyword in peopleKeywords {
            if text.contains(keyword) {
                return keyword
            }
        }
        return ""
    }

    // MARK: - 事件提取

    /// 从文本中提取事件描述
    private func extractEvent(from text: String, userTexts: [String]) -> String {
        // 事件关键词
        let eventKeywords = [
            "结婚", "上学", "工作", "退休", "当兵", "搬家",
            "生孩子", "生了个", "做饭", "种地", "打工",
            "赶集", "学手艺", "出国", "下海",
        ]
        for keyword in eventKeywords {
            if text.contains(keyword) {
                return extractContextAround(keyword: keyword, in: text, prefixLen: 2, suffixLen: 2)
            }
        }

        // 从有意义的用户语句中提取最后一条作为事件
        let meaningful = userTexts.filter { isMeaningfulStatement($0) }
        if let last = meaningful.last {
            let trimmed = String(last.prefix(15)).trimmingCharacters(in: .whitespaces)
            return trimmed
        }

        return ""
    }

    // MARK: - 辅助方法

    /// 在关键词前后提取上下文，形成更完整的描述
    private func extractContextAround(keyword: String, in text: String, prefixLen: Int, suffixLen: Int) -> String {
        guard let range = text.range(of: keyword) else { return keyword }
        let startIdx = text.index(range.lowerBound, offsetBy: -prefixLen, limitedBy: text.startIndex) ?? text.startIndex
        let endIdx = text.index(range.upperBound, offsetBy: suffixLen, limitedBy: text.endIndex) ?? text.endIndex
        let context = String(text[startIdx..<endIdx]).trimmingCharacters(in: .whitespaces)
        return context.count >= keyword.count ? context : keyword
    }

    /// 判断一段文本是否是有意义的陈述（非寒暄/应答/模板）
    private func isMeaningfulStatement(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 3 else { return false }

        // 黑名单
        let blacklist = [
            "你好", "您好", "嗳", "嗯", "啊", "哦", "好", "好的", "好吧",
            "行", "可以", "对", "是", "不是", "没有", "有",
            "谢谢", "不客气", "再见", "拜拜",
            "嘿", "嗨", "哈", "哈哈", "呵呵",
            "不知道", "忘了", "想不起来",
            "帮我生成回忆录", "生成回忆录", "回忆录",
        ]
        if blacklist.contains(where: { trimmed == $0 }) { return false }

        // 模板句式
        let templates = [
            "又来找我", "又见面啦", "上次您跟我说", "上回咱们聊到",
            "我一直记着", "今天想聊点什么", "今天想呢",
            "您好呀，我是寻梦环游", "我是寻梦环游", "想跟您聊聊天",
            "上次聊的", "我可还记得",
        ]
        if templates.contains(where: { trimmed.contains($0) }) { return false }

        // 至少4字且非纯应答
        return trimmed.count >= 4
    }

    // MARK: - Owner-scoped persistence

    private var currentConversationStorageLease: ConversationStorageLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        let context = DigitalHumanContextStore.shared.current
        let personaScope: ConversationPersonaScope = context.isSelfAssistant ? .personal : .family
        let contextOwner = context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerId = personaScope == .personal ? userId : contextOwner
        guard let scope = ConversationStorageScope(
            accountLease: accountLease,
            ownerId: ownerId,
            personaScope: personaScope
        ) else {
            return nil
        }
        return ConversationStorageLease(
            accountLease: accountLease,
            scope: scope,
            runtimeGeneration: runtimeGeneration
        )
    }

    private func isCurrentConversationStorageLease(
        _ lease: ConversationStorageLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        guard accountLeaseRuntime.validate(lease.accountLease, at: checkpoint).allowed,
              let current = currentConversationStorageLease else {
            return false
        }
        return current == lease
    }

    private func recordTurn(role: String, text: String) -> Bool {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return false }
        refreshForCurrentContext()
        guard let lease = loadedStorageLease,
              isCurrentConversationStorageLease(lease, at: .commit) else {
            return false
        }
        if let transcriptStorageLease {
            guard transcriptStorageLease == lease else {
                currentTranscript = []
                self.transcriptStorageLease = nil
                return false
            }
        } else {
            transcriptStorageLease = lease
        }
        currentTranscript.append(
            ConversationTurn(role: role, text: normalizedText, timestamp: Date())
        )
        return true
    }

    private func unmountAndDiscardPendingTranscript(reason: String) {
        runtimeGeneration = UUID()
        if !currentTranscript.isEmpty {
            PrivacySafeDiagnostics.log(
                subsystem: "Memory",
                event: "uncommittedTranscriptDiscarded",
                states: ["reason": reason],
                counts: ["turnCount": currentTranscript.count]
            )
        }
        currentTranscript = []
        transcriptStorageLease = nil
        loadedStorageLease = nil
        currentMemory = ConversationMemory()
    }

    private static func isSameAccountLeaseGeneration(
        _ lhs: AccountLease,
        _ rhs: AccountLease
    ) -> Bool {
        lhs.subjectId == rhs.subjectId
            && lhs.vaultId == rhs.vaultId
            && lhs.generation == rhs.generation
            && lhs.generationId == rhs.generationId
            && lhs.authorityEpoch == rhs.authorityEpoch
    }

    private func performSynchronouslyOnMain<T>(_ block: () -> T) -> T {
        if Thread.isMainThread {
            return block()
        }
        return DispatchQueue.main.sync(execute: block)
    }
}

/// A deliberately narrow diagnostics surface for private-memory runtime paths.
/// It only accepts state codes, counts, and one-way correlation hashes so console
/// output cannot become another copy of user memory, Provider payloads, or IDs.
enum PrivacySafeDiagnostics {
    static let redactionPolicyVersion = "iosDiagnostics-v1"
    private static let correlationDigestLength = 16

    static func correlationHash(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else { return "none" }
        let digest = SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "sha256:" + String(digest.prefix(correlationDigestLength))
    }

    static func correlationHash(_ value: Data) -> String {
        guard !value.isEmpty else { return "none" }
        let digest = SHA256.hash(data: value)
            .map { String(format: "%02x", $0) }
            .joined()
        return "sha256:" + String(digest.prefix(correlationDigestLength))
    }

    static func safeCode(_ value: String?, fallback: String = "redacted") -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty,
              normalized.utf8.count <= 96,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 48...57, 65...90, 97...122, 45, 46, 58, 95:
                      return true
                  default:
                      return false
                  }
              }) else {
            return fallback
        }
        return normalized
    }

    static func log(
        subsystem: String,
        event: String,
        states: [String: String] = [:],
        counts: [String: Int] = [:],
        correlations: [String: String?] = [:]
    ) {
        var fields = [
            "policy=" + redactionPolicyVersion,
            "event=" + safeCode(event, fallback: "redactedEvent"),
        ]
        fields += states.keys.sorted().map { key in
            safeCode(key, fallback: "state") + "=" + safeCode(states[key], fallback: "redactedState")
        }
        fields += counts.keys.sorted().map { key in
            safeCode(key, fallback: "count") + "=" + String(max(0, counts[key] ?? 0))
        }
        fields += correlations.keys.sorted().map { key in
            safeCode(key, fallback: "correlation") + "=" + correlationHash(correlations[key] ?? nil)
        }
        print("[\(safeCode(subsystem, fallback: "Diagnostics"))] " + fields.joined(separator: " "))
    }
}

struct NativeLiveDiagnosticEvent: Codable, Equatable, Sendable {
    let sequence: UInt64
    let monotonicMilliseconds: UInt64
    let recordedAt: Date
    let source: String
    let event: String
    let eventCode: Int?
    let callbackOrdinal: UInt64?
    let sessionHash: String
    let questionHash: String
    let replyHash: String
    let reason: String?
    let speakingBefore: Bool?
    let speakingAfter: Bool?
    let resultCode: Int?
    let requestExposure: String?
    let errorDomain: String?
    let errorCode: String?
    let elapsedMilliseconds: Int?
    let requestAttempt: Int?
}

struct NativeLiveDiagnosticSnapshot: Equatable, Sendable {
    let events: [NativeLiveDiagnosticEvent]
    let droppedCount: Int
    let firstCriticalFailure: NativeLiveDiagnosticEvent?
    let firstRequestFailure: NativeLiveDiagnosticEvent?
    let persistenceUnavailable: Bool

    init(
        events: [NativeLiveDiagnosticEvent],
        droppedCount: Int,
        firstCriticalFailure: NativeLiveDiagnosticEvent? = nil,
        firstRequestFailure: NativeLiveDiagnosticEvent? = nil,
        persistenceUnavailable: Bool = false
    ) {
        self.events = events
        self.droppedCount = droppedCount
        self.firstCriticalFailure = firstCriticalFailure
        self.firstRequestFailure = firstRequestFailure
        self.persistenceUnavailable = persistenceUnavailable
    }
}

/// Bounded, account-scoped evidence for native Live event ordering. The
/// persisted envelope contains only approved state codes, numeric values, and
/// one-way correlations; it never accepts transcript or provider payload text.
final class NativeLiveDiagnosticsRingStore {
    static let shared = NativeLiveDiagnosticsRingStore()

    private static let schemaVersion = "native-live-diagnostics-v1"

    private struct Envelope: Codable {
        let schemaVersion: String
        let scopeDigest: String
        let sessionHash: String
        var events: [NativeLiveDiagnosticEvent]
        var droppedCount: Int
        var firstCriticalFailure: NativeLiveDiagnosticEvent?
        var firstRequestFailure: NativeLiveDiagnosticEvent?
        var isActive: Bool?
        var activePinReleasedAt: Date?
        let createdAt: Date
        var updatedAt: Date
    }

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let maximumEventCount: Int
    private let maximumSessionCount: Int
    private let maximumTotalBytes: Int
    private let retentionInterval: TimeInterval
    private let costObservation: ((String, Double, Int) -> Void)?
    private func measured<T>(_ stage: String, bytes: Int = 0, _ body: () throws -> T) rethrows -> T {
        guard let costObservation else { return try body() }
        let start = ProcessInfo.processInfo.systemUptime
        defer { costObservation(stage, (ProcessInfo.processInfo.systemUptime - start) * 1000, bytes) }
        return try body()
    }
    private let queue: DispatchQueue
    private var unavailableSessionKeys: [String] = []
    private let admissionLock = NSLock()
    private var pendingOrdinaryEvents = 0
    // Only routine PCM notifications are sampled. Identity/lifecycle/error
    // records and the first-failure slots retain their existing guarantees.
    private var audioSampleOrdinals: [String: Int] = [:]
    private func admitAudioSample(scope: String) -> Bool {
        admissionLock.lock(); defer { admissionLock.unlock() }
        guard audioSampleOrdinals[scope] != nil || audioSampleOrdinals.count < 16 else { return true }
        let ordinal = audioSampleOrdinals[scope, default: 0]
        audioSampleOrdinals[scope] = (ordinal + 1) % 50
        guard ordinal == 0 else {
            if droppedBeforeEnqueue[scope] != nil || droppedBeforeEnqueue.count < 16 {
                droppedBeforeEnqueue[scope, default: 0] += 1
            }
            return false
        }
        return true
    }
    private var droppedBeforeEnqueue: [String: Int] = [:]

    private func reserveOrdinaryEvent(scope: String) -> Bool {
        admissionLock.lock(); defer { admissionLock.unlock() }
        guard pendingOrdinaryEvents < 256 else {
            if droppedBeforeEnqueue[scope] != nil || droppedBeforeEnqueue.count < 16 {
                droppedBeforeEnqueue[scope, default: 0] += 1
            }
            return false
        }
        pendingOrdinaryEvents += 1
        return true
    }

    private func finishOrdinaryEvent() {
        admissionLock.lock(); pendingOrdinaryEvents -= 1; admissionLock.unlock()
    }

    private func takeDroppedCount(scope: String) -> Int {
        admissionLock.lock(); defer { admissionLock.unlock() }
        return droppedBeforeEnqueue.removeValue(forKey: scope) ?? 0
    }

    private func markPersistenceUnavailable(scopeDigest: String, sessionHash: String) {
        let key = scopeDigest + ":" + sessionHash
        guard !unavailableSessionKeys.contains(key) else { return }
        unavailableSessionKeys.append(key)
        if unavailableSessionKeys.count > 16 {
            unavailableSessionKeys.removeFirst(unavailableSessionKeys.count - 16)
        }
    }

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        maximumEventCount: Int = 4_096,
        maximumSessionCount: Int = 3,
        maximumTotalBytes: Int = 2 * 1_024 * 1_024,
        retentionInterval: TimeInterval = 48 * 60 * 60,
        queueLabel: String = "com.dreamjourney.native-live-diagnostics",
        costObservation: ((String, Double, Int) -> Void)? = nil
    ) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.rootDirectory = rootDirectory ?? applicationSupport.appendingPathComponent(
            "NativeLiveDiagnostics",
            isDirectory: true
        )
        self.costObservation = costObservation
        self.fileManager = fileManager
        self.now = now
        self.maximumEventCount = max(1, maximumEventCount)
        self.maximumSessionCount = max(1, maximumSessionCount)
        self.maximumTotalBytes = max(1_024, maximumTotalBytes)
        self.retentionInterval = max(1, retentionInterval)
        queue = DispatchQueue(label: queueLabel, qos: .utility)
    }

    func record(
        accountLease: AccountLease,
        providerSessionID: String,
        source: String,
        event: String,
        eventCode: Int? = nil,
        callbackOrdinal: UInt64? = nil,
        questionID: String? = nil,
        replyID: String? = nil,
        reason: String? = nil,
        speakingBefore: Bool? = nil,
        speakingAfter: Bool? = nil,
        resultCode: Int? = nil
    ) {
        let scopeDigest = Self.scopeDigest(for: accountLease)
        let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
        let safeSource = PrivacySafeDiagnostics.safeCode(source, fallback: "unknown")
        let safeEvent = PrivacySafeDiagnostics.safeCode(event, fallback: "unknown")
        let safeReason = reason.map {
            PrivacySafeDiagnostics.safeCode($0, fallback: "redacted")
        }
        let questionHash = PrivacySafeDiagnostics.correlationHash(questionID)
        let replyHash = PrivacySafeDiagnostics.correlationHash(replyID)
        if safeSource == "sdk", safeEvent == "providerCallback", eventCode == 3018,
           safeReason == nil, resultCode == nil,
           !admitAudioSample(scope: scopeDigest + ":" + sessionHash) { return }
        guard reserveOrdinaryEvent(scope: scopeDigest + ":" + sessionHash) else { return }
        let enqueuedAt = costObservation == nil ? 0 : ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self else { return }
            defer { self.finishOrdinaryEvent() }
            self.costObservation?("queueWait", (ProcessInfo.processInfo.systemUptime - enqueuedAt) * 1000, 0)
            self.recordOnQueue(
                scopeDigest: scopeDigest,
                sessionHash: sessionHash,
                source: safeSource,
                event: safeEvent,
                eventCode: eventCode,
                callbackOrdinal: callbackOrdinal,
                questionHash: questionHash,
                replyHash: replyHash,
                reason: safeReason,
                speakingBefore: speakingBefore,
                speakingAfter: speakingAfter,
                resultCode: resultCode,
                preservesFirstCriticalFailure: false
            )
        }
    }

    func recordFirstCriticalFailure(
        accountLease: AccountLease,
        providerSessionID: String,
        stage: String,
        reason: String,
        callbackOrdinal: UInt64? = nil
    ) {
        let scopeDigest = Self.scopeDigest(for: accountLease)
        let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
        let safeStage = PrivacySafeDiagnostics.safeCode(stage, fallback: "unknown")
        let safeReason = PrivacySafeDiagnostics.safeCode(reason, fallback: "redacted")
        queue.async { [weak self] in
            self?.recordOnQueue(
                scopeDigest: scopeDigest,
                sessionHash: sessionHash,
                source: safeStage,
                event: "firstCaptureFailure",
                eventCode: nil,
                callbackOrdinal: callbackOrdinal,
                questionHash: PrivacySafeDiagnostics.correlationHash(nil),
                replyHash: PrivacySafeDiagnostics.correlationHash(nil),
                reason: safeReason,
                speakingBefore: nil,
                speakingAfter: nil,
                resultCode: nil,
                preservesFirstCriticalFailure: true
            )
        }
    }

    func recordFirstRequestFailure(
        accountLease: AccountLease,
        providerSessionID: String,
        commandID: String?,
        messageID: String?,
        sequence: Int?,
        stage: String,
        reason: String,
        httpStatus: Int? = nil,
        requestExposure: String? = nil,
        errorDomain: String? = nil,
        errorCode: String? = nil,
        elapsedMilliseconds: Int? = nil,
        attempt: Int? = nil
    ) {
        let scopeDigest = Self.scopeDigest(for: accountLease)
        let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
        let commandHash = PrivacySafeDiagnostics.correlationHash(commandID)
        let messageHash = PrivacySafeDiagnostics.correlationHash(messageID)
        let safeStage = PrivacySafeDiagnostics.safeCode(stage, fallback: "unknown")
        let safeReason = PrivacySafeDiagnostics.safeCode(reason, fallback: "unknown")
        queue.async { [weak self] in
            self?.recordOnQueue(
                scopeDigest: scopeDigest,
                sessionHash: sessionHash,
                source: safeStage,
                event: "firstRequestFailure",
                eventCode: httpStatus,
                callbackOrdinal: sequence.flatMap { $0 >= 0 ? UInt64($0) : nil },
                questionHash: commandHash,
                replyHash: messageHash,
                reason: safeReason,
                speakingBefore: nil,
                speakingAfter: nil,
                resultCode: nil,
                preservesFirstCriticalFailure: false,
                preservesFirstRequestFailure: true,
                requestExposure: requestExposure.map { PrivacySafeDiagnostics.safeCode($0, fallback: "unknown") },
                errorDomain: errorDomain.map { PrivacySafeDiagnostics.safeCode($0, fallback: "unknown") },
                errorCode: errorCode.map { PrivacySafeDiagnostics.safeCode($0, fallback: "unknown") },
                elapsedMilliseconds: elapsedMilliseconds.map { max(0, $0) },
                requestAttempt: attempt.map { max(1, $0) }
            )
        }
    }

    func beginActiveSession(
        accountLease: AccountLease,
        providerSessionID: String
    ) {
        let scopeDigest = Self.scopeDigest(for: accountLease)
        let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
        queue.async { [weak self] in
            self?.setActiveSessionOnQueue(
                scopeDigest: scopeDigest,
                sessionHash: sessionHash,
                active: true
            )
        }
    }

    func endActiveSession(
        accountLease: AccountLease,
        providerSessionID: String
    ) {
        let scopeDigest = Self.scopeDigest(for: accountLease)
        let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
        queue.async { [weak self] in
            self?.setActiveSessionOnQueue(
                scopeDigest: scopeDigest,
                sessionHash: sessionHash,
                active: false
            )
        }
    }

    func snapshot(accountLease: AccountLease, providerSessionID: String) -> NativeLiveDiagnosticSnapshot {
        queue.sync { snapshotOnQueue(accountLease: accountLease, providerSessionID: providerSessionID) }
    }

    func snapshotAsync(accountLease: AccountLease, providerSessionID: String,
        completion: @escaping (NativeLiveDiagnosticSnapshot) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let result = self.snapshotOnQueue(accountLease: accountLease, providerSessionID: providerSessionID)
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func snapshotOnQueue(accountLease: AccountLease, providerSessionID: String) -> NativeLiveDiagnosticSnapshot {
    let scopeDigest = Self.scopeDigest(for: accountLease)
    let sessionHash = PrivacySafeDiagnostics.correlationHash(providerSessionID)
    guard let envelope = readEnvelope(
        at: fileURL(scopeDigest: scopeDigest, sessionHash: sessionHash),
        scopeDigest: scopeDigest,
        sessionHash: sessionHash
    ) else {
        return NativeLiveDiagnosticSnapshot(
            events: [], droppedCount: 0,
            persistenceUnavailable: unavailableSessionKeys.contains(
                scopeDigest + ":" + sessionHash
            )
        )
    }
    return NativeLiveDiagnosticSnapshot(
        events: envelope.events,
        droppedCount: envelope.droppedCount,
        firstCriticalFailure: envelope.firstCriticalFailure,
        firstRequestFailure: envelope.firstRequestFailure,
        persistenceUnavailable: unavailableSessionKeys.contains(
            scopeDigest + ":" + sessionHash
        )
    )
    }

    func waitForPendingWrites() {
        queue.sync {}
    }

    private func recordOnQueue(
        scopeDigest: String,
        sessionHash: String,
        source: String,
        event: String,
        eventCode: Int?,
        callbackOrdinal: UInt64?,
        questionHash: String,
        replyHash: String,
        reason: String?,
        speakingBefore: Bool?,
        speakingAfter: Bool?,
        resultCode: Int?,
        preservesFirstCriticalFailure: Bool,
        preservesFirstRequestFailure: Bool = false,
        requestExposure: String? = nil,
        errorDomain: String? = nil,
        errorCode: String? = nil,
        elapsedMilliseconds: Int? = nil,
        requestAttempt: Int? = nil
    ) {
        let beganAt = costObservation == nil ? 0 : ProcessInfo.processInfo.systemUptime
        defer { costObservation?("execution", (ProcessInfo.processInfo.systemUptime - beganAt) * 1000, 0) }
        let timestamp = now()
        let url = fileURL(scopeDigest: scopeDigest, sessionHash: sessionHash)
        var envelope = readEnvelope(
            at: url,
            scopeDigest: scopeDigest,
            sessionHash: sessionHash
        ) ?? Envelope(
            schemaVersion: Self.schemaVersion,
            scopeDigest: scopeDigest,
            sessionHash: sessionHash,
            events: [],
            droppedCount: 0,
            firstCriticalFailure: nil,
            firstRequestFailure: nil,
            isActive: nil,
            activePinReleasedAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        envelope.droppedCount += takeDroppedCount(scope: scopeDigest + ":" + sessionHash)
        let nextSequence = (envelope.events.last?.sequence ?? 0) &+ 1
        let diagnostic = NativeLiveDiagnosticEvent(
            sequence: nextSequence,
            monotonicMilliseconds: DispatchTime.now().uptimeNanoseconds / 1_000_000,
            recordedAt: timestamp,
            source: source,
            event: event,
            eventCode: eventCode,
            callbackOrdinal: callbackOrdinal,
            sessionHash: sessionHash,
            questionHash: questionHash,
            replyHash: replyHash,
            reason: reason,
            speakingBefore: speakingBefore,
            speakingAfter: speakingAfter,
            resultCode: resultCode,
            requestExposure: requestExposure,
            errorDomain: errorDomain,
            errorCode: errorCode,
            elapsedMilliseconds: elapsedMilliseconds,
            requestAttempt: requestAttempt
        )
        envelope.events.append(diagnostic)
        if preservesFirstCriticalFailure, envelope.firstCriticalFailure == nil {
            envelope.firstCriticalFailure = diagnostic
        }
        if preservesFirstRequestFailure, envelope.firstRequestFailure == nil {
            envelope.firstRequestFailure = diagnostic
        }
        envelope.updatedAt = timestamp
        if envelope.events.count > maximumEventCount {
            let overflow = envelope.events.count - maximumEventCount
            envelope.events.removeFirst(overflow)
            envelope.droppedCount += overflow
        }
        measured("trim") { trimToByteLimit(&envelope) }
        do {
            let data = try measured("encode") { try Self.encoder.encode(envelope) }
            _ = try measured("atomicReplace", bytes: data.count) { try KnowledgeLocalStoragePolicy.write(data, to: url) }
            measured("prune") { pruneScopeDirectory(scopeDigest: scopeDigest, now: timestamp) }
        } catch {
            markPersistenceUnavailable(scopeDigest: scopeDigest, sessionHash: sessionHash)
            PrivacySafeDiagnostics.log(
                subsystem: "NativeLiveDiagnostics",
                event: "diagnosticsPersistenceUnavailable",
                states: ["storage": "writeFailed"]
            )
        }
    }

    private func setActiveSessionOnQueue(
        scopeDigest: String,
        sessionHash: String,
        active: Bool
    ) {
        let timestamp = now()
        let directory = rootDirectory.appendingPathComponent(scopeDigest, isDirectory: true)
        if active,
           let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
           ) {
            for url in urls where url.pathExtension == "json" {
                guard var envelope = readEnvelopeData(at: url, scopeDigest: scopeDigest),
                      envelope.sessionHash != sessionHash,
                      envelope.isActive == true else { continue }
                envelope.isActive = false
                envelope.activePinReleasedAt = timestamp
                _ = try? KnowledgeLocalStoragePolicy.write(
                    try Self.encoder.encode(envelope),
                    to: url
                )
            }
        }
        let url = fileURL(scopeDigest: scopeDigest, sessionHash: sessionHash)
        var envelope = readEnvelope(
            at: url,
            scopeDigest: scopeDigest,
            sessionHash: sessionHash
        ) ?? Envelope(
            schemaVersion: Self.schemaVersion,
            scopeDigest: scopeDigest,
            sessionHash: sessionHash,
            events: [],
            droppedCount: 0,
            firstCriticalFailure: nil,
            firstRequestFailure: nil,
            isActive: nil,
            activePinReleasedAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        envelope.isActive = active
        if active {
            envelope.activePinReleasedAt = nil
            envelope.updatedAt = timestamp
        } else {
            envelope.activePinReleasedAt = timestamp
        }
        do {
            try KnowledgeLocalStoragePolicy.write(try Self.encoder.encode(envelope), to: url)
            pruneScopeDirectory(scopeDigest: scopeDigest, now: timestamp)
        } catch {
            markPersistenceUnavailable(scopeDigest: scopeDigest, sessionHash: sessionHash)
            // Diagnostics remain best-effort and cannot affect Live capture.
        }
    }

    private func trimToByteLimit(_ envelope: inout Envelope) {
        while envelope.events.count > 1,
              ((try? Self.encoder.encode(envelope).count) ?? Int.max) > maximumTotalBytes {
            envelope.events.removeFirst()
            envelope.droppedCount += 1
        }
    }

    private func pruneScopeDirectory(scopeDigest: String, now: Date) {
        let directory = rootDirectory.appendingPathComponent(scopeDigest, isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        var retained: [(URL, Envelope, Int)] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let envelope = try? Self.decoder.decode(Envelope.self, from: data),
                  envelope.schemaVersion == Self.schemaVersion,
                  envelope.scopeDigest == scopeDigest else {
                continue
            }
            if now.timeIntervalSince(envelope.updatedAt) > retentionInterval {
                try? fileManager.removeItem(at: url)
            } else {
                retained.append((url, envelope, data.count))
            }
        }
        retained.sort { lhs, rhs in
            let lhsIsActive = lhs.1.isActive == true
            let rhsIsActive = rhs.1.isActive == true
            if lhsIsActive != rhsIsActive {
                return lhsIsActive
            }
            let lhsHasFirstFailure = lhs.1.firstCriticalFailure != nil
                || lhs.1.firstRequestFailure != nil
            let rhsHasFirstFailure = rhs.1.firstCriticalFailure != nil
                || rhs.1.firstRequestFailure != nil
            if lhsHasFirstFailure != rhsHasFirstFailure {
                return lhsHasFirstFailure
            }
            let lhsWasReleased = lhs.1.activePinReleasedAt != nil
            let rhsWasReleased = rhs.1.activePinReleasedAt != nil
            if lhsWasReleased != rhsWasReleased {
                return !lhsWasReleased
            }
            return lhs.1.updatedAt > rhs.1.updatedAt
        }
        for item in retained.dropFirst(maximumSessionCount) {
            try? fileManager.removeItem(at: item.0)
        }
        var total = retained.prefix(maximumSessionCount).reduce(0) { $0 + $1.2 }
        for item in retained.prefix(maximumSessionCount).reversed()
            where total > maximumTotalBytes {
            try? fileManager.removeItem(at: item.0)
            total -= item.2
        }
    }

    private func readEnvelope(
        at url: URL,
        scopeDigest: String,
        sessionHash: String
    ) -> Envelope? {
        guard let data = try? measured("read", { try Data(contentsOf: url) }),
              let envelope = try? measured("decode", bytes: data.count, { try Self.decoder.decode(Envelope.self, from: data) }),
              envelope.schemaVersion == Self.schemaVersion,
              envelope.scopeDigest == scopeDigest,
              envelope.sessionHash == sessionHash else {
            return nil
        }
        return envelope
    }

    private func readEnvelopeData(
        at url: URL,
        scopeDigest: String
    ) -> Envelope? {
        guard let data = try? measured("read", { try Data(contentsOf: url) }),
              let envelope = try? measured("decode", bytes: data.count, { try Self.decoder.decode(Envelope.self, from: data) }),
              envelope.schemaVersion == Self.schemaVersion,
              envelope.scopeDigest == scopeDigest else {
            return nil
        }
        return envelope
    }

    private func fileURL(scopeDigest: String, sessionHash: String) -> URL {
        rootDirectory
            .appendingPathComponent(scopeDigest, isDirectory: true)
            .appendingPathComponent(Self.fileSafeDigest(sessionHash) + ".json")
    }

    private static func scopeDigest(for lease: AccountLease) -> String {
        fileSafeDigest([
            lease.subjectId,
            lease.vaultId,
            String(lease.generation),
            lease.generationId.uuidString.lowercased(),
            lease.authorityEpoch,
        ].joined(separator: "|"))
    }

    private static func fileSafeDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
