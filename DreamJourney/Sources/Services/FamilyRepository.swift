import Foundation

// MARK: - FamilyRepository 单例：亲属关系存储
final class FamilyRepository {

    static let shared = FamilyRepository()
    private init() {
        loadModeOverrides()
        seedMockData()
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
    private var modeOverrides: [String: DigitalHumanMode] = [:]
    private let modeOverridesKey = "dj.family.digitalHumanModeOverrides"

    func getAll() -> [FamilyMember] { return members }

    var hasStarModeMember: Bool {
        members.contains { $0.digitalHumanMode == .star }
    }

    func add(_ member: FamilyMember) {
        // 去重
        if !members.contains(where: { $0.name == member.name }) {
            members.append(member)
            notifyMembersChanged()
        }
    }

    func remove(id: String) {
        // PRD: 家庭成员通过手机号邀请后不可删除；退出/解除关系未明确，暂不实现。
    }

    func get(by id: String) -> FamilyMember? {
        return members.first { $0.id == id }
    }

    func updateMode(memberId: String, mode: DigitalHumanMode) {
        guard let index = members.firstIndex(where: { $0.id == memberId }) else { return }
        members[index].digitalHumanMode = mode
        modeOverrides[memberId] = mode
        persistModeOverrides()
        notifyMembersChanged()
    }

    func refreshFromBackend(userId: String, completion: ((Result<[FamilyMember], Error>) -> Void)? = nil) {
        DreamJourneyBackendClient.shared.fetchFamilyMembers(userId: userId) { [weak self] result in
            switch result {
            case .success(let remoteMembers):
                self?.mergeRemoteMembers(remoteMembers)
                completion?(.success(remoteMembers))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func inviteByPhone(
        userId: String,
        phone: String,
        name: String,
        relation: String,
        completion: @escaping (Result<FamilyMember, Error>) -> Void
    ) {
        DreamJourneyBackendClient.shared.inviteFamilyMember(
            userId: userId,
            name: name,
            relation: relation,
            phone: phone
        ) { [weak self] result in
            switch result {
            case .success(let member):
                self?.upsert(member)
                completion(.success(member))
            case .failure(let error):
                let failedMember = FamilyMember(
                    id: "family_invite_failed_\(UUID().uuidString)",
                    name: name,
                    relation: relation,
                    phone: phone,
                    isOnline: false,
                    lastUpdated: "邀请失败",
                    accessStatus: "failed",
                    invitationStatus: "failed",
                    invitationError: error.localizedDescription
                )
                self?.upsert(failedMember)
                completion(.failure(error))
            }
        }
    }

    // MARK: - KBLite 同步：从知识库中提取人物 → 亲属圈

    /// 供外部按需调用的公开同步方法
    func refreshFromKnowledgeBase() {
        syncFromKnowledgeBase()
    }

    /// 将知识库中识别到的人物自动同步到亲属圈列表
    private func syncFromKnowledgeBase() {
        let graph = KBLiteManager.shared.graph
        guard !graph.people.isEmpty else { return }
        var didAppendMember = false

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
            let isRecent = person.sourceSessionIds.last.map { $0 >= KBLiteManager.shared.graph.sessionCount - 1 } ?? false

            let lastUpdated: String
            if isRecent {
                lastUpdated = "刚刚聊到"
            } else if let lastSession = person.sourceSessionIds.last {
                lastUpdated = "第\(lastSession)次会话"
            } else {
                lastUpdated = "未知"
            }

            let member = applyModeOverride(to: FamilyMember(
                id: "kb_\(person.id.prefix(8))",
                name: person.name,
                relation: relation,
                isOnline: isRecent,
                lastUpdated: lastUpdated
            ))
            members.append(member)
            didAppendMember = true
        }

        print("[FamilyRepo] 🔄 已从知识库同步 \(graph.people.count) 人 → 亲属圈 (总数: \(members.count))")
        if didAppendMember {
            notifyMembersChanged()
        }
    }

    // MARK: - Mock 数据
    private func seedMockData() {
        members = [
            FamilyMember(id: "fm_001", name: "林静文", relation: "祖母",  phone: nil, isOnline: false, lastUpdated: "2小时前"),
            FamilyMember(id: "fm_002", name: "张国强", relation: "父亲",  phone: nil, isOnline: false, lastUpdated: "昨天"),
            FamilyMember(id: "fm_003", name: "周美芳", relation: "母亲",  phone: nil, isOnline: true,  lastUpdated: "刚刚")
        ].map(applyModeOverride(to:))
    }

    private func applyModeOverride(to member: FamilyMember) -> FamilyMember {
        guard let mode = modeOverrides[member.id] else { return member }
        var updated = member
        updated.digitalHumanMode = mode
        return updated
    }

    private func mergeRemoteMembers(_ remoteMembers: [FamilyMember]) {
        var didChangeMembers = false
        for remoteMember in remoteMembers {
            let updatedMember = applyModeOverride(to: remoteMember)
            if let index = members.firstIndex(where: { $0.id == updatedMember.id }) {
                members[index] = updatedMember
                didChangeMembers = true
            } else if let index = members.firstIndex(where: {
                $0.name == updatedMember.name && $0.relation == updatedMember.relation
            }) {
                members[index] = updatedMember
                didChangeMembers = true
            } else {
                members.append(updatedMember)
                didChangeMembers = true
            }
        }
        if didChangeMembers {
            notifyMembersChanged()
        }
    }

    private func upsert(_ member: FamilyMember) {
        let updatedMember = applyModeOverride(to: member)
        if let index = members.firstIndex(where: { $0.id == updatedMember.id }) {
            members[index] = updatedMember
        } else if let phone = updatedMember.phone,
                  let index = members.firstIndex(where: { $0.phone == phone && !$0.isAcceptedFamilyMember }) {
            members[index] = updatedMember
        } else {
            members.append(updatedMember)
        }
        notifyMembersChanged()
    }

    private func loadModeOverrides() {
        guard let rawValues = UserDefaults.standard.dictionary(forKey: modeOverridesKey) as? [String: String] else {
            modeOverrides = [:]
            return
        }
        modeOverrides = rawValues.reduce(into: [:]) { result, pair in
            if let mode = DigitalHumanMode(rawValue: pair.value) {
                result[pair.key] = mode
            }
        }
    }

    private func persistModeOverrides() {
        let rawValues = modeOverrides.mapValues(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: modeOverridesKey)
    }

    private func notifyMembersChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .djFamilyMembersDidChange, object: self.members)
        }
    }
}

extension Notification.Name {
    static let djFamilyMembersDidChange = Notification.Name("dj.family.membersDidChange")
}
