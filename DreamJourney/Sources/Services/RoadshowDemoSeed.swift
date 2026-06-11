import Foundation

enum RoadshowDemoSeed {
    private static let seededKey = "dreamjourney.roadshow.seeded.v1"
    private static let offlineModeKey = "dreamjourney.roadshow.offlineMode"

    struct LaunchConfiguration: Equatable {
        let shouldSeed: Bool
        let shouldReset: Bool
        let offlineMode: Bool
    }

    struct RuntimeStatus: Equatable {
        let shouldSeed: Bool
        let shouldReset: Bool
        let offlineMode: Bool
        let hasSeededData: Bool

        var isActive: Bool {
            shouldSeed || shouldReset || offlineMode || hasSeededData
        }

        var title: String {
            if offlineMode {
                return "路演模式：本机演示已就绪"
            }
            if shouldSeed || shouldReset || hasSeededData {
                return "路演数据已准备"
            }
            return "路演模式"
        }

        var detail: String {
            if offlineMode {
                return "使用 seed 数据、mock 对话和 mock 安全兜底；不复活、不诊断、不展示私密原文。"
            }
            return "使用固定家庭、信箱、档案、看板和分享包数据；适合现场走完整主线。"
        }
    }

    enum DemoStepID: String, Codable, CaseIterable, Hashable {
        case timeMailbox
        case memoryArchive
        case voiceCompanion
        case careDashboard
        case familySharing
    }

    struct DemoFamilyMember: Codable, Equatable, Hashable {
        let id: String
        let displayName: String
        let relation: String
    }

    struct DemoItem: Codable, Equatable, Hashable {
        let id: String
        let stepID: String
        let title: String
        let body: String
    }

    struct Package: Codable {
        let members: [DemoFamilyMember]
        let selectedMemberIDForVisibility: String
        let transcript: [ConversationTurn]
        let demoItems: [DemoItem]
        let demoSteps: [DemoStepID]
        let boundaryNotices: [String]
    }

    static func launchConfiguration(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LaunchConfiguration {
        let seedValue = environment["DREAMJOURNEY_SEED"]?.lowercased()
        let offlineValue = environment["DREAMJOURNEY_ROADSHOW_OFFLINE"]?.lowercased()
        let resetValue = environment["DREAMJOURNEY_RESET_DEMO"]?.lowercased()

        return LaunchConfiguration(
            shouldSeed: arguments.contains("--seed-roadshow-demo") || seedValue == "roadshow_demo",
            shouldReset: arguments.contains("--reset-roadshow-demo") || resetValue == "1" || resetValue == "true",
            offlineMode: arguments.contains("--roadshow-offline-mode") || offlineValue == "1" || offlineValue == "true"
        )
    }

    static func runtimeStatus(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> RuntimeStatus {
        let configuration = launchConfiguration(arguments: arguments, environment: environment)
        return RuntimeStatus(
            shouldSeed: configuration.shouldSeed,
            shouldReset: configuration.shouldReset,
            offlineMode: configuration.offlineMode || userDefaults.bool(forKey: offlineModeKey),
            hasSeededData: userDefaults.bool(forKey: seededKey)
        )
    }

    static func makePackage(now: Date = Date()) -> Package {
        let daughterID = "fm_daughter_chen_lan"
        let sonID = "fm_son_chen_hao"
        let granddaughterID = "fm_granddaughter_chen_yu"
        let familyMetadata = MemoryPrivacyMetadata(
            scope: .familyCircle,
            createdBySurface: .careDashboard,
            createdAt: now
        )
        let daughterMetadata = MemoryPrivacyMetadata(
            scope: .familyCircle,
            createdBySurface: .careDashboard,
            createdAt: now,
            familyVisibility: .selectedMembers([daughterID])
        )

        return Package(
            members: [
                DemoFamilyMember(id: daughterID, displayName: "陈岚", relation: "女儿"),
                DemoFamilyMember(id: sonID, displayName: "陈浩", relation: "儿子"),
                DemoFamilyMember(id: granddaughterID, displayName: "陈予", relation: "孙女")
            ],
            selectedMemberIDForVisibility: daughterID,
            transcript: [
                ConversationTurn(
                    role: "ai",
                    text: "今天想从哪段回忆开始聊？",
                    timestamp: now.addingTimeInterval(-4 * 24 * 60 * 60),
                    privacyMetadata: familyMetadata
                ),
                ConversationTurn(
                    role: "user",
                    text: "昨晚睡不好，翻到很晚才睡着。",
                    timestamp: now.addingTimeInterval(-3 * 24 * 60 * 60),
                    privacyMetadata: familyMetadata
                ),
                ConversationTurn(
                    role: "user",
                    text: "下午一个人在家有点孤单，想听听陈予的声音。",
                    timestamp: now.addingTimeInterval(-2 * 24 * 60 * 60),
                    privacyMetadata: familyMetadata
                ),
                ConversationTurn(
                    role: "user",
                    text: "这两天胸闷，胃口差，也吃不下多少。",
                    timestamp: now.addingTimeInterval(-24 * 60 * 60),
                    privacyMetadata: daughterMetadata
                ),
                ConversationTurn(
                    role: "ai",
                    text: "我会把这些近况整理成只给家人看的关怀提示。",
                    timestamp: now.addingTimeInterval(-23 * 60 * 60),
                    privacyMetadata: familyMetadata
                ),
                ConversationTurn(
                    role: "user",
                    text: "记忆档案馆保存老相册：1984 年弄堂里全家吃年夜饭。",
                    timestamp: now.addingTimeInterval(-22 * 60 * 60),
                    privacyMetadata: familyMetadata
                ),
                ConversationTurn(
                    role: "user",
                    text: "时空信箱写给陈予十八岁生日：记得常回家吃饭。",
                    timestamp: now.addingTimeInterval(-21 * 60 * 60),
                    privacyMetadata: familyMetadata
                )
            ],
            demoItems: [
                DemoItem(
                    id: "demo_time_mailbox_001",
                    stepID: DemoStepID.timeMailbox.rawValue,
                    title: "时空信箱示例",
                    body: "给陈予十八岁生日的一封信，包含称呼、触发日期、家人可见范围和本机草稿内容。"
                ),
                DemoItem(
                    id: "demo_memory_archive_001",
                    stepID: DemoStepID.memoryArchive.rawValue,
                    title: "记忆档案馆示例",
                    body: "1984 年弄堂年夜饭相册条目，带时间、地点、人物和家庭可见说明。"
                ),
                DemoItem(
                    id: "demo_voice_companion_001",
                    stepID: DemoStepID.voiceCompanion.rawValue,
                    title: "语音陪伴示例",
                    body: "用预置文本演示问候、复述和陪伴，不调用外部服务。"
                ),
                DemoItem(
                    id: "demo_care_dashboard_001",
                    stepID: DemoStepID.careDashboard.rawValue,
                    title: "关怀看板示例",
                    body: "基于 familyCircle 对话生成睡眠、情绪和身体三类脱敏关怀信号。"
                ),
                DemoItem(
                    id: "demo_family_share_001",
                    stepID: DemoStepID.familySharing.rawValue,
                    title: "家族分享包与 KBLite",
                    body: "最小分享包包含 KBLite 人物、地点、事件摘要和可见成员列表。"
                )
            ],
            demoSteps: DemoStepID.allCases,
            boundaryNotices: [
                "这是记忆陪伴演示，不是复活，也不模拟真实亲人的完整人格。",
                "关怀看板不是医疗诊断，只提示家人做日常确认。",
                "分享给家人的只是脱敏信号和授权记忆，不展示完整私密原文。"
            ]
        )
    }
}

#if !CARE_DASHBOARD_VERIFY && !MEMORY_PRIVACY_INTEGRATION_VERIFY
extension RoadshowDemoSeed {
    static func applyIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()
    ) {
        let configuration = launchConfiguration(arguments: arguments, environment: environment)
        guard configuration.shouldSeed || configuration.shouldReset || configuration.offlineMode else {
            return
        }

        UserManager.shared.login(phone: "18800000001", nickname: "路演家庭")

        if configuration.shouldReset {
            resetDemoData()
        }

        UserDefaults.standard.set(configuration.offlineMode, forKey: offlineModeKey)

        guard configuration.shouldReset || configuration.shouldSeed else {
            print("[RoadshowDemo] offlineMode=\(configuration.offlineMode)")
            return
        }

        let alreadySeeded = UserDefaults.standard.bool(forKey: seededKey)
        guard configuration.shouldReset || !alreadySeeded else {
            return
        }

        apply(package: makePackage(now: now), now: now)
        UserDefaults.standard.set(true, forKey: seededKey)
        print("[RoadshowDemo] seed applied; offlineMode=\(configuration.offlineMode)")
    }

    private static func resetDemoData() {
        UserDefaults.standard.removeObject(forKey: seededKey)
        UserDefaults.standard.removeObject(forKey: offlineModeKey)
        UserDefaults.standard.removeObject(forKey: "dreamjourney.timeMailbox.letters")
        UserDefaults.standard.removeObject(forKey: "dreamjourney.memoryArchive.items")

        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent("conversation_memory.json"))
        }

        KBLiteManager.shared.reset()
        print("[RoadshowDemo] demo namespace reset")
    }

    private static func apply(package: Package, now: Date) {
        package.members.forEach { member in
            FamilyRepository.shared.add(
                FamilyMember(
                    id: member.id,
                    name: member.displayName,
                    relation: member.relation,
                    isOnline: member.id == package.selectedMemberIDForVisibility,
                    lastUpdated: member.id == package.selectedMemberIDForVisibility ? "刚刚" : "路演数据"
                )
            )
        }

        seedMailbox(now: now)
        seedMemoryArchive(now: now)
        seedKnowledgeBase(from: package, now: now)
        seedConversationTranscript(package.transcript)
    }

    private static func seedMailbox(now: Date) {
        _ = try? TimeMailboxRepository.shared.createLetter(
            recipientName: "爷爷",
            title: "写给爷爷的一封信",
            body: "爷爷，我今天又想起 1975 年外滩那张合影。\n我会把这份想念好好放进生活里。",
            deliverAt: now.addingTimeInterval(-60),
            now: now.addingTimeInterval(-3600),
            boundaryAcknowledged: true,
            privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
        )
        _ = TimeMailboxRepository.shared.refreshDelivery(now: now)
    }

    private static func seedMemoryArchive(now: Date) {
        let familyMetadata = MemoryPrivacyMetadata(scope: .familyCircle, createdBySurface: .familySync, createdAt: now)
        _ = try? MemoryArchiveRepository.shared.addText(
            kind: .textNote,
            title: "外滩合影的背景",
            note: "1975 年 7 月，陈树安和陈静文在外滩拍过一张全家合影。",
            tags: ["路演", "外滩", "家庭合影"],
            isPrivate: false,
            privacyMetadata: familyMetadata,
            now: now.addingTimeInterval(-3000)
        )
        _ = try? MemoryArchiveRepository.shared.addText(
            kind: .personalityNote,
            title: "陈树安的习惯",
            note: "说话慢，喜欢先听完别人讲完再回答。",
            tags: ["路演", "人格边界"],
            isPrivate: false,
            privacyMetadata: familyMetadata,
            now: now.addingTimeInterval(-2400)
        )
        _ = try? MemoryArchiveRepository.shared.addText(
            kind: .catchphrase,
            title: "慢慢来，饭要趁热吃",
            note: "家人记得的一句口头禅，用于记忆整理，不用于冒充真实逝者。",
            tags: ["路演", "口头禅"],
            isPrivate: false,
            privacyMetadata: familyMetadata,
            now: now.addingTimeInterval(-1800)
        )
        if let photo = try? MemoryArchiveRepository.shared.addPhoto(
            localPath: "roadshow_demo_photo_placeholder",
            title: "外滩老照片",
            note: "路演占位照片，使用本机 mock 分析结果。",
            tags: ["路演", "旧照片"],
            isPrivate: false,
            privacyMetadata: familyMetadata,
            now: now.addingTimeInterval(-1200)
        ) {
            _ = try? MemoryArchiveRepository.shared.applyImageAnalysis(
                id: photo.id,
                analysis: MemoryArchiveImageAnalysis(
                    summary: "老照片中可能是一家人在江边合影，背景有城市建筑和栏杆，整体氛围温暖。",
                    detectedPeople: ["陈树安", "陈静文", "陈岚"],
                    scene: "上海外滩江边",
                    occasion: "家庭合影",
                    mood: "怀旧、温暖",
                    estimatedDecade: 1970
                ),
                now: now
            )
        }
    }

    private static func seedKnowledgeBase(from package: Package, now: Date) {
        let familyMetadata = MemoryPrivacyMetadata(scope: .familyCircle, createdBySurface: .familySync, createdAt: now)
        let daughterMetadata = MemoryPrivacyMetadata(
            scope: .familyCircle,
            createdBySurface: .familySync,
            createdAt: now,
            familyVisibility: .selectedMembers([package.selectedMemberIDForVisibility])
        )

        let graph = KBLiteGraph(
            lastUpdated: now,
            sessionCount: 1,
            people: [
                KBPerson(
                    id: "roadshow_person_grandpa",
                    name: "陈树安",
                    aliases: ["爷爷"],
                    relation: "祖父",
                    traits: ["说话慢", "重视团圆"],
                    briefBio: "家人记忆中的温和长辈，常提醒晚辈慢慢来。",
                    sourceSessionIds: [1],
                    createdAt: now,
                    updatedAt: now,
                    privacyMetadata: familyMetadata
                ),
                KBPerson(
                    id: "roadshow_person_grandma",
                    name: "陈静文",
                    aliases: [],
                    relation: "祖母",
                    traits: ["喜欢整理老照片"],
                    sourceSessionIds: [1],
                    createdAt: now,
                    updatedAt: now,
                    privacyMetadata: daughterMetadata
                )
            ],
            places: [
                KBPlace(
                    id: "roadshow_place_bund",
                    name: "上海外滩",
                    category: "visited",
                    latitude: 31.2400,
                    longitude: 121.4900,
                    description: "路演样例中的家庭合影地点。",
                    relatedPersonIds: ["roadshow_person_grandpa", "roadshow_person_grandma"],
                    sourceSessionIds: [1],
                    createdAt: now,
                    privacyMetadata: familyMetadata
                )
            ],
            events: [
                KBEvent(
                    id: "roadshow_event_bund_photo",
                    title: "外滩全家合影",
                    description: "1975 年 7 月家人在外滩留下的合影记忆。",
                    year: 1975,
                    month: 7,
                    locationId: "roadshow_place_bund",
                    participantIds: ["roadshow_person_grandpa", "roadshow_person_grandma"],
                    sourceSessionIds: [1],
                    createdAt: now,
                    privacyMetadata: familyMetadata
                )
            ],
            facts: [
                KBFact(
                    id: "roadshow_fact_boundary",
                    statement: "时空信箱回声只基于保存记忆整理，不代表逝者真实回复。",
                    confidence: "confirmed",
                    relatedPersonIds: ["roadshow_person_grandpa"],
                    relatedEventIds: ["roadshow_event_bund_photo"],
                    sourceSessionIds: [1],
                    createdAt: now,
                    privacyMetadata: familyMetadata
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(graph), let json = String(data: data, encoding: .utf8) else {
            return
        }
        _ = KBLiteManager.shared.importJSON(json)
    }

    private static func seedConversationTranscript(_ transcript: [ConversationTurn]) {
        transcript.forEach { turn in
            if turn.role.lowercased() == "user" {
                ConversationMemoryManager.shared.recordUserTurn(
                    text: turn.text,
                    privacyMetadata: turn.privacyMetadata
                )
            } else {
                ConversationMemoryManager.shared.recordAITurn(
                    text: turn.text,
                    privacyMetadata: turn.privacyMetadata
                )
            }
        }
        ConversationMemoryManager.shared.endSession()
    }
}
#endif
