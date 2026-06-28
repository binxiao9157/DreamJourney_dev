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
        assertTrue(direct.dataState == .available, "direct backend snapshot should be available")
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

        let staleAggregate = ProfileCareSnapshot(json: [
            "item": [
                "snapshot": [
                    "riskLevel": "stable",
                    "summary": "旧窗口数据。",
                    "windowEnd": "2026-05-01T00:00:00Z",
                ],
            ],
        ])

        guard let staleAggregate else {
            fatalError("stale aggregate care snapshot should parse")
        }
        assertTrue(staleAggregate.isStale, "stale backend window should mark snapshot stale")
        assertTrue(staleAggregate.dataState == .stale, "stale backend window should use stale data state")

        let missing = ProfileCareSnapshot(json: ["data": ["irrelevant": true]])
        assertTrue(missing == nil, "care snapshot should reject payloads without signal fields")

        let fallback = ProfileCareSnapshot.offlineFallback()
        assertEqual(fallback.moodStatus, "待同步", "fallback status")
        assertEqual(fallback.emotionalIndex, 0.5, "fallback emotional index")
        assertTrue(fallback.isStale, "fallback should be stale")
        assertTrue(fallback.dataState == .stale, "fallback should use stale data state")
        assertEqual(fallback.syncCaption, "关怀数据暂未同步，当前显示本地安全状态。", "fallback caption")

        let loading = ProfileCareSnapshot.loadingPlaceholder()
        assertTrue(loading.dataState == .loading, "loading placeholder state")
        assertTrue(loading.dataState.isRetryable == false, "loading state should not show manual retry")
        assertEqual(loading.syncCaption, "正在同步关怀信号，稍后会更新聚合结果。", "loading caption")

        let empty = ProfileCareSnapshot.emptyFallback()
        assertTrue(empty.dataState == .empty, "empty fallback state")
        assertTrue(empty.dataState.isRetryable, "empty state should allow retry")
        assertEqual(empty.syncCaption, "暂无可用关怀信号，后续有足够数据后会自动更新。", "empty caption")

        let failed = ProfileCareSnapshot.failedFallback()
        assertTrue(failed.dataState == .failed, "failed fallback state")
        assertTrue(failed.dataState.isRetryable, "failed state should allow retry")
        assertEqual(failed.syncCaption, "关怀信号加载失败，请稍后重试。", "failed caption")

        assertContains(profileSource, "DreamJourneyBackendClient.shared.latestCareSnapshot", "profile should fetch care signal snapshot through backend client")
        assertContains(profileSource, "DreamJourneyBackendClient.shared.isCareSnapshotConfigured", "profile should only fetch care signal snapshot when backend is explicitly configured")
        assertContains(profileSource, "ProfileCareSnapshot(json: json)", "profile should parse backend payload through care snapshot model")
        assertContains(profileSource, "careSnapshot = ProfileCareSnapshot.emptyFallback()", "profile should use an explicit empty state when backend returns no usable care payload")
        assertContains(profileSource, "careSnapshotFallback(for: error)", "profile should classify backend failures into empty or failed state")
        assertContains(profileSource, "return .failedFallback()", "profile should map backend failures to explicit failed state")
        assertContains(profileSource, "makeCareRetryButton()", "profile should expose retry for retryable care states")
        assertContains(profileSource, "care snapshot sync unavailable", "profile should log care backend unavailability")
        assertContains(profileSource, "ProfileCareSnapshot.loadingPlaceholder()", "profile should use an explicit loading state before care backend returns")
        assertContains(profileSource, "makeCareSyncCaption(snapshot:", "profile should render care sync state without raw chat content")
        assertNotContains(profileSource, "ConversationMemoryManager.shared.currentTranscript", "profile must not render raw conversation transcript")
        assertNotContains(profileSource, "DialogMessage", "profile must not render raw dialog messages")

        assertContains(careModelSource, "enum ProfileCareDataState", "care model should define public care data states")
        assertContains(careModelSource, "正在同步关怀信号", "care model should include loading state copy")
        assertContains(careModelSource, "暂无可用关怀信号", "care model should include empty state copy")
        assertContains(careModelSource, "数据可能不是最新", "care model should include stale state copy")
        assertContains(careModelSource, "关怀信号加载失败", "care model should include failed state copy")
        assertNotContains(careModelSource, "transcript", "care model should not expose raw transcript fields")
        assertNotContains(careModelSource, "rawMessages", "care model should not expose raw message fields")
        assertContains(careModelSource, "boundedDoubleValue", "care model should clamp numeric signal fields")
        let backendClientPath = "\(root)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
        let backendClientSource = (try? String(contentsOfFile: backendClientPath, encoding: .utf8)) ?? ""
        assertContains(backendClientSource, "var isCareSnapshotConfigured", "backend client should expose care snapshot configuration state")

        assertContains(legalSource, "不展示聊天原文", "legal copy should promise no raw chat display")
        assertContains(legalSource, "不是医疗诊断", "legal copy should avoid medical diagnosis claims")
        print("Profile care snapshot checks passed")
    }
}
