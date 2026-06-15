import Foundation

// MARK: - Dialog Engine Shared Models

enum DialogEndReason {
    case manual
    case keyword(String)
    case silenceTimeout
    case serverEnded
    case crisis(SafetyAssessment)
}

enum DialogEndIntentPolicy {
    static let memoirRequestKeywords: [String] = [
        "生成回忆录", "整理回忆录", "写回忆录", "做回忆录", "回忆录生成"
    ]

    static let endOnlyKeywords: [String] = [
        "停止", "结束", "聊完了", "聊好了", "不聊了", "再见",
        "我要去忙了", "先这样吧", "下次再聊"
    ]

    static let endKeywords: [String] = memoirRequestKeywords + [
        "生成家书", "写家书"
    ] + endOnlyKeywords

    static func matchedEndKeyword(in text: String, candidates: [String] = endKeywords) -> String? {
        let normalized = normalizeCommandText(text)
        guard !normalized.isEmpty, !shouldRecordAsMemoryTurn(text) else { return nil }

        return candidates.first { keyword in
            let normalizedKeyword = normalizeCommandText(keyword)
            guard !normalizedKeyword.isEmpty else { return false }
            if normalized == normalizedKeyword { return true }

            let wrapperBudget = normalizedKeyword.count + 6
            return normalized.count <= wrapperBudget && normalized.contains(normalizedKeyword)
        }
    }

    static func shouldPromptMemoir(for reason: DialogEndReason) -> Bool {
        guard case .keyword(let keyword) = reason else {
            return false
        }
        return memoirRequestKeywords.contains { keyword.contains($0) || $0.contains(keyword) }
    }

    static func shouldRecordAsMemoryTurn(_ text: String) -> Bool {
        let normalized = normalizeCommandText(text)
        guard !normalized.isEmpty else { return false }

        let controlKeywords = memoirRequestKeywords + endOnlyKeywords + ["生成家书", "写家书"]
        let isStandaloneControl = controlKeywords.contains { keyword in
            let normalizedKeyword = normalizeCommandText(keyword)
            guard !normalizedKeyword.isEmpty else { return false }
            if normalized == normalizedKeyword { return true }

            // Allow short polite wrappers such as “那就聊完了吧” or “请生成回忆录”.
            let wrapperBudget = normalizedKeyword.count + 6
            return normalized.count <= wrapperBudget && normalized.contains(normalizedKeyword)
        }
        return !isStandaloneControl
    }

    private static func normalizeCommandText(_ text: String) -> String {
        let removable = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "，。！？、；：,.!?;:~～「」『』“”‘’（）()【】[]"))
        return text
            .components(separatedBy: removable)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MemoryDialogIntent: String {
    case casualChat
    case memoryRecall
    case factQuestion
    case storyContinuation
    case newMemoryCapture
}

enum MemoryIntentClassifier {
    static func classify(_ text: String) -> MemoryDialogIntent {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .casualChat }

        if containsAny(normalized, [
            "哪里", "哪儿", "哪年", "什么时候", "是谁", "叫什么", "和谁", "在哪",
            "记得我", "还记得", "我以前", "我过去", "我住", "我是不是", "有没有"
        ]) || normalized.contains("?") || normalized.contains("？") {
            return .factQuestion
        }

        if containsAny(normalized, [
            "我叫", "我是", "住在", "住过", "搬到", "搬去", "妻子", "丈夫", "老伴",
            "父亲", "母亲", "爷爷", "奶奶", "外公", "外婆", "开过", "做过", "工作", "出生"
        ]) && (containsYear(normalized) || containsAny(normalized, ["我叫", "住在", "住过", "妻子", "丈夫", "老伴", "开过"])) {
            return .newMemoryCapture
        }

        if containsAny(normalized, ["继续", "接着", "然后呢", "后来呢", "讲下去", "往下说"]) {
            return .storyContinuation
        }

        if containsAny(normalized, ["记得", "想起来", "以前", "小时候", "当年", "那时候", "过去"]) {
            return .memoryRecall
        }

        return .casualChat
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func containsYear(_ text: String) -> Bool {
        let pattern = #"((19|20)\d{2})年?"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

struct MemoryEvidenceItem: Equatable {
    enum Kind: String {
        case person
        case place
        case event
        case fact
    }

    let kind: Kind
    let text: String
    let confidence: Int
    let source: String
    let sourceTitle: String?
}

private enum DialogMemoryEvidenceSanitizer {
    private static let genericKinshipNames: Set<String> = [
        "爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
        "爸爸", "妈妈", "父亲", "母亲",
        "老伴", "老公", "老婆", "丈夫", "妻子",
        "哥哥", "姐姐", "弟弟", "妹妹",
        "叔叔", "阿姨", "舅舅", "姑姑",
        "儿子", "女儿", "孙子", "孙女"
    ]

    static func isGenericKinshipName(_ name: String) -> Bool {
        genericKinshipNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func shouldSuppressFact(_ fact: KBFact, concretePersonIds: Set<String>) -> Bool {
        guard genericKinshipNames.contains(where: { fact.statement.contains($0) }) else {
            return false
        }
        return !fact.relatedPersonIds.contains(where: { concretePersonIds.contains($0) })
    }
}

struct MemoryEvidencePack {
    let query: String
    let intent: MemoryDialogIntent
    let items: [MemoryEvidenceItem]

    var hasEvidence: Bool {
        !items.isEmpty
    }

    static func build(query: String, graph: KBLiteGraph, maxItems: Int = 5) -> MemoryEvidencePack {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = MemoryIntentClassifier.classify(trimmedQuery)
        var scored: [(score: Int, order: Int, item: MemoryEvidenceItem)] = []
        var order = 0
        let concretePersonIds = Set(
            graph.people
                .filter { !DialogMemoryEvidenceSanitizer.isGenericKinshipName($0.name) }
                .map(\.id)
        )

        func append(kind: MemoryEvidenceItem.Kind, text: String, metadata: MemoryPrivacyMetadata, source: String) {
            guard PrivacyScopePolicy.canUse(metadata: metadata, surface: .prompt) else { return }
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            let score = relevanceScore(query: trimmedQuery, text: normalized, intent: intent, kind: kind)
            guard trimmedQuery.isEmpty || score > 0 else { return }
            let item = MemoryEvidenceItem(
                kind: kind,
                text: normalized,
                confidence: score,
                source: source,
                sourceTitle: evidenceSourceTitle(from: metadata)
            )
            scored.append((score, order, item))
            order += 1
        }

        for person in graph.people {
            guard !DialogMemoryEvidenceSanitizer.isGenericKinshipName(person.name) else { continue }
            var text = person.name
            if let relation = person.relation, !relation.isEmpty {
                text += "（\(relation)）"
            }
            if let bio = person.briefBio, !bio.isEmpty {
                text += "：\(bio)"
            }
            append(kind: .person, text: text, metadata: person.privacyMetadata, source: person.id)
        }

        for place in graph.places {
            var text = place.name
            if let category = place.category, !category.isEmpty {
                text += "（\(category)）"
            }
            if let description = place.description, !description.isEmpty {
                text += "：\(description)"
            }
            append(kind: .place, text: text, metadata: place.privacyMetadata, source: place.id)
        }

        for event in graph.events {
            var text = event.title
            if let year = event.year {
                text = "\(year)年\(text)"
            }
            if let description = event.description, !description.isEmpty {
                text += "：\(description)"
            }
            append(kind: .event, text: text, metadata: event.privacyMetadata, source: event.id)
        }

        for fact in graph.facts {
            guard !DialogMemoryEvidenceSanitizer.shouldSuppressFact(
                fact,
                concretePersonIds: concretePersonIds
            ) else { continue }
            append(kind: .fact, text: fact.statement, metadata: fact.privacyMetadata, source: fact.id)
        }

        var seen: Set<String> = []
        let items = scored
            .sorted {
                if $0.score == $1.score { return $0.order < $1.order }
                return $0.score > $1.score
            }
            .compactMap { entry -> MemoryEvidenceItem? in
                guard !seen.contains(entry.item.text) else { return nil }
                seen.insert(entry.item.text)
                return entry.item
            }
            .prefix(maxItems)

        return MemoryEvidencePack(query: trimmedQuery, intent: intent, items: Array(items))
    }

    private static func relevanceScore(
        query: String,
        text: String,
        intent: MemoryDialogIntent,
        kind: MemoryEvidenceItem.Kind
    ) -> Int {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return 1 }

        var score = 0
        let terms = memoryTerms(from: query)
        let specificTerms = terms.filter { isSpecificMemoryTerm($0) }
        if !specificTerms.isEmpty,
           !specificTerms.contains(where: { text.contains($0) }) {
            return 0
        }
        for term in terms where text.contains(term) {
            score += max(term.count, 1) * 2
        }

        let synonymGroups: [[String]] = [
            ["哪里", "哪儿", "住", "地点", "地方", "老家", "家", "街", "路", "城", "区"],
            ["谁", "妻子", "丈夫", "老伴", "家人", "父亲", "母亲", "爷爷", "奶奶"],
            ["照相馆", "开店", "工作", "职业", "生意", "经营"],
            ["哪年", "什么时候", "年份", "年"]
        ]
        for group in synonymGroups {
            if group.contains(where: { query.contains($0) }) &&
                group.contains(where: { text.contains($0) }) {
                score += 6
            }
        }

        if kind == .person && ["谁", "和谁", "家人", "妻子", "丈夫", "老伴"].contains(where: { query.contains($0) }) {
            score += 18
        }
        if kind == .place && ["哪里", "哪儿", "在哪", "住", "地方"].contains(where: { query.contains($0) }) {
            score += 10
        }
        if kind == .event && ["什么事", "经历", "开过", "做过", "发生"].contains(where: { query.contains($0) }) {
            score += 2
        }
        if kind == .fact &&
            ["哪里", "哪儿", "在哪", "住"].contains(where: { query.contains($0) }) &&
            text.contains("住") {
            score += 10
        }
        if kind == .fact &&
            ["开过", "照相馆", "工作", "做过"].contains(where: { query.contains($0) }) &&
            ["开过", "照相馆", "工作", "做过"].contains(where: { text.contains($0) }) {
            score += 8
        }
        if kind == .event && score > 0 {
            score = max(score - 16, 1)
        }

        switch intent {
        case .factQuestion:
            score += score > 0 ? 4 : 0
        case .newMemoryCapture:
            score += score > 0 ? 1 : 0
        case .memoryRecall, .storyContinuation:
            score += score > 0 ? 2 : 0
        case .casualChat:
            break
        }

        return score
    }

    private static func evidenceSourceTitle(from metadata: MemoryPrivacyMetadata) -> String? {
        let preferredKinds: [MemorySourceKind] = [
            .memoryArchiveItem,
            .timeMailboxLetter,
            .conversationTurn,
            .memoir,
            .importRecord
        ]
        for kind in preferredKinds {
            if let title = metadata.sourceRefs.first(where: { $0.kind == kind })?.title?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                return title
            }
        }
        return metadata.sourceRefs
            .compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func memoryTerms(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "，。！？；：、“”‘’（）《》"))
        let rawParts = text.components(separatedBy: separators)
        var terms: [String] = []
        for part in rawParts where part.count >= 2 {
            terms.append(part)
            if part.count >= 4 {
                var index = part.startIndex
                while let end = part.index(index, offsetBy: 2, limitedBy: part.endIndex) {
                    terms.append(String(part[index..<end]))
                    index = part.index(after: index)
                    if index >= part.endIndex { break }
                }
            }
        }
        return Array(Set(terms))
    }

    private static func isSpecificMemoryTerm(_ term: String) -> Bool {
        let genericTerms: Set<String> = [
            "是谁", "哪里", "哪儿", "在哪", "哪年", "什么时候", "什么", "怎么", "平时",
            "以前", "过去", "当年", "那时候", "后来", "有没有", "记得", "还记", "我这",
            "这里", "这个", "那个", "今天", "中午", "天气", "不错"
        ]
        guard term.count >= 2, !genericTerms.contains(term) else { return false }
        return true
    }
}

enum MemoryGroundedReplyMode: String {
    case answerWithEvidence
    case askForMissingMemory
    case confirmAmbiguousMemory
    case captureNewMemory
    case casualChat
}

struct MemoryGroundedReplyPlan {
    let mode: MemoryGroundedReplyMode
    let instruction: String
    let evidenceLines: [String]
}

private struct DialogCurrentSpeakerIdentity {
    let name: String
    let relation: String
    let aliases: [String]

    var displayName: String {
        "\(name)（\(relation)）"
    }
}

private enum DialogCurrentSpeakerIdentityResolver {
    private static let selfRelations: Set<String> = [
        "本人", "自己", "我", "当前用户", "用户本人", "长辈本人", "讲述者", "受访者"
    ]

    static func resolve(in graph: KBLiteGraph) -> DialogCurrentSpeakerIdentity? {
        let promptPeople = graph.people
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }

        let candidates = promptPeople
            .filter { person in
                guard let relation = person.relation?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !relation.isEmpty
                else {
                    return false
                }
                return selfRelations.contains(relation)
            }
            .sorted { lhs, rhs in
                (lhs.sourceSessionIds.last ?? 0) > (rhs.sourceSessionIds.last ?? 0)
            }

        if let person = candidates.first,
           let relation = person.relation?.trimmingCharacters(in: .whitespacesAndNewlines),
           !person.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DialogCurrentSpeakerIdentity(
                name: person.name.trimmingCharacters(in: .whitespacesAndNewlines),
                relation: relation,
                aliases: person.aliases
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }

        if let selfIntroName = explicitSelfIntroName(in: graph) {
            let matchedPerson = promptPeople.first { person in
                person.name == selfIntroName || person.aliases.contains(selfIntroName)
            }
            return DialogCurrentSpeakerIdentity(
                name: selfIntroName,
                relation: "本人",
                aliases: matchedPerson?.aliases
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []
            )
        }

        return nil
    }

    private static func explicitSelfIntroName(in graph: KBLiteGraph) -> String? {
        let promptFacts = graph.facts
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt) }
            .sorted { lhs, rhs in
                (lhs.sourceSessionIds.last ?? 0) > (rhs.sourceSessionIds.last ?? 0)
            }

        for fact in promptFacts {
            if let name = extractNameAfterWoJiao(from: fact.statement),
               !DialogMemoryEvidenceSanitizer.isGenericKinshipName(name) {
                return name
            }
        }
        return nil
    }

    private static func extractNameAfterWoJiao(from text: String) -> String? {
        let pattern = #"我叫([\u4e00-\u9fa5]{2,4})(?:，|。|,|\.|\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2
        else {
            return nil
        }
        return nsText.substring(with: match.range(at: 1))
    }
}

enum MemoryGroundedReplyPlanner {
    static func makePlan(pack: MemoryEvidencePack) -> MemoryGroundedReplyPlan {
        let evidenceLines = pack.items.map { item in
            "[\(item.kind.rawValue)] \(item.text)"
        }

        switch pack.intent {
        case .newMemoryCapture:
            return MemoryGroundedReplyPlan(
                mode: .captureNewMemory,
                instruction: "用户正在提供新的家庭记忆。先简短确认你听到了，再围绕时间、地点、人物、事件只追问一个细节；不要把未确认内容说成已归档事实。",
                evidenceLines: evidenceLines
            )

        case .factQuestion:
            if pack.hasEvidence {
                return MemoryGroundedReplyPlan(
                    mode: .answerWithEvidence,
                    instruction: "根据证据自然回答。只说证据支持的内容；如果问题有一部分没有证据，明确说还没有记住那一部分，不要编造。",
                    evidenceLines: evidenceLines
                )
            }
            return MemoryGroundedReplyPlan(
                mode: .askForMissingMemory,
                instruction: "没有检索到相关家庭记忆。不要编造；请说“我这里还没有记住这段，可以跟我讲讲吗？”，再追问一个具体细节。",
                evidenceLines: []
            )

        case .memoryRecall, .storyContinuation:
            if pack.hasEvidence {
                return MemoryGroundedReplyPlan(
                    mode: .answerWithEvidence,
                    instruction: "用已知记忆接住话题，温和延续，并追问一个具体细节。事实边界只来自证据。",
                    evidenceLines: evidenceLines
                )
            }
            return MemoryGroundedReplyPlan(
                mode: .confirmAmbiguousMemory,
                instruction: "用户可能在回忆往事，但档案里没有匹配证据。不要假装记得；请邀请用户补充一个时间、地点或人物。",
                evidenceLines: []
            )

        case .casualChat:
            return MemoryGroundedReplyPlan(
                mode: pack.hasEvidence ? .answerWithEvidence : .casualChat,
                instruction: pack.hasEvidence
                    ? "可以少量自然引用已知记忆，但不要主动展开过多档案内容。"
                    : "本轮是普通陪聊，不需要引用档案；如果涉及事实，仍然不能编造。",
                evidenceLines: evidenceLines
            )
        }
    }
}

enum DialogMemoryGroundingPolicy {
    static func systemRoleAppendix() -> String {
        """

【已知家庭记忆使用规则】
1. 涉及用户姓名、家人关系、年份、地点、经历、职业、迁徙和家庭事件时，必须优先依据【已知家庭记忆】回答。
2. 不得编造用户没有说过的人物、年份、地点、关系、经历和情绪。没有证据时，不要猜。
3. 如果用户问到人生事实但【已知家庭记忆】没有记录，要说：“我这里还没有记住这段，可以跟我讲讲吗？”然后只追问一个具体问题。
4. 引用已知事实时，用“我记得您说过……”或“您之前提到……”自然表达，不要逐条朗读档案。
5. 可以温暖陪聊，但事实性内容必须以已知记忆为边界。
6. 如果【当前说话人身份】标记了“本人”，你正在和这个人本人对话，必须用“您/你”称呼这位用户，不要用第三人称。
"""
    }

    static func currentSpeakerIdentityContext(graph: KBLiteGraph) -> String {
        guard let identity = DialogCurrentSpeakerIdentityResolver.resolve(in: graph) else {
            return ""
        }

        let aliasLine: String
        if identity.aliases.isEmpty {
            aliasLine = ""
        } else {
            aliasLine = "\n- 其他称呼：\(identity.aliases.joined(separator: "、"))。"
        }

        return """

【当前说话人身份】
- 当前正在对话的长辈/用户：\(identity.displayName)。
- 称呼视角：你是在和\(identity.name)本人说话；直接对话时，把\(identity.name)称作“您”或“你”。
- 禁止第三人称：不要把\(identity.name)说成“他”“\(identity.name)”“这位用户”；除非用户主动要求写档案摘要。\(aliasLine)
"""
    }

    static func currentSpeakerIdentityRAGContent(graph: KBLiteGraph) -> String? {
        guard let identity = DialogCurrentSpeakerIdentityResolver.resolve(in: graph) else {
            return nil
        }

        return """
当前说话人身份：\(identity.displayName)。
称呼视角：你正在和\(identity.name)本人对话，必须把\(identity.name)称作“您”或“你”。
禁止第三人称：不要把\(identity.name)说成“他”“\(identity.name)”“这位用户”；回答\(identity.name)的经历时，要说“您之前提到……”。
"""
    }

    static func queryContext(for query: String, graph: KBLiteGraph, maxItems: Int = 5) -> String {
        let pack = MemoryEvidencePack.build(query: query, graph: graph, maxItems: maxItems)
        let plan = MemoryGroundedReplyPlanner.makePlan(pack: pack)
        let identityContext = currentSpeakerIdentityContext(graph: graph)

        if plan.evidenceLines.isEmpty {
            return """

\(identityContext)
【本轮记忆意图】\(pack.intent.rawValue)
【回复计划】\(plan.mode.rawValue)
【本轮已知家庭记忆】
没有检索到相关家庭记忆。如果用户追问具体人生事实，不要编造；请说“我这里还没有记住这段，可以跟我讲讲吗？”，再追问一个细节。
【回复约束】
\(plan.instruction)
"""
        }

        return """

\(identityContext)
【本轮记忆意图】\(pack.intent.rawValue)
【回复计划】\(plan.mode.rawValue)
【本轮已知家庭记忆】
\(plan.evidenceLines.map { "- \($0)" }.joined(separator: "\n"))
【回复约束】
\(plan.instruction)
如果没有证据支撑用户追问的事实，不要编造；请温和说明还没有记住，并邀请用户补充。
"""
    }
}

enum DialogMemoryRAGPayloadBuilder {
    static let maxPayloadCharacters = 4_000

    static func makePayload(
        query: String,
        graph: KBLiteGraph,
        maxItems: Int = 5
    ) -> String? {
        let pack = MemoryEvidencePack.build(query: query, graph: graph, maxItems: maxItems)
        let plan = MemoryGroundedReplyPlanner.makePlan(pack: pack)
        let identityContent = DialogMemoryGroundingPolicy.currentSpeakerIdentityRAGContent(graph: graph)
        guard pack.hasEvidence else {
            if let identityContent {
                return makePayload(items: [[
                    "title": "当前说话人身份",
                    "content": identityContent
                ]])
            }
            guard shouldSendNoEvidenceBoundary(for: pack.intent) else { return nil }
            return makePayload(items: [[
                "title": "没有匹配的家庭记忆",
                "content": "没有检索到相关家庭记忆。\n回复边界：\(plan.instruction)"
            ]])
        }

        var items: [[String: String]] = []
        if let identityContent {
            items.append([
                "title": "当前说话人身份",
                "content": identityContent
            ])
        }
        items.append(contentsOf: pack.items.map { item in
            [
                "title": title(for: item),
                "content": content(for: item, plan: plan)
            ]
        })
        return makePayload(items: items)
    }

    private static func makePayload(items: [[String: String]]) -> String? {
        var trimmedItems = items
        while !trimmedItems.isEmpty {
            guard let externalRAG = encodeJSONStringArray(trimmedItems),
                  let payload = encodeJSONObject(["external_rag": externalRAG]) else {
                return nil
            }
            if payload.count <= maxPayloadCharacters {
                return payload
            }
            trimmedItems.removeLast()
        }
        return nil
    }

    private static func shouldSendNoEvidenceBoundary(for intent: MemoryDialogIntent) -> Bool {
        switch intent {
        case .factQuestion, .memoryRecall, .storyContinuation:
            return true
        case .casualChat, .newMemoryCapture:
            return false
        }
    }

    private static func title(for item: MemoryEvidenceItem) -> String {
        switch item.kind {
        case .person:
            return "家庭记忆人物"
        case .place:
            return "家庭记忆地点"
        case .event:
            return "家庭记忆事件"
        case .fact:
            return "家庭记忆事实"
        }
    }

    private static func content(for item: MemoryEvidenceItem, plan: MemoryGroundedReplyPlan) -> String {
        let sourceLine = item.sourceTitle.map { "\n证据来源：\($0)" } ?? ""
        let raw = "\(item.text)\(sourceLine)\n回复边界：\(plan.instruction)"
        if raw.count <= 520 {
            return raw
        }
        return String(raw.prefix(520))
    }

    private static func encodeJSONStringArray(_ items: [[String: String]]) -> String? {
        guard JSONSerialization.isValidJSONObject(items),
              let data = try? JSONSerialization.data(withJSONObject: items),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func encodeJSONObject(_ object: [String: String]) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSFinished()
    func onAssistantFinalText(text: String)
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onSafetyTriggered(assessment: SafetyAssessment)
    func onDialogEnded(reason: DialogEndReason)
}

extension DialogEngineDelegate {
    func onSafetyTriggered(assessment: SafetyAssessment) {}
    func onAssistantFinalText(text: String) {}
}
