import Foundation

@main
enum EchoSafetyPolicyModelSmoke {
    static func main() throws {
        verifyPositiveCorpus()
        verifyNegativeCorpus()
        verifyNeutralDecision()
        verifyCrisisDecision()
        verifyPersistentDisclosure()
        try verifySubjectEligibility()
        print("Echo safety policy model smoke passed")
    }

    private static func verifyNeutralDecision() {
        let decision = EchoSafetyPolicy.evaluate(text: "今天想聊聊旅行。")
        require(!decision.isCrisis, "ordinary input must remain in neutral assistant mode")
        require(decision.mode == .neutralAssistant, "ordinary input must retain neutral assistant mode")
        require(decision.effects.persona, "ordinary input may retain the selected persona")
        require(decision.allowsContext, "ordinary input may use authorized context")
        require(decision.allowsDelayedReply, "ordinary input may use delayed reply pacing")
        require(decision.effects.clonedVoice, "ordinary input may use an otherwise authorized cloned voice")
        require(decision.effects.digitalHuman, "ordinary input may use an otherwise authorized digital human")
        require(decision.allowsProviderEffects, "ordinary input may use otherwise authorized provider effects")
    }

    private static func verifyPositiveCorpus() {
        let cases: [(String, EchoSafetyRiskClass)] = [
            ("我现在想自杀", .selfHarm),
            ("我不想活了", .selfHarm),
            ("I plan to kill myself", .selfHarm),
            ("I'm suicidal", .selfHarm),
            ("我要杀了他", .harmToOthers),
            ("I am going to hurt them", .harmToOthers),
            ("我想死了去陪去世的妈妈", .joinDeceased),
            ("I want to die to be with my late father", .joinDeceased),
            ("我想去陪已经去世的爷爷", .joinDeceased),
            ("I want to join my deceased wife", .joinDeceased),
            ("我的孩子刚刚走失了", .immediateMissingPersonDanger),
            ("I am in immediate danger", .immediateMissingPersonDanger),
            ("我的女儿刚才不见了", .immediateMissingPersonDanger),
            ("I am in danger right now", .immediateMissingPersonDanger),
            ("我真的撑不住了", .highDistress),
            ("我快要崩溃了", .highDistress),
            ("I can't go on", .highDistress),
        ]

        for (text, expected) in cases {
            require(
                EchoSafetyPolicy.classify(text) == expected,
                "expected \(expected.rawValue) for: \(text)"
            )
        }
    }

    private static func verifyNegativeCorpus() {
        let cases = [
            "奶奶去世后，我一直很难过。",
            "最近有点焦虑，晚上睡不好。",
            "工作压力很大，但我准备先休息一下。",
            "我不想自杀，只是需要休息。",
            "I am not suicidal; I am grieving.",
            "I don't want to die. I want help with anxiety.",
            "She said, \"I want to die\", in the film.",
            "My friend said I want to die while quoting a movie.",
            "“我想自杀”这句话需要怎样翻译？",
            "他没有失踪，只是手机没电了。",
            "My child is not missing; she is at school.",
            "我想去陪妈妈吃晚饭。",
        ]

        for text in cases {
            require(EchoSafetyPolicy.classify(text) == .none, "false positive for: \(text)")
        }
    }

    private static func verifyCrisisDecision() {
        let decision = EchoSafetyPolicy.evaluate(text: "我现在想自杀")
        require(decision.isCrisis, "explicit self-harm must produce a crisis decision")
        require(decision.mode == .neutralSafety, "crisis must select neutral safety mode")
        require(decision.action == .enterNeutralSafetyMode, "crisis must enter the safety action")
        require(!decision.effects.persona, "crisis must deny persona")
        require(!decision.allowsContext, "crisis must deny memory and context effects")
        require(!decision.allowsDelayedReply, "crisis must never enqueue a delayed reply")
        require(!decision.effects.clonedVoice, "crisis must deny cloned voice")
        require(!decision.effects.digitalHuman, "crisis must deny digital human")
        require(!decision.effects.providerEffects, "crisis must deny provider effects")

        let response = decision.responseText ?? ""
        require(response.contains("可信任的人"), "safe response must direct the user to a trusted person")
        require(response.contains("当地紧急服务"), "safe response must mention local emergency services")
        for forbidden in ["诊断", "治疗你", "照顾你", "保证", "承诺", "一直陪着你"] {
            require(!response.contains(forbidden), "safe response must not diagnose or promise care: \(forbidden)")
        }
    }

    private static func verifyPersistentDisclosure() {
        for text in ["今天想聊聊旅行。", "I plan to kill myself"] {
            let disclosure = EchoSafetyPolicy.evaluate(text: text).disclosure
            require(disclosure.required, "AI disclosure must always be required")
            require(disclosure.presentation == .persistent, "AI disclosure must be persistent")
            require(disclosure.label.contains("AI"), "AI disclosure must identify the system as AI")
            require(disclosure.label.contains("非真人本人"), "AI disclosure must deny real-person identity")
        }
    }

    private static func verifySubjectEligibility() throws {
        let eligibleEvidence = EchoSubjectEligibilityEvidence(
            subjectStatus: .living,
            adultStatus: .verifiedAdult,
            liveness: .verified,
            subjectIsActor: .verified,
            purposeConsent: .verified
        )

        for capability in [EchoSyntheticMediaCapability.voiceClone, .digitalHuman] {
            let decision = EchoSubjectEligibilityPolicy.evaluate(eligibleEvidence, for: capability)
            require(decision.eligible, "complete self-subject evidence must be eligible")
            require(decision.providerEffectsAllowed, "eligible evidence may reach the provider boundary")
            require(decision.denialCodes.isEmpty, "eligible evidence must have no denial code")
        }

        let legacy = try JSONDecoder().decode(EchoSubjectEligibilityEvidence.self, from: Data("{}".utf8))
        let legacyDecision = EchoSubjectEligibilityPolicy.evaluate(legacy, for: .voiceClone)
        require(!legacyDecision.eligible, "missing legacy fields must deny")
        require(!legacyDecision.providerEffectsAllowed, "missing legacy fields must deny provider effects")
        require(
            legacyDecision.denialCodes == [
                .subjectStatusUnknown,
                .adultStatusUnknown,
                .livenessUnknown,
                .subjectActorUnknown,
                .purposeConsentUnknown,
            ],
            "legacy denial codes must be complete and stable"
        )

        let thirdParty = EchoSubjectEligibilityEvidence(
            subjectStatus: .living,
            adultStatus: .verifiedAdult,
            liveness: .verified,
            subjectIsActor: .rejected,
            purposeConsent: .verified
        )
        requireDenied(thirdParty, code: .subjectActorMismatch, "third-party subject")

        let minor = EchoSubjectEligibilityEvidence(
            subjectStatus: .living,
            adultStatus: .notVerifiedAdult,
            liveness: .verified,
            subjectIsActor: .verified,
            purposeConsent: .verified
        )
        requireDenied(minor, code: .subjectNotVerifiedAdult, "non-adult subject")

        let deceased = EchoSubjectEligibilityEvidence(
            subjectStatus: .deceased,
            adultStatus: .verifiedAdult,
            liveness: .verified,
            subjectIsActor: .verified,
            purposeConsent: .verified
        )
        requireDenied(deceased, code: .subjectNotLiving, "deceased subject")

        let noLiveness = EchoSubjectEligibilityEvidence(
            subjectStatus: .living,
            adultStatus: .verifiedAdult,
            liveness: .rejected,
            subjectIsActor: .verified,
            purposeConsent: .verified
        )
        requireDenied(noLiveness, code: .livenessNotVerified, "failed liveness")

        let noConsent = EchoSubjectEligibilityEvidence(
            subjectStatus: .living,
            adultStatus: .verifiedAdult,
            liveness: .verified,
            subjectIsActor: .verified,
            purposeConsent: .rejected
        )
        requireDenied(noConsent, code: .purposeConsentNotVerified, "missing purpose consent")
    }

    private static func requireDenied(
        _ evidence: EchoSubjectEligibilityEvidence,
        code: EchoSubjectEligibilityDenialCode,
        _ label: String
    ) {
        for capability in [EchoSyntheticMediaCapability.voiceClone, .digitalHuman] {
            let decision = EchoSubjectEligibilityPolicy.evaluate(evidence, for: capability)
            require(!decision.eligible, "\(label) must deny \(capability.rawValue)")
            require(!decision.providerEffectsAllowed, "\(label) must deny provider effects")
            require(decision.denialCodes.contains(code), "\(label) must return \(code.rawValue)")
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Echo safety policy model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
