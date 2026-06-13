import Foundation

// MARK: - FamilyRepository 单例：亲属关系存储
final class FamilyRepository {

    static let shared = FamilyRepository()
    private init() {
        loadLocalAccessState()
        NotificationCenter.default.addObserver(self, selector: #selector(onKBUpdated), name: .kbLiteDidUpdate, object: nil)
        // 延迟首次同步（等知识库加载完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.syncFromKnowledgeBase()
        }
    }

    @objc private func onKBUpdated() {
        syncFromKnowledgeBase()
    }

    private var members: [FamilyMember] = []
    private var acceptedInvitations: [String: FamilyAccessControlService.Invitation] = [:]
    private var revokedAccessMemberIDs = Set<String>()
    private let viewerOverrideKey = "dj_family_viewer_member_id"
    private let acceptedInvitationsKey = "dj_family_accepted_invitations"
    private let revokedAccessMemberIDsKey = "dj_family_revoked_access_member_ids"

    func getAll() -> [FamilyMember] { return members }

    func add(_ member: FamilyMember) {
        // 去重
        if !members.contains(where: { $0.name == member.name }) {
            members.append(member)
        }
    }

    func remove(id: String) {
        members.removeAll { $0.id == id }
        acceptedInvitations.removeValue(forKey: id)
        revokedAccessMemberIDs.remove(id)
        saveLocalAccessState()
    }

    func get(by id: String) -> FamilyMember? {
        return members.first { $0.id == id }
    }

    func setLocalViewerFamilyMemberID(_ memberID: String?) {
        let trimmed = memberID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty, get(by: trimmed) != nil {
            UserDefaults.standard.set(trimmed, forKey: viewerOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: viewerOverrideKey)
        }
    }

    func currentViewerIdentity() -> FamilyAccessIdentityResolver.ViewerIdentity? {
        let userRecord = UserManager.shared.currentUser.map {
            FamilyAccessIdentityResolver.UserRecord(id: $0.id, phone: $0.phone)
        }
        let memberRecords = members.map {
            FamilyAccessIdentityResolver.MemberRecord(id: $0.id, phone: $0.phone)
        }
        guard let identity = FamilyAccessIdentityResolver.resolveViewer(
            currentUser: userRecord,
            members: memberRecords,
            overrideFamilyMemberID: UserDefaults.standard.string(forKey: viewerOverrideKey)
        ) else {
            return nil
        }
        return revokedAccessMemberIDs.contains(identity.familyMemberID) ? nil : identity
    }

    func acceptLocalInvitation(phone: String, acceptedAt: Date = Date()) -> FamilyMember? {
        guard let memberIndex = members.firstIndex(where: { normalizedPhone($0.phone) == normalizedPhone(phone) }),
              !revokedAccessMemberIDs.contains(members[memberIndex].id) else {
            return nil
        }

        let member = members[memberIndex]
        let invitation = FamilyAccessControlService.Invitation(
            id: "local_invite_\(member.id)",
            familyMemberID: member.id,
            phone: member.phone ?? phone,
            status: .pending,
            createdAt: member.joinedAt
        )
        guard let accepted = FamilyAccessControlService.acceptInvitation(
            invitation,
            phone: phone,
            acceptedAt: acceptedAt
        ) else {
            return nil
        }

        acceptedInvitations[member.id] = accepted
        setLocalViewerFamilyMemberID(member.id)
        members[memberIndex].isOnline = true
        members[memberIndex].lastUpdated = "刚刚接受邀请"
        saveLocalAccessState()
        return members[memberIndex]
    }

    @discardableResult
    func revokeAccess(for memberID: String) -> Bool {
        guard get(by: memberID) != nil else {
            return false
        }

        let shouldClearViewerOverride = currentViewerIdentity()?.familyMemberID == memberID
        revokedAccessMemberIDs.insert(memberID)
        acceptedInvitations[memberID] = acceptedInvitations[memberID].map {
            FamilyAccessControlService.Invitation(
                id: $0.id,
                familyMemberID: $0.familyMemberID,
                phone: $0.phone,
                status: .revoked,
                createdAt: $0.createdAt,
                acceptedAt: $0.acceptedAt
            )
        }
        if shouldClearViewerOverride {
            setLocalViewerFamilyMemberID(nil)
        }
        if let index = members.firstIndex(where: { $0.id == memberID }) {
            members[index].isOnline = false
            members[index].lastUpdated = "访问已撤回"
        }
        saveLocalAccessState()
        return true
    }

    func isAccessRevoked(for memberID: String) -> Bool {
        revokedAccessMemberIDs.contains(memberID)
    }

    func resetLocalAccessState() {
        acceptedInvitations.removeAll()
        revokedAccessMemberIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: acceptedInvitationsKey)
        UserDefaults.standard.removeObject(forKey: revokedAccessMemberIDsKey)
        setLocalViewerFamilyMemberID(nil)
    }

    // MARK: - KBLite 同步：从知识库中提取人物 → 亲属圈

    /// 供外部按需调用的公开同步方法
    func refreshFromKnowledgeBase() {
        syncFromKnowledgeBase()
    }

    /// 将知识库中识别到的人物自动同步到亲属圈列表
    private func syncFromKnowledgeBase() {
        let graph = KBLiteManager.shared.sanitizedGraph(for: .familySync)
        guard !graph.people.isEmpty else { return }

        // 常见关系映射
        let relationKeywords: [(keyword: String, relation: String)] = [
            ("祖父", "grandfather"), ("爷爷", "grandfather"),
            ("祖母", "grandmother"), ("奶奶", "grandmother"),
            ("外公", "grandfather"), ("外婆", "grandmother"),
            ("爸爸", "father"), ("父亲", "father"),
            ("妈妈", "mother"), ("母亲", "mother"),
            ("老伴", "spouse"), ("老公", "husband"), ("老婆", "wife"),
            ("哥哥", "brother"), ("姐姐", "sister"),
            ("弟弟", "brother"), ("妹妹", "sister"),
            ("儿子", "son"), ("女儿", "daughter"),
            ("叔叔", "uncle"), ("阿姨", "aunt"),
            ("老师", "teacher"), ("师傅", "mentor"),
            ("同学", "classmate"), ("战友", "comrade"),
        ]

        for person in graph.people {
            guard !KBLiteManager.isGenericKinshipDisplayName(person.name) else { continue }
            // 检查是否已存在
            if members.contains(where: { $0.name == person.name || person.aliases.contains($0.name) }) {
                continue
            }

            // 推断关系
            let relation: String
            if let rel = person.relation {
                relation = rel
            } else {
                // 从名字推断关系
                var guessed = "亲属"
                for (keyword, rel) in relationKeywords {
                    if person.name.contains(keyword) {
                        guessed = rel
                        break
                    }
                }
                // 从特征推断
                if guessed == "亲属", !person.traits.isEmpty {
                    guessed = person.traits.first!
                }
                relation = guessed
            }

            // 在线状态：最近 24 小时内有会话更新的人物标记为"在线"
            let isRecent = person.sourceSessionIds.last.map { $0 >= graph.sessionCount - 1 } ?? false

            let lastUpdated: String
            if isRecent {
                lastUpdated = "刚刚聊到"
            } else if let lastSession = person.sourceSessionIds.last {
                lastUpdated = "第\(lastSession)次会话"
            } else {
                lastUpdated = "未知"
            }

            let member = FamilyMember(
                id: "kb_\(person.id.prefix(8))",
                name: person.name,
                relation: relation,
                isOnline: isRecent,
                lastUpdated: lastUpdated
            )
            members.append(member)
        }

        print("[FamilyRepo] 🔄 已从知识库同步 \(graph.people.count) 人 → 亲属圈 (总数: \(members.count))")
    }

    private func normalizedPhone(_ phone: String?) -> String? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }

    private func loadLocalAccessState() {
        if let data = UserDefaults.standard.data(forKey: acceptedInvitationsKey),
           let decoded = try? JSONDecoder().decode([String: FamilyAccessControlService.Invitation].self, from: data) {
            acceptedInvitations = decoded
        }
        let revokedIDs = UserDefaults.standard.stringArray(forKey: revokedAccessMemberIDsKey) ?? []
        revokedAccessMemberIDs = Set(revokedIDs)
    }

    private func saveLocalAccessState() {
        if let data = try? JSONEncoder().encode(acceptedInvitations) {
            UserDefaults.standard.set(data, forKey: acceptedInvitationsKey)
        }
        UserDefaults.standard.set(Array(revokedAccessMemberIDs).sorted(), forKey: revokedAccessMemberIDsKey)
    }
}
