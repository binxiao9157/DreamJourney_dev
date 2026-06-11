import Foundation

final class SafetyMonitor {
    static let shared = SafetyMonitor()

    private let highRiskKeywords = [
        "不想活",
        "活着没意思",
        "想死",
        "自杀",
        "结束生命",
        "撑不下去",
        "我也走",
        "跟你一起走",
        "不如死了",
        "我去陪你",
        "结束这一切",
        "没有活下去的意义"
    ]

    private let mediumRiskKeywords = [
        "撑不住",
        "受不了了",
        "没人理解",
        "太痛苦",
        "没有希望",
        "睡不着"
    ]

    private let ignoredCharacters: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "，。！？；：、“”‘’（）()【】[]《》<>「」『』,.!?;:\"'`~@#$%^&*_-+=/\\|")
        return set
    }()

    private init() {}

    func evaluate(_ text: String) -> SafetyAssessment {
        let normalizedText = normalize(text)
        let highMatches = matchedKeywords(in: normalizedText, candidates: highRiskKeywords)

        if !highMatches.isEmpty {
            return SafetyAssessment(
                level: .high,
                matchedKeywords: highMatches,
                userText: text,
                reason: "检测到明确生命安全风险表达",
                shouldBlockRoleplay: true
            )
        }

        let mediumMatches = matchedKeywords(in: normalizedText, candidates: mediumRiskKeywords)
        if !mediumMatches.isEmpty {
            return SafetyAssessment(
                level: .medium,
                matchedKeywords: mediumMatches,
                userText: text,
                reason: "检测到持续痛苦或求助信号",
                shouldBlockRoleplay: false
            )
        }

        return SafetyAssessment(
            level: .none,
            matchedKeywords: [],
            userText: text,
            reason: "未检测到生命安全风险关键词",
            shouldBlockRoleplay: false
        )
    }

    func evaluateAssistantOutput(_ text: String) -> SafetyAssessment {
        let assessment = evaluate(text)
        guard assessment.shouldBlockRoleplay else { return assessment }

        return SafetyAssessment(
            level: assessment.level,
            matchedKeywords: assessment.matchedKeywords,
            userText: text,
            reason: "AI 回复包含可能引发生命安全风险的内容",
            shouldBlockRoleplay: true
        )
    }

    private func matchedKeywords(in normalizedText: String, candidates: [String]) -> [String] {
        candidates.filter { keyword in
            normalizedText.contains(normalize(keyword))
        }
    }

    private func normalize(_ text: String) -> String {
        String(text.unicodeScalars.filter { !ignoredCharacters.contains($0) }).lowercased()
    }
}
