enum KnowledgeGenerationPolicy {
    static func allowsEntity(privacyScope: String?) -> Bool {
        privacyScope == "generationAllowed"
    }

    static func allowsFact(privacyScope: String?, confidence: String?) -> Bool {
        guard allowsEntity(privacyScope: privacyScope) else {
            return false
        }
        switch confidence?.lowercased() {
        case "high", "confirmed":
            return true
        default:
            return false
        }
    }
}
