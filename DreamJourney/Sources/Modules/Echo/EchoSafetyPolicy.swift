import Foundation

enum EchoSafetyRiskClass: String, Codable, CaseIterable, Sendable {
    case none
    case highDistress = "high_distress"
    case selfHarm = "self_harm"
    case harmToOthers = "harm_to_others"
    case joinDeceased = "join_deceased"
    case immediateMissingPersonDanger = "immediate_missing_person_danger"

    var isCrisis: Bool { self != .none }
}

enum EchoSafetyAction: String, Codable, Sendable {
    case continueNeutralAssistant = "continue_neutral_assistant"
    case enterNeutralSafetyMode = "enter_neutral_safety_mode"
}

enum EchoSafetyMode: String, Codable, Sendable {
    case neutralAssistant = "neutral_assistant"
    case neutralSafety = "neutral_safety"
}

enum EchoAIIdentityDisclosurePresentation: String, Codable, Sendable {
    case persistent
}

struct EchoAIIdentityDisclosure: Codable, Equatable, Sendable {
    let required: Bool
    let presentation: EchoAIIdentityDisclosurePresentation
    let label: String
    let policyVersion: String

    static let persistent = EchoAIIdentityDisclosure(
        required: true,
        presentation: .persistent,
        label: "AI 助手生成，非真人本人",
        policyVersion: EchoSafetyPolicy.policyVersion
    )
}

struct EchoSafetyEffectPermissions: Codable, Equatable, Sendable {
    let persona: Bool
    let context: Bool
    let delayedReply: Bool
    let clonedVoice: Bool
    let digitalHuman: Bool
    let providerEffects: Bool

    static let neutralAssistant = EchoSafetyEffectPermissions(
        persona: true,
        context: true,
        delayedReply: true,
        clonedVoice: true,
        digitalHuman: true,
        providerEffects: true
    )

    static let crisisDenied = EchoSafetyEffectPermissions(
        persona: false,
        context: false,
        delayedReply: false,
        clonedVoice: false,
        digitalHuman: false,
        providerEffects: false
    )
}

struct EchoSafetyDecision: Codable, Equatable, Sendable {
    let policyVersion: String
    let disclosure: EchoAIIdentityDisclosure
    let riskClass: EchoSafetyRiskClass
    let action: EchoSafetyAction
    let mode: EchoSafetyMode
    let reasonCode: String
    let responseText: String?
    let effects: EchoSafetyEffectPermissions

    var isCrisis: Bool { riskClass.isCrisis }
    var allowsContext: Bool { !isCrisis && effects.context }
    var allowsDelayedReply: Bool { !isCrisis && effects.delayedReply }
    var allowsProviderEffects: Bool { !isCrisis && effects.providerEffects }
}

enum EchoSafetyPolicy {
    static let policyVersion = "wi-s0-06-09.v1"

    static let neutralChineseCrisisResponse =
        "我注意到你可能正处在危险中。请立即联系身边可信任的人；如有紧迫危险，请联系当地紧急服务。"

    static func classify(_ text: String) -> EchoSafetyRiskClass {
        let candidate = classifierInput(text)
        guard !candidate.isEmpty else { return .none }

        if matchesAny(candidate, patterns: joinDeceasedPatterns) {
            return .joinDeceased
        }
        if matchesAny(candidate, patterns: selfHarmPatterns) {
            return .selfHarm
        }
        if matchesAny(candidate, patterns: harmToOthersPatterns) {
            return .harmToOthers
        }
        if matchesAny(candidate, patterns: immediateDangerPatterns) {
            return .immediateMissingPersonDanger
        }
        if matchesAny(candidate, patterns: highDistressPatterns) {
            return .highDistress
        }
        return .none
    }

    static func evaluate(text: String) -> EchoSafetyDecision {
        let riskClass = classify(text)
        guard riskClass.isCrisis else {
            return EchoSafetyDecision(
                policyVersion: policyVersion,
                disclosure: .persistent,
                riskClass: .none,
                action: .continueNeutralAssistant,
                mode: .neutralAssistant,
                reasonCode: "safety_no_crisis",
                responseText: nil,
                effects: .neutralAssistant
            )
        }

        return EchoSafetyDecision(
            policyVersion: policyVersion,
            disclosure: .persistent,
            riskClass: riskClass,
            action: .enterNeutralSafetyMode,
            mode: .neutralSafety,
            reasonCode: "crisis_\(riskClass.rawValue)",
            responseText: neutralChineseCrisisResponse,
            effects: .crisisDenied
        )
    }

    static func decide(for text: String) -> EchoSafetyDecision {
        evaluate(text: text)
    }

    private static let joinDeceasedPatterns = [
        #"我(?:也)?想(?:死|走|离开)(?:了)?去陪(?:去世的|死去的|已经走了的|在天堂的|在那边的)?(?:他|她|你|妈妈|母亲|爸爸|父亲|家人|亲人|爱人)"#,
        #"我想去陪(?:去世的|死去的|已经走了的|在天堂的|在那边的)(?:他|她|妈妈|母亲|爸爸|父亲|家人|亲人|爱人)"#,
        #"我(?:也)?想随(?:他|她|你|妈妈|母亲|爸爸|父亲|家人|亲人|爱人)而去"#,
        #"我(?:也)?要跟(?:他|她|妈妈|爸爸|家人|亲人|爱人)一起死"#,
        #"我(?:也)?想(?:死|走|离开)?(?:了)?去陪(?:已经)?(?:去世|死去)(?:了)?的?[^，。！？,.!?\s]{1,8}"#,
        #"我(?:也)?想去那边陪(?:他|她|妈妈|母亲|爸爸|父亲|爷爷|奶奶|家人|亲人|爱人|丈夫|妻子)"#,
        #"\bi (?:want|plan|intend|am going) to die (?:so i can|to) (?:join|be with) (?:him|her|them|my (?:(?:dead|deceased|late) )?(?:mom|mother|dad|father|grandmother|grandfather|grandma|grandpa|wife|husband|son|daughter|family|partner))\b"#,
        #"\bi (?:want|plan|intend|am going) to (?:join|be with) (?:my )?(?:dead|deceased|late) (?:mom|mother|dad|father|grandmother|grandfather|grandma|grandpa|wife|husband|son|daughter|family|partner)\b"#,
        #"\bi (?:want|plan|intend|am going) to join my (?:mom|mother|dad|father|grandmother|grandfather|grandma|grandpa|wife|husband|son|daughter|partner) who died\b"#,
        #"\bi (?:want|plan|intend|am going) to follow (?:him|her|them) (?:in death|to the grave)\b"#,
    ]

    private static let selfHarmPatterns = [
        #"我(?:现在|马上|今晚|今天)?(?:想|要|准备|打算|决定)(?:去)?(?:自杀|自残|伤害自己|结束自己的生命|结束生命|割腕|跳楼|服药自杀|上吊)"#,
        #"我(?:现在|马上|今晚|今天)?(?:就)?(?:去死|不想活了|活不下去了)"#,
        #"我有自杀计划"#,
        #"我想一了百了"#,
        #"\bi(?:'m| am) suicidal\b"#,
        #"\bi (?:want|plan|intend|am going|have decided) to (?:kill myself|hurt myself|harm myself|end my life|take my own life|die)\b"#,
        #"\bi(?:'m| am) going to (?:cut myself|jump off|overdose)\b"#,
        #"\bi (?:do not|don't|dont) want to (?:live|be alive)(?: anymore)?\b"#,
        #"\bi cannot go on and (?:want to die|will kill myself)\b"#,
    ]

    private static let harmToOthersPatterns = [
        #"我(?:现在|马上|今晚|今天)?(?:想|要|准备|打算|决定)(?:去)?(?:杀人|杀了|伤害|弄死|捅死)(?:他|她|他们|她们|那个人|别人|某人)?"#,
        #"我有(?:杀人|伤害他人)计划"#,
        #"\bi (?:want|plan|intend|am going|have decided) to (?:kill|hurt|harm|stab|shoot) (?:him|her|them|someone|that person|people)\b"#,
        #"\bi(?:'m| am) going to commit murder\b"#,
    ]

    private static let immediateDangerPatterns = [
        #"(?:我的)?(?:孩子|小孩|儿子|女儿|老人|家人|亲人|妈妈|母亲|爸爸|父亲)(?:刚刚|刚才|现在|突然|已经)?(?:走失了|失踪了|不见了|失联了)"#,
        #"(?:他|她)(?:刚刚|现在|突然|已经)(?:走失了|失踪了|不见了|失联了)"#,
        #"我(?:现在|此刻)(?:正)?(?:有危险|有生命危险|处于危险中|被人追杀|被人持刀威胁)"#,
        #"有人(?:现在|正在)(?:追杀我|拿刀威胁我|攻击我)"#,
        #"\bmy (?:child|kid|son|daughter|mother|father|parent|partner|family member) (?:is|has gone) missing\b"#,
        #"\bmy (?:child|kid|son|daughter|mother|father|parent|partner|family member) (?:just |suddenly )?disappeared\b"#,
        #"\b(?:he|she) (?:just |suddenly )?(?:went missing|disappeared) and (?:is|may be) in (?:immediate )?danger\b"#,
        #"\bi am (?:in immediate danger|in danger (?:now|right now)|being attacked|being held against my will)\b"#,
        #"\bsomeone is (?:trying to kill me|attacking me|threatening me with (?:a knife|a gun))\b"#,
    ]

    private static let highDistressPatterns = [
        #"我(?:真的|已经|快|实在)?(?:撑不住|扛不住|坚持不下去)(?:了|啦|啊|[。！？,.!?]|$)"#,
        #"我(?:真的|已经|快|实在)?(?:要|快要)?崩溃(?:了|啦|啊|[。！？,.!?]|$)"#,
        #"\b(?:i )?(?:cannot|can't) (?:go on|take it anymore|cope anymore)\b"#,
        #"\b(?:i'm|i am) (?:at|near) (?:my )?breaking point\b"#,
    ]

    private static let negatedOrReportedPatterns = [
        #"我(?:不想|不会|不打算|并不想|从没想过|没有想过|没想过)(?:去)?(?:自杀|自残|伤害自己|结束生命|结束自己的生命|去死|死)"#,
        #"我(?:不想|不会|不打算|并不想|没有要|没打算)(?:去)?(?:杀人|杀了|伤害|弄死|捅死)(?:他|她|他们|她们|别人|某人)?"#,
        #"我(?:不想|不会|不打算|并不想)(?:去)?陪(?:去世的|死去的|已经走了的|在天堂的|在那边的)?(?:他|她|妈妈|爸爸|家人|亲人|爱人)"#,
        #"(?:他|她|孩子|小孩|老人|家人)(?:没有|并未|不是)(?:走失|失踪|不见|失联)"#,
        #"\bi (?:do not|don't|dont|never|would never|will not|won't|wont) (?:want|plan|intend|mean|try)?\s*to?\s*(?:kill myself|hurt myself|harm myself|end my life|take my own life|die)\b"#,
        #"\bi(?:'m| am) not (?:suicidal|going to (?:kill myself|hurt myself|harm myself|die))\b"#,
        #"\bi never said i (?:want|plan|intend) to (?:die|kill myself|hurt myself|harm myself)\b"#,
        #"\b(?:he|she|they|my friend|the (?:article|book|film|movie)) (?:said|says|wrote|uses the phrase).{0,60}\bi (?:want|plan|intend|am going) to (?:die|kill myself|hurt myself|harm myself)\b"#,
        #"\bi (?:do not|don't|dont|never|would never|will not|won't|wont) (?:want|plan|intend|mean|try)?\s*to?\s*(?:kill|hurt|harm|stab|shoot) (?:him|her|them|someone|people)\b"#,
        #"\b(?:he|she|my (?:child|kid|family member)) is not missing\b"#,
        #"\bi am not in (?:immediate )?danger\b"#,
    ]

    private static let quotedSegmentPatterns = [
        #"\"[^\"]*\""#,
        #"“[^”]*”"#,
        #"‘[^’]*’"#,
        #"「[^」]*」"#,
        #"『[^』]*』"#,
    ]

    private static func classifierInput(_ text: String) -> String {
        var value = text.lowercased()
        for pattern in quotedSegmentPatterns + negatedOrReportedPatterns {
            value = replacingMatches(in: value, pattern: pattern, with: " ")
        }
        return value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesAny(_ value: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            value.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func replacingMatches(in value: String, pattern: String, with replacement: String) -> String {
        value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}

enum EchoSyntheticMediaCapability: String, Codable, Sendable {
    case voiceClone = "voice_clone"
    case digitalHuman = "digital_human"
}

enum EchoSubjectStatus: String, Codable, Sendable {
    case living
    case deceased
    case unknown
}

enum EchoAdultStatus: String, Codable, Sendable {
    case verifiedAdult = "verified_adult"
    case notVerifiedAdult = "not_verified_adult"
    case unknown
}

enum EchoEligibilityVerification: String, Codable, Sendable {
    case verified
    case rejected
    case unknown
}

struct EchoSubjectEligibilityEvidence: Codable, Equatable, Sendable {
    let subjectStatus: EchoSubjectStatus
    let adultStatus: EchoAdultStatus
    let liveness: EchoEligibilityVerification
    let subjectIsActor: EchoEligibilityVerification
    let purposeConsent: EchoEligibilityVerification

    init(
        subjectStatus: EchoSubjectStatus = .unknown,
        adultStatus: EchoAdultStatus = .unknown,
        liveness: EchoEligibilityVerification = .unknown,
        subjectIsActor: EchoEligibilityVerification = .unknown,
        purposeConsent: EchoEligibilityVerification = .unknown
    ) {
        self.subjectStatus = subjectStatus
        self.adultStatus = adultStatus
        self.liveness = liveness
        self.subjectIsActor = subjectIsActor
        self.purposeConsent = purposeConsent
    }

    private enum CodingKeys: String, CodingKey {
        case subjectStatus
        case adultStatus
        case liveness
        case subjectIsActor
        case purposeConsent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjectStatus = try container.decodeIfPresent(EchoSubjectStatus.self, forKey: .subjectStatus) ?? .unknown
        adultStatus = try container.decodeIfPresent(EchoAdultStatus.self, forKey: .adultStatus) ?? .unknown
        liveness = try container.decodeIfPresent(EchoEligibilityVerification.self, forKey: .liveness) ?? .unknown
        subjectIsActor = try container.decodeIfPresent(EchoEligibilityVerification.self, forKey: .subjectIsActor) ?? .unknown
        purposeConsent = try container.decodeIfPresent(EchoEligibilityVerification.self, forKey: .purposeConsent) ?? .unknown
    }
}

enum EchoSubjectEligibilityDenialCode: String, Codable, CaseIterable, Sendable {
    case subjectStatusUnknown = "subject_status_unknown"
    case subjectNotLiving = "subject_not_living"
    case adultStatusUnknown = "adult_status_unknown"
    case subjectNotVerifiedAdult = "subject_not_verified_adult"
    case livenessUnknown = "liveness_unknown"
    case livenessNotVerified = "liveness_not_verified"
    case subjectActorUnknown = "subject_actor_unknown"
    case subjectActorMismatch = "subject_actor_mismatch"
    case purposeConsentUnknown = "purpose_consent_unknown"
    case purposeConsentNotVerified = "purpose_consent_not_verified"
}

struct EchoSubjectEligibilityDecision: Codable, Equatable, Sendable {
    let capability: EchoSyntheticMediaCapability
    let eligible: Bool
    let providerEffectsAllowed: Bool
    let denialCodes: [EchoSubjectEligibilityDenialCode]
}

enum EchoSubjectEligibilityPolicy {
    static func evaluate(
        _ evidence: EchoSubjectEligibilityEvidence,
        for capability: EchoSyntheticMediaCapability
    ) -> EchoSubjectEligibilityDecision {
        var denialCodes: [EchoSubjectEligibilityDenialCode] = []

        switch evidence.subjectStatus {
        case .living:
            break
        case .deceased:
            denialCodes.append(.subjectNotLiving)
        case .unknown:
            denialCodes.append(.subjectStatusUnknown)
        }

        switch evidence.adultStatus {
        case .verifiedAdult:
            break
        case .notVerifiedAdult:
            denialCodes.append(.subjectNotVerifiedAdult)
        case .unknown:
            denialCodes.append(.adultStatusUnknown)
        }

        appendVerificationDenial(
            evidence.liveness,
            unknown: .livenessUnknown,
            rejected: .livenessNotVerified,
            to: &denialCodes
        )
        appendVerificationDenial(
            evidence.subjectIsActor,
            unknown: .subjectActorUnknown,
            rejected: .subjectActorMismatch,
            to: &denialCodes
        )
        appendVerificationDenial(
            evidence.purposeConsent,
            unknown: .purposeConsentUnknown,
            rejected: .purposeConsentNotVerified,
            to: &denialCodes
        )

        let eligible = denialCodes.isEmpty
        return EchoSubjectEligibilityDecision(
            capability: capability,
            eligible: eligible,
            providerEffectsAllowed: eligible,
            denialCodes: denialCodes
        )
    }

    private static func appendVerificationDenial(
        _ value: EchoEligibilityVerification,
        unknown: EchoSubjectEligibilityDenialCode,
        rejected: EchoSubjectEligibilityDenialCode,
        to denialCodes: inout [EchoSubjectEligibilityDenialCode]
    ) {
        switch value {
        case .verified:
            break
        case .rejected:
            denialCodes.append(rejected)
        case .unknown:
            denialCodes.append(unknown)
        }
    }
}
