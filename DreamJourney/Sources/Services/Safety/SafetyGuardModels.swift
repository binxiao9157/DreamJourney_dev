import Foundation

enum SafetyGuardSurface: String, Codable, Equatable {
    case dialog
    case mailbox
    case memoryArchive = "memory_archive"
    case photoAnalysis = "photo_analysis"
    case memoir
    case knowledge
    case tts
}

enum SafetyGuardStage: String, Codable, Equatable {
    case userInputPreLLM = "user_input_pre_llm"
    case assistantOutputPreUI = "assistant_output_pre_ui"
    case ttsInputPreSynth = "tts_input_pre_synth"
    case localSavePrePersist = "local_save_pre_persist"
    case imagePreAnalysis = "image_pre_analysis"
    case analysisSummaryPrePersist = "analysis_summary_pre_persist"
}

enum SafetyGuardContentType: String, Codable, Equatable {
    case text
    case transcript
    case image
    case summary
}

enum SafetyGuardTarget: String, Codable, Equatable {
    case volcengineDialog = "volcengine_dialog"
    case deepseek
    case volcengineTTS = "volcengine_tts"
    case localOnly = "local_only"
}

enum SafetyGuardRiskLevel: String, Codable, Equatable {
    case safe
    case low
    case medium
    case high
    case critical
}

enum SafetyGuardAction: String, Codable, Equatable {
    case allow
    case allowWithCare = "allow_with_care"
    case block
    case escalate
}

struct SafetyGuardRequest: Codable, Equatable {
    let requestID: String
    let clientEventID: String
    let sessionID: String
    let userIDHash: String
    let deviceIDHash: String
    let surface: SafetyGuardSurface
    let stage: SafetyGuardStage
    let contentType: SafetyGuardContentType
    let text: String?
    let mediaRef: String?
    let locale: String
    let sdkEventType: String?
    let target: SafetyGuardTarget
    let noStoreRaw: Bool

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case clientEventID = "client_event_id"
        case sessionID = "session_id"
        case userIDHash = "user_id_hash"
        case deviceIDHash = "device_id_hash"
        case surface
        case stage
        case contentType = "content_type"
        case text
        case mediaRef = "media_ref"
        case locale
        case sdkEventType = "sdk_event_type"
        case target
        case noStoreRaw = "no_store_raw"
    }
}

struct SafetyGuardResponse: Codable, Equatable {
    let decisionID: String
    let riskLevel: SafetyGuardRiskLevel
    let action: SafetyGuardAction
    let categories: [String]
    let policyVersion: String
    let reasonCode: String
    let safeReplacementKey: String?
    let canPersist: Bool
    let canSendToLLM: Bool
    let canSendToTTS: Bool
    let canShowInFamilyDashboard: Bool
    let audit: SafetyGuardAudit

    enum CodingKeys: String, CodingKey {
        case decisionID = "decision_id"
        case riskLevel = "risk_level"
        case action
        case categories
        case policyVersion = "policy_version"
        case reasonCode = "reason_code"
        case safeReplacementKey = "safe_replacement_key"
        case canPersist = "can_persist"
        case canSendToLLM = "can_send_to_llm"
        case canSendToTTS = "can_send_to_tts"
        case canShowInFamilyDashboard = "can_show_in_family_dashboard"
        case audit
    }
}

struct SafetyGuardAudit: Codable, Equatable {
    let rawContentStored: Bool
    let contentHMACSHA256: String?
    let contentLength: Int
    let evaluatedAt: String
    let latencyMS: Int

    enum CodingKeys: String, CodingKey {
        case rawContentStored = "raw_content_stored"
        case contentHMACSHA256 = "content_hmac_sha256"
        case contentLength = "content_length"
        case evaluatedAt = "evaluated_at"
        case latencyMS = "latency_ms"
    }
}
