import Foundation

func assertEqual(_ lhs: String, _ rhs: String, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs)")
    }
}

func assertEqual(_ lhs: Double, _ rhs: Double, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs)")
    }
}

func assertTrue(_ value: Bool, _ message: String) {
    guard value else {
        fatalError("\(message): expected true")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

@main
enum ProfileCareSnapshotCheck {
    static func main() {
        let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
        let profilePath = "\(root)/DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
        let careModelPath = "\(root)/DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift"
        let legalPath = "\(root)/DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift"

        let profileSource = (try? String(contentsOfFile: profilePath, encoding: .utf8)) ?? ""
        let careModelSource = (try? String(contentsOfFile: careModelPath, encoding: .utf8)) ?? ""
        let legalSource = (try? String(contentsOfFile: legalPath, encoding: .utf8)) ?? ""

        let direct = ProfileCareSnapshot(json: [
            "moodTitle": "今日状态",
            "moodStatus": "平稳",
            "emotionalIndex": 1.7,
            "cognitiveIndex": -0.3,
            "sleepStatus": "睡眠浅",
            "lonelinessIndex": "0.42",
            "riskReminder": "建议今天主动问候一次",
            "transcript": "这是一段不应展示的聊天原文",
            "rawMessages": [
                ["role": "user", "text": "不应进入 UI 模型"],
            ],
        ])

        guard let direct else {
            fatalError("direct care snapshot should parse")
        }

        assertEqual(direct.moodTitle, "今日状态", "direct mood title")
        assertEqual(direct.moodStatus, "平稳", "direct mood status")
        assertEqual(direct.emotionalIndex, 1, "emotional index should clamp upper bound")
        assertEqual(direct.cognitiveIndex, 0, "cognitive index should clamp lower bound")
        assertEqual(direct.lonelinessIndex, 0.42, "string loneliness index should parse")
        assertEqual(direct.riskReminder, "建议今天主动问候一次", "risk reminder")
        assertTrue(direct.isStale == false, "direct backend snapshot should not be stale")
        assertEqual(direct.syncCaption, "建议今天主动问候一次", "direct sync caption should use risk reminder")

        let nested = ProfileCareSnapshot(json: [
            "data": [
                "snapshot": [
                    "moodStatus": "待同步",
                    "emotionalIndex": "0.64",
                    "cognitiveIndex": 0.51,
                    "sleepStatus": "睡眠平稳",
                    "lonelinessIndex": 0.2,
                ],
            ],
        ])

        guard let nested else {
            fatalError("nested care snapshot should parse")
        }

        assertEqual(nested.moodTitle, "心境追踪", "nested default title")
        assertEqual(nested.moodStatus, "待同步", "nested status")
        assertEqual(nested.sleepStatus, "睡眠平稳", "nested sleep status")
        assertEqual(nested.riskReminder, "暂无风险提醒", "nested default risk reminder")

        let backendAggregate = ProfileCareSnapshot(json: [
            "userId": "user_001",
            "item": [
                "snapshot": [
                    "riskLevel": "watch",
                    "summary": "近七天情绪有轻微波动。",
                    "trendSummary": "建议家人今天主动问候。",
                    "suggestions": [
                        "今天可以主动打个电话。",
                    ],
                    "sleepMentions": 2,
                    "repetitionRatio": 0.25,
                    "dailyTrend": [
                        [
                            "date": "2026-06-17",
                            "signalScore": 0.64,
                            "sleepMentions": 2,
                            "repetitionRatio": 0.25,
                        ],
                    ],
                ],
            ],
        ])

        guard let backendAggregate else {
            fatalError("backend aggregate care snapshot should parse")
        }

        assertEqual(backendAggregate.moodStatus, "需关注", "backend risk status")
        assertEqual(backendAggregate.emotionalIndex, 0.64, "backend signal score")
        assertEqual(backendAggregate.cognitiveIndex, 0.75, "backend repetition-derived cognitive index")
        assertEqual(backendAggregate.sleepStatus, "睡眠线索 2 条", "backend sleep status")
        assertEqual(backendAggregate.riskReminder, "今天可以主动打个电话。", "backend first suggestion")

        let missing = ProfileCareSnapshot(json: ["data": ["irrelevant": true]])
        assertTrue(missing == nil, "care snapshot should reject payloads without signal fields")

        let fallback = ProfileCareSnapshot.offlineFallback()
        assertEqual(fallback.moodStatus, "待同步", "fallback status")
        assertEqual(fallback.emotionalIndex, 0.5, "fallback emotional index")
        assertTrue(fallback.isStale, "fallback should be stale")
        assertEqual(fallback.syncCaption, "关怀数据暂未同步，当前显示本地安全状态。", "fallback caption")

        assertContains(profileSource, "DreamJourneyBackendClient.shared.latestCareSnapshot", "profile should fetch care signal snapshot through backend client")
        assertContains(profileSource, "ProfileCareSnapshot(json: json)", "profile should parse backend payload through care snapshot model")
        assertContains(profileSource, "careSnapshot = .offlineFallback()", "profile should use a safe fallback when care backend is unavailable")
        assertContains(profileSource, "makeCareSyncCaption(snapshot:", "profile should render care sync state without raw chat content")
        assertNotContains(profileSource, "ConversationMemoryManager.shared.currentTranscript", "profile must not render raw conversation transcript")
        assertNotContains(profileSource, "DialogMessage", "profile must not render raw dialog messages")

        assertNotContains(careModelSource, "transcript", "care model should not expose raw transcript fields")
        assertNotContains(careModelSource, "rawMessages", "care model should not expose raw message fields")
        assertContains(careModelSource, "boundedDoubleValue", "care model should clamp numeric signal fields")

        assertContains(legalSource, "不展示聊天原文", "legal copy should promise no raw chat display")
        assertContains(legalSource, "不是医疗诊断", "legal copy should avoid medical diagnosis claims")
    }
}
