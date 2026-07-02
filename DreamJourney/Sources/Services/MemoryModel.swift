import Foundation

// MARK: - 回忆模型
struct MemoryModel: Codable, Identifiable {
    let id: String
    var title: String           // 标题，如"上海 · 1975年7月"
    var subtitle: String        // 事件描述（短摘要，地图气泡用）
    var fullContent: String?    // 完整生成内容（散文 prose），详情页正文使用；老数据可能为 nil
    var location: String        // 地点名称
    var year: Int               // 年份
    var month: Int              // 月份
    var latitude: Double        // 纬度
    var longitude: Double       // 经度
    var imageNames: [String]    // 本地图片名列表
    var audioName: String?      // 本地音频文件名（同时作为原始对话录音的 sessionId，用于查找 recordings/{audioName}.m4a）
    var isPrivate: Bool         // 是否私密
    var createdAt: Date
    var updatedAt: Date
    var comments: [CommentModel]
    var likes: [LikeModel]      // 点赞列表
    var supplements: [SupplementModel]  // 亲属补充内容
    var authorId: String

    init(id: String = UUID().uuidString,
         title: String,
         subtitle: String,
         fullContent: String? = nil,
         location: String,
         year: Int,
         month: Int,
         latitude: Double = 31.2304,
         longitude: Double = 121.4737,
         imageNames: [String] = [],
         audioName: String? = nil,
         isPrivate: Bool = false,
         authorId: String = "user_001") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.fullContent = fullContent
        self.location = location
        self.year = year
        self.month = month
        self.latitude = latitude
        self.longitude = longitude
        self.imageNames = imageNames
        self.audioName = audioName
        self.isPrivate = isPrivate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.comments = []
        self.likes = []
        self.supplements = []
        self.authorId = authorId
    }

    /// 当前用户是否已点赞
    func isLikedBy(userId: String) -> Bool {
        return likes.contains { $0.userId == userId }
    }
}

// MARK: - 评论模型
struct CommentModel: Codable, Identifiable {
    let id: String
    var authorId: String
    var authorName: String
    var content: String
    var createdAt: Date

    init(id: String = UUID().uuidString,
         authorId: String,
         authorName: String,
         content: String) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.createdAt = Date()
    }
}

// MARK: - 用户模型
struct UserModel: Codable {
    var id: String
    var nickname: String
    var phone: String           // 明文手机号（本地存储）
    var avatarName: String?     // 系统 SF Symbol 名称作为头像占位
    var gender: String?
    var region: String?

    init(
        id: String,
        nickname: String,
        phone: String,
        avatarName: String? = nil,
        gender: String? = nil,
        region: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.phone = phone
        self.avatarName = avatarName
        self.gender = gender
        self.region = region
    }

    var maskedPhone: String {
        guard phone.count >= 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }

    var recordYears: Int {
        // Mock：基于 id 计算年数
        return 75
    }
}

// MARK: - 亲属模型
struct FamilyMember: Codable, Identifiable {
    let id: String
    var name: String
    var relation: String        // "祖母"/"父亲"/"母亲"/"子女"/"配偶"等
    var phone: String?
    var avatarName: String?
    var joinedAt: Date
    /// 在线状态：true=在线，false=离线
    var isOnline: Bool
    /// 最近更新描述，如“2小时前”“昨天”“刚刚”
    var lastUpdated: String
    /// 家庭数字人后端合同字段；默认隐藏，不代表公开入口可见。
    var personaScope: String
    var digitalHumanId: String
    /// 数字人生命周期状态：默认阳光，只有星辰状态启用心境追踪。
    var digitalHumanMode: DigitalHumanMode
    var familyPersonaContractVersion: Int
    var backendContractMode: String?
    var defaultReleaseVisible: Bool
    var accessStatus: String
    var invitationStatus: String
    var invitationURL: String?
    var invitationCode: String?
    var invitationError: String?
    /// 家人对应的复刻音色合同字段；Echo 只消费 ready + enabled 的音色。
    var voiceProfileId: String?
    var voiceSampleStatus: String
    var voiceEnabled: Bool

    var digitalHumanModeLabel: String {
        digitalHumanMode.displayName
    }

    var isAcceptedFamilyMember: Bool {
        accessStatus.lowercased() == "active" && invitationStatus.lowercased() == "accepted"
    }

    var familyInvitationDisplayName: String {
        if isAcceptedFamilyMember {
            return "已加入"
        }
        if invitationStatus.lowercased() == "failed" || accessStatus.lowercased() == "failed" {
            return "邀请失败"
        }
        return "邀请中"
    }

    var normalizedVoiceProfileId: String? {
        guard let voiceProfileId else { return nil }
        let trimmed = voiceProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isVoiceProfileReadyForEcho: Bool {
        guard normalizedVoiceProfileId != nil, voiceEnabled else { return false }
        switch voiceSampleStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ready", "accepted":
            return true
        default:
            return false
        }
    }

    var voiceCloneStatusLabel: String {
        guard normalizedVoiceProfileId != nil else {
            return "未配置复刻音色"
        }
        switch voiceSampleStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ready", "accepted" where voiceEnabled:
            return "复刻音色可用于回响"
        case "pending", "training", "processing":
            return "复刻音色训练中"
        case "failed":
            return "复刻音色训练失败"
        case "disabled":
            return "复刻音色已停用"
        default:
            return voiceEnabled ? "复刻音色待确认" : "复刻音色未启用"
        }
    }

    init(id: String = UUID().uuidString, name: String, relation: String,
         phone: String? = nil, isOnline: Bool = false, lastUpdated: String = "未知",
         personaScope: String = "family", digitalHumanId: String? = nil,
         digitalHumanMode: DigitalHumanMode = .sunlight,
         familyPersonaContractVersion: Int = 1,
         backendContractMode: String? = nil,
         defaultReleaseVisible: Bool = false,
         accessStatus: String = "active",
         invitationStatus: String = "accepted",
         invitationURL: String? = nil,
         invitationCode: String? = nil,
         invitationError: String? = nil,
         voiceProfileId: String? = nil,
         voiceSampleStatus: String = "notProvided",
         voiceEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.relation = relation
        self.phone = phone
        self.avatarName = nil
        self.joinedAt = Date()
        self.isOnline = isOnline
        self.lastUpdated = lastUpdated
        self.personaScope = personaScope
        self.digitalHumanId = digitalHumanId ?? id
        self.digitalHumanMode = digitalHumanMode
        self.familyPersonaContractVersion = familyPersonaContractVersion
        self.backendContractMode = backendContractMode
        self.defaultReleaseVisible = defaultReleaseVisible
        self.accessStatus = accessStatus
        self.invitationStatus = invitationStatus
        self.invitationURL = invitationURL
        self.invitationCode = invitationCode
        self.invitationError = invitationError
        self.voiceProfileId = voiceProfileId
        self.voiceSampleStatus = voiceSampleStatus
        self.voiceEnabled = voiceEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case relation
        case phone
        case avatarName
        case joinedAt
        case isOnline
        case lastUpdated
        case personaScope
        case digitalHumanId
        case digitalHumanMode
        case familyPersonaContractVersion
        case backendContractMode
        case defaultReleaseVisible
        case accessStatus
        case invitationStatus
        case invitationURL
        case invitationCode
        case invitationError
        case voiceProfileId
        case voiceSampleStatus
        case voiceEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        relation = try container.decode(String.self, forKey: .relation)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        avatarName = try container.decodeIfPresent(String.self, forKey: .avatarName)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? Date()
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated) ?? "未知"
        personaScope = try container.decodeIfPresent(String.self, forKey: .personaScope) ?? "family"
        digitalHumanId = try container.decodeIfPresent(String.self, forKey: .digitalHumanId) ?? id
        digitalHumanMode = try container.decodeIfPresent(DigitalHumanMode.self, forKey: .digitalHumanMode) ?? .sunlight
        familyPersonaContractVersion = try container.decodeIfPresent(Int.self, forKey: .familyPersonaContractVersion) ?? 1
        backendContractMode = try container.decodeIfPresent(String.self, forKey: .backendContractMode)
        defaultReleaseVisible = try container.decodeIfPresent(Bool.self, forKey: .defaultReleaseVisible) ?? false
        accessStatus = try container.decodeIfPresent(String.self, forKey: .accessStatus) ?? "active"
        invitationStatus = try container.decodeIfPresent(String.self, forKey: .invitationStatus) ?? "accepted"
        invitationURL = try container.decodeIfPresent(String.self, forKey: .invitationURL)
        invitationCode = try container.decodeIfPresent(String.self, forKey: .invitationCode)
        invitationError = try container.decodeIfPresent(String.self, forKey: .invitationError)
        voiceProfileId = try container.decodeIfPresent(String.self, forKey: .voiceProfileId)
        voiceSampleStatus = try container.decodeIfPresent(String.self, forKey: .voiceSampleStatus) ?? "notProvided"
        voiceEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? false
    }

    static func fromBackendJSON(_ object: [String: Any]) -> FamilyMember? {
        guard let id = stringValue(in: object, for: "id"),
              let name = stringValue(in: object, for: "name") else {
            return nil
        }

        return FamilyMember(
            id: id,
            name: name,
            relation: stringValue(in: object, for: "relation") ?? "亲属",
            phone: stringValue(in: object, for: "phone"),
            isOnline: stringValue(in: object, for: "accessStatus")?.lowercased() == "active",
            lastUpdated: stringValue(in: object, for: "lastUpdated")
                ?? stringValue(in: object, for: "updatedAt")
                ?? stringValue(in: object, for: "acceptedAt")
                ?? "后端已同步",
            personaScope: stringValue(in: object, for: "personaScope") ?? "family",
            digitalHumanId: stringValue(in: object, for: "digitalHumanId") ?? id,
            digitalHumanMode: digitalHumanMode(from: object) ?? .sunlight,
            familyPersonaContractVersion: intValue(in: object, for: "familyPersonaContractVersion") ?? 1,
            backendContractMode: stringValue(in: object, for: "backendContractMode"),
            defaultReleaseVisible: boolValue(in: object, for: "defaultReleaseVisible") ?? false,
            accessStatus: stringValue(in: object, for: "accessStatus") ?? "pending",
            invitationStatus: stringValue(in: object, for: "invitationStatus") ?? "pending",
            invitationURL: stringValue(in: object, for: "invitationURL"),
            invitationCode: stringValue(in: object, for: "invitationCode"),
            invitationError: stringValue(in: object, for: "invitationError"),
            voiceProfileId: stringValue(in: object, for: "voiceProfileId"),
            voiceSampleStatus: stringValue(in: object, for: "voiceSampleStatus") ?? "notProvided",
            voiceEnabled: boolValue(in: object, for: "voiceEnabled") ?? false
        )
    }

    private static func digitalHumanMode(from object: [String: Any]) -> DigitalHumanMode? {
        if let rawMode = stringValue(in: object, for: "digitalHumanMode"),
           let mode = DigitalHumanMode(rawValue: rawMode) {
            return mode
        }
        switch stringValue(in: object, for: "digitalHumanModeLabel") {
        case "阳光":
            return .sunlight
        case "星辰":
            return .star
        case "静默":
            return .silent
        default:
            return nil
        }
    }

    private static func stringValue(in object: [String: Any], for key: String) -> String? {
        guard let value = object[key] else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func intValue(in object: [String: Any], for key: String) -> Int? {
        guard let value = object[key] else { return nil }
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private static func boolValue(in object: [String: Any], for key: String) -> Bool? {
        guard let value = object[key] else { return nil }
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

extension FamilyMember: FamilyInvitationMessageSource {
    var familyMemberId: String { id }
    var familyMemberName: String { name }
    var familyMemberRelation: String { relation }
    var familyMemberPhone: String? { phone }
    var familyInvitationStatus: String { invitationStatus }
    var familyAccessStatus: String { accessStatus }
    var familyInvitationError: String? { invitationError }
    var familyLastUpdated: String { lastUpdated }
}

// MARK: - 点赞模型
struct LikeModel: Codable, Identifiable {
    let id: String
    var userId: String
    var userName: String
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, userName: String) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.createdAt = Date()
    }
}

// MARK: - 补充回忆模型（亲属补充内容）
struct SupplementModel: Codable, Identifiable {
    let id: String
    var authorId: String
    var authorName: String
    var content: String
    var createdAt: Date

    init(id: String = UUID().uuidString, authorId: String, authorName: String, content: String) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.createdAt = Date()
    }
}
