import Foundation

struct FamilyRelationshipCandidate: Equatable, Identifiable {
    let id: String
    let ownerUserId: String
    let personId: String
    let name: String
    let aliases: [String]
    let relation: String
    let evidenceStatus: String
}

enum FamilyRepositoryError: LocalizedError {
    case noActiveOwner
    case ownerMismatch
    case staleResponse
    case invalidBackendRecord

    var errorDescription: String? {
        switch self {
        case .noActiveOwner:
            return "请先登录后再管理家人"
        case .ownerMismatch:
            return "家庭数据与当前账号不匹配"
        case .staleResponse:
            return "账号已切换，已忽略旧家庭数据"
        case .invalidBackendRecord:
            return "家庭关系授权信息不完整"
        }
    }
}

// MARK: - FamilyRepository 单例：亲属关系存储
final class FamilyRepository {

    static let shared = FamilyRepository()
    private let accountLeaseRuntime = AccountLeaseRuntime.shared

    private init() {
        activeOwnerUserId = Self.normalizedUserId(UserManager.shared.currentUser?.id)
        loadModeOverrides()
        loadVoiceProfileOverrides()
        NotificationCenter.default.addObserver(self, selector: #selector(onKBUpdated), name: .kbLiteDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onUserDidLogin), name: .djUserDidLogin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onUserDidLogout), name: .djUserDidLogout, object: nil)
        // 延迟首次同步（等知识库加载完成）
        let startupOwnerUserId = activeOwnerUserId
        let startupAccountLease = captureAccountLease(for: startupOwnerUserId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self,
                  let startupAccountLease,
                  self.isCurrentAccountLease(
                      startupAccountLease,
                      ownerUserId: startupOwnerUserId,
                      at: .timer
                  ) else {
                return
            }
            self.syncFromKnowledgeBase(accountLease: startupAccountLease)
            self.bootstrapCurrentUserFromBackend(accountLease: startupAccountLease)
        }
    }

    @objc private func onKBUpdated() {
        let ownerUserId = activeOwnerUserId
        guard let accountLease = captureAccountLease(for: ownerUserId) else { return }
        syncFromKnowledgeBase(accountLease: accountLease)
    }

    @objc private func onUserDidLogin() {
        let userId = UserManager.shared.currentUser?.id
        let ownerUserId = Self.normalizedUserId(userId)
        let accountLease = captureAccountLease(for: ownerUserId)
        activateUser(userId, accountLease: accountLease)
        guard let accountLease else { return }
        bootstrapCurrentUserFromBackend(accountLease: accountLease)
    }

    @objc private func onUserDidLogout() {
        activateUser(nil, accountLease: nil)
    }

    private var members: [FamilyMember] = []
    private(set) var knowledgeCandidates: [FamilyRelationshipCandidate] = []
    private var activeOwnerUserId: String
    private var userGeneration = UUID()
    private var authorizationFreshness = FamilyAuthorizationFreshness()
    private var modeOverrides: [String: DigitalHumanMode] = [:]
    private var voiceProfileOverrides: [String: VoiceProfileOverride] = [:]
    private let modeOverridesBaseKey = "dj.family.digitalHumanModeOverrides"
    private let voiceProfileOverridesBaseKey = "dj.family.voiceProfileOverrides"

    private struct VoiceProfileOverride: Codable {
        var voiceProfileId: String
        var voiceSampleStatus: String
        var voiceEnabled: Bool
    }

    func getAll() -> [FamilyMember] { members }

    func acceptedMembers() -> [FamilyMember] {
        guard authorizationFreshness.allowsPreviouslyVerifiedUse else { return [] }
        return members.filter {
            $0.isAcceptedFamilyMember(for: activeOwnerUserId, allowQAFixtures: Self.isUIQARuntime)
        }
    }

    func acceptedMembers(for ownerUserId: String) -> [FamilyMember] {
        let normalizedOwner = Self.normalizedUserId(ownerUserId)
        guard !normalizedOwner.isEmpty, normalizedOwner == activeOwnerUserId else { return [] }
        return acceptedMembers()
    }

    func acceptedMembersForKnowledgeSync(ownerUserId: String) -> [FamilyMember] {
        let normalizedOwner = Self.normalizedUserId(ownerUserId)
        guard authorizationFreshness.allowsKnowledgeSyncSnapshot,
              !normalizedOwner.isEmpty,
              normalizedOwner == activeOwnerUserId else {
            return []
        }
        return members.filter {
            $0.isAcceptedFamilyMember(for: normalizedOwner, allowQAFixtures: Self.isUIQARuntime)
        }
    }

    func authorizationGeneration(for ownerUserId: String) -> UUID? {
        let normalizedOwner = Self.normalizedUserId(ownerUserId)
        guard authorizationFreshness.allowsPreviouslyVerifiedUse,
              !normalizedOwner.isEmpty,
              normalizedOwner == activeOwnerUserId else {
            return nil
        }
        return authorizationFreshness.generation
    }

    var hasStarModeMember: Bool {
        acceptedMembers().contains { $0.digitalHumanMode == .star }
    }

    func add(_ member: FamilyMember) {
        guard Self.isUIQARuntime,
              member.relationshipOwnerUserId == activeOwnerUserId,
              member.relationshipAuthoritySource == .qaFixture || member.relationshipAuthoritySource == .backendInvitation,
              let accountLease = captureAccountLease(for: activeOwnerUserId),
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: activeOwnerUserId,
                  at: .commit
              ) else {
            return
        }
        let previousAuthorization = rawAcceptedAuthorizationKeys(ownerUserId: activeOwnerUserId)
        if !authorizationFreshness.allowsPreviouslyVerifiedUse {
            authorizationFreshness.completeSuccess()
        }
        guard upsert(
            member,
            expectedGeneration: userGeneration,
            accountLease: accountLease
        ) else {
            return
        }
        let currentAuthorization = rawAcceptedAuthorizationKeys(ownerUserId: activeOwnerUserId)
        if previousAuthorization != currentAuthorization {
            authorizationFreshness.completeSuccess()
        }
        KBLiteManager.shared.familyAuthorizationGenerationDidChange(
            ownerUserId: activeOwnerUserId,
            generation: authorizationFreshness.generation
        )
        KnowledgeSyncCoordinator.shared.familyAuthorizationDidRefresh(
            ownerUserId: activeOwnerUserId,
            authorizationChanged: previousAuthorization != currentAuthorization
        )
        if previousAuthorization != currentAuthorization {
            DigitalHumanContextStore.shared.reconcileFamilyAuthorization()
        }
    }

    func remove(id: String) {
        // PRD: 家庭成员通过手机号邀请后不可删除；退出/解除关系未明确，暂不实现。
    }

    func get(by id: String) -> FamilyMember? {
        return members.first { $0.id == id }
    }

    func acceptedMember(by id: String) -> FamilyMember? {
        guard authorizationFreshness.allowsPreviouslyVerifiedUse else { return nil }
        return members.first {
            $0.id == id && $0.isAcceptedFamilyMember(
                for: activeOwnerUserId,
                allowQAFixtures: Self.isUIQARuntime
            )
        }
    }

    func bootstrapCurrentUserFromBackend(
        completion: ((Result<[FamilyMember], Error>) -> Void)? = nil
    ) {
        let ownerUserId = activeOwnerUserId
        guard !ownerUserId.isEmpty else {
            completion?(.failure(FamilyRepositoryError.noActiveOwner))
            return
        }
        guard let accountLease = captureAccountLease(for: ownerUserId),
              isCurrentAccountLease(accountLease, ownerUserId: ownerUserId, at: .request) else {
            completion?(.failure(FamilyRepositoryError.staleResponse))
            return
        }
        bootstrapCurrentUserFromBackend(accountLease: accountLease, completion: completion)
    }

    private func bootstrapCurrentUserFromBackend(
        accountLease: AccountLease,
        completion: ((Result<[FamilyMember], Error>) -> Void)? = nil
    ) {
        let ownerUserId = activeOwnerUserId
        guard !ownerUserId.isEmpty,
              isCurrentAccountLease(accountLease, ownerUserId: ownerUserId, at: .request) else {
            return
        }
        refreshFromBackend(
            userId: ownerUserId,
            accountLease: accountLease,
            completion: completion
        )
    }

    func updateMode(memberId: String, mode: DigitalHumanMode) {
        guard let accountLease = captureAccountLease(for: activeOwnerUserId),
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: activeOwnerUserId,
                  at: .commit
              ),
              let index = members.firstIndex(where: { $0.id == memberId }),
              members[index].isAcceptedFamilyMember(
                  for: activeOwnerUserId,
                  allowQAFixtures: Self.isUIQARuntime
              ) else { return }
        members[index].digitalHumanMode = mode
        modeOverrides[memberId] = mode
        persistModeOverrides(accountLease: accountLease)
        notifyMembersChanged(accountLease: accountLease)
    }

    func updateVoiceProfile(memberId: String, voiceProfileId: String?, sampleStatus: String, voiceEnabled: Bool) {
        guard let accountLease = captureAccountLease(for: activeOwnerUserId),
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: activeOwnerUserId,
                  at: .commit
              ),
              let index = members.firstIndex(where: { $0.id == memberId }),
              members[index].isAcceptedFamilyMember(
                  for: activeOwnerUserId,
                  allowQAFixtures: Self.isUIQARuntime
              ) else { return }
        let trimmedProfileId = voiceProfileId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        members[index].voiceProfileId = trimmedProfileId.isEmpty ? nil : trimmedProfileId
        members[index].voiceSampleStatus = sampleStatus
        members[index].voiceEnabled = voiceEnabled

        if trimmedProfileId.isEmpty {
            voiceProfileOverrides.removeValue(forKey: memberId)
        } else {
            voiceProfileOverrides[memberId] = VoiceProfileOverride(
                voiceProfileId: trimmedProfileId,
                voiceSampleStatus: sampleStatus,
                voiceEnabled: voiceEnabled
            )
        }
        persistVoiceProfileOverrides(accountLease: accountLease)
        notifyMembersChanged(accountLease: accountLease)
    }

    func refreshFromBackend(userId: String, completion: ((Result<[FamilyMember], Error>) -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.refreshFromBackend(userId: userId, completion: completion)
            }
            return
        }
        let requestedOwner = Self.normalizedUserId(userId)
        guard !requestedOwner.isEmpty else {
            completion?(.failure(FamilyRepositoryError.noActiveOwner))
            return
        }
        guard requestedOwner == activeOwnerUserId else {
            completion?(.failure(FamilyRepositoryError.ownerMismatch))
            return
        }
        guard let accountLease = captureAccountLease(for: requestedOwner),
              isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .request) else {
            completion?(.failure(FamilyRepositoryError.staleResponse))
            return
        }
        refreshFromBackend(
            userId: userId,
            accountLease: accountLease,
            completion: completion
        )
    }

    private func refreshFromBackend(
        userId: String,
        accountLease: AccountLease,
        completion: ((Result<[FamilyMember], Error>) -> Void)? = nil
    ) {
        let requestedOwner = Self.normalizedUserId(userId)
        guard !requestedOwner.isEmpty,
              requestedOwner == activeOwnerUserId,
              isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .request) else {
            completion?(.failure(FamilyRepositoryError.staleResponse))
            return
        }
        guard isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .commit) else {
            return
        }
        authorizationFreshness.beginRefresh()
        KBLiteManager.shared.familyAuthorizationGenerationDidChange(
            ownerUserId: requestedOwner,
            generation: authorizationFreshness.generation
        )
        KnowledgeSyncCoordinator.shared.familyAuthorizationRefreshStarted(ownerUserId: requestedOwner)
        let capturedGeneration = userGeneration
        let capturedRefreshGeneration = authorizationFreshness.generation
        DreamJourneyBackendClient.shared.fetchFamilyMembers(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentAccountLease(
                    accountLease,
                    ownerUserId: requestedOwner,
                    at: .commit
                ) else {
                    return
                }
                guard FamilyAuthorizationRefreshResponsePolicy.accepts(
                          capturedOwnerUserId: requestedOwner,
                          currentOwnerUserId: self.activeOwnerUserId,
                          capturedUserGeneration: capturedGeneration,
                          currentUserGeneration: self.userGeneration,
                          capturedRefreshGeneration: capturedRefreshGeneration,
                          currentRefreshGeneration: self.authorizationFreshness.generation
                      ) else {
                    self.deliver(
                        .failure(FamilyRepositoryError.staleResponse),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                    return
                }
                switch result {
                case .success(let remoteMembers):
                    guard self.replaceRemoteMembers(
                        remoteMembers,
                        ownerUserId: requestedOwner,
                        accountLease: accountLease
                    ) else {
                        self.invalidateAuthorization(
                            ownerUserId: requestedOwner,
                            accountLease: accountLease
                        )
                        self.deliver(
                            .failure(FamilyRepositoryError.invalidBackendRecord),
                            accountLease: accountLease,
                            ownerUserId: requestedOwner,
                            completion: completion
                        )
                        return
                    }
                    self.deliver(
                        .success(self.members),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                case .failure(let error):
                    self.invalidateAuthorization(
                        ownerUserId: requestedOwner,
                        accountLease: accountLease
                    )
                    self.deliver(
                        .failure(error),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                }
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
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.inviteByPhone(
                    userId: userId,
                    phone: phone,
                    name: name,
                    relation: relation,
                    completion: completion
                )
            }
            return
        }
        let requestedOwner = Self.normalizedUserId(userId)
        guard !requestedOwner.isEmpty else {
            completion(.failure(FamilyRepositoryError.noActiveOwner))
            return
        }
        guard requestedOwner == activeOwnerUserId else {
            completion(.failure(FamilyRepositoryError.ownerMismatch))
            return
        }
        guard let accountLease = captureAccountLease(for: requestedOwner),
              isCurrentAccountLease(accountLease, ownerUserId: requestedOwner, at: .request) else {
            completion(.failure(FamilyRepositoryError.staleResponse))
            return
        }
        let capturedGeneration = userGeneration
        DreamJourneyBackendClient.shared.inviteFamilyMember(
            userId: userId,
            name: name,
            relation: relation,
            phone: phone
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentAccountLease(
                    accountLease,
                    ownerUserId: requestedOwner,
                    at: .commit
                ) else {
                    return
                }
                guard self.userGeneration == capturedGeneration,
                      self.activeOwnerUserId == requestedOwner else {
                    self.deliver(
                        .failure(FamilyRepositoryError.staleResponse),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                    return
                }
                switch result {
                case .success(let member):
                    guard self.isOwnedBackendRecord(member, ownerUserId: requestedOwner) else {
                        self.deliver(
                            .failure(FamilyRepositoryError.invalidBackendRecord),
                            accountLease: accountLease,
                            ownerUserId: requestedOwner,
                            completion: completion
                        )
                        return
                    }
                    guard self.upsert(
                        member,
                        expectedGeneration: capturedGeneration,
                        accountLease: accountLease
                    ) else {
                        return
                    }
                    self.deliver(
                        .success(member),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                case .failure(let error):
                    let failedMember = FamilyMember(
                        id: "family_invite_failed_\(UUID().uuidString)",
                        name: name,
                        relation: relation,
                        phone: phone,
                        isOnline: false,
                        lastUpdated: "邀请失败",
                        relationshipOwnerUserId: requestedOwner,
                        relationshipAuthoritySource: .localInvitationAttempt,
                        accessStatus: "failed",
                        invitationStatus: "failed",
                        invitationError: error.localizedDescription
                    )
                    guard self.upsert(
                        failedMember,
                        expectedGeneration: capturedGeneration,
                        accountLease: accountLease
                    ) else {
                        return
                    }
                    self.deliver(
                        .failure(error),
                        accountLease: accountLease,
                        ownerUserId: requestedOwner,
                        completion: completion
                    )
                }
            }
        }
    }

    // MARK: - KBLite 候选：知识人物不能自动提升为家庭关系

    /// 供外部按需调用的公开同步方法
    func refreshFromKnowledgeBase() {
        let ownerUserId = activeOwnerUserId
        guard let accountLease = captureAccountLease(for: ownerUserId) else { return }
        syncFromKnowledgeBase(accountLease: accountLease)
    }

    /// 将知识库人物投影为本地关系候选，不进入已授权家庭成员列表。
    private func syncFromKnowledgeBase(accountLease: AccountLease) {
        let ownerUserId = activeOwnerUserId
        guard !ownerUserId.isEmpty,
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: ownerUserId,
                  at: .commit
              ) else {
            return
        }
        let graph = KBLiteManager.shared.graph
        guard !graph.people.isEmpty else {
            knowledgeCandidates = []
            notifyCandidatesChanged(accountLease: accountLease)
            return
        }

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

        let authorizedNames = Set(
            members.flatMap { [$0.name] }.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )
        knowledgeCandidates = graph.people.compactMap { person in
            let normalizedName = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty,
                  !authorizedNames.contains(normalizedName.lowercased()) else {
                return nil
            }

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

            return FamilyRelationshipCandidate(
                id: "kb-candidate:\(person.id)",
                ownerUserId: ownerUserId,
                personId: person.id,
                name: normalizedName,
                aliases: person.aliases,
                relation: relation,
                evidenceStatus: person.evidenceStatus ?? "legacyUnverified"
            )
        }
        print("[FamilyRepo] 已从知识库更新 \(knowledgeCandidates.count) 个家庭关系候选；未授予家庭权限")
        notifyCandidatesChanged(accountLease: accountLease)
    }

    private func applyLocalOverrides(to member: FamilyMember) -> FamilyMember {
        var updated = member
        if let mode = modeOverrides[member.id] {
            updated.digitalHumanMode = mode
        }
        if let voiceOverride = voiceProfileOverrides[member.id] {
            updated.voiceProfileId = voiceOverride.voiceProfileId
            updated.voiceSampleStatus = voiceOverride.voiceSampleStatus
            updated.voiceEnabled = voiceOverride.voiceEnabled
        }
        return updated
    }

    @discardableResult
    private func replaceRemoteMembers(
        _ remoteMembers: [FamilyMember],
        ownerUserId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard ownerUserId == activeOwnerUserId,
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: ownerUserId,
                  at: .commit
              ) else {
            return false
        }
        let validated = remoteMembers.filter { isOwnedBackendRecord($0, ownerUserId: ownerUserId) }
        guard validated.count == remoteMembers.count else { return false }
        let previousAuthorization = rawAcceptedAuthorizationKeys(ownerUserId: ownerUserId)
        members = validated.map(applyLocalOverrides(to:))
        authorizationFreshness.completeSuccess()
        KBLiteManager.shared.familyAuthorizationGenerationDidChange(
            ownerUserId: ownerUserId,
            generation: authorizationFreshness.generation
        )
        let currentAuthorization = rawAcceptedAuthorizationKeys(ownerUserId: ownerUserId)
        notifyMembersChanged(accountLease: accountLease)
        syncFromKnowledgeBase(accountLease: accountLease)
        let authorizationChanged = previousAuthorization != currentAuthorization
        KnowledgeSyncCoordinator.shared.familyAuthorizationDidRefresh(
            ownerUserId: ownerUserId,
            authorizationChanged: authorizationChanged
        )
        if authorizationChanged {
            DigitalHumanContextStore.shared.reconcileFamilyAuthorization()
        }
        return true
    }

    private func rawAcceptedAuthorizationKeys(ownerUserId: String) -> Set<String> {
        let now = Date()
        return Set(members.compactMap { member in
            guard member.isAcceptedFamilyMember(
                for: ownerUserId,
                allowQAFixtures: Self.isUIQARuntime,
                now: now
            ) else {
                return nil
            }
            let digitalHumanId = member.digitalHumanId
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedDigitalHumanId = digitalHumanId.isEmpty ? member.id : digitalHumanId
            let grantFingerprint = member.activeFamilyPersonaReadGrants(at: now)
                .sorted { $0.id < $1.id }
                .map { grant in
                    let expiresAt = grant.expiresAt?.timeIntervalSince1970.description ?? "none"
                    return "\(grant.id):\(grant.rowVersion):\(expiresAt)"
                }
                .joined(separator: ",")
            let effectiveGrantFingerprint = grantFingerprint.isEmpty ? "qa-fixture" : grantFingerprint
            return [
                member.id,
                resolvedDigitalHumanId,
                member.relationshipId,
                "relationshipEpoch=\(member.relationshipEpoch)",
                "grantEpoch=\(member.grantEpoch)",
                effectiveGrantFingerprint,
            ].joined(separator: "|")
        })
    }

    private func invalidateAuthorization(
        ownerUserId: String,
        accountLease: AccountLease
    ) {
        guard ownerUserId == activeOwnerUserId,
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: ownerUserId,
                  at: .commit
              ) else {
            return
        }
        authorizationFreshness.completeFailure()
        KBLiteManager.shared.familyAuthorizationGenerationDidChange(
            ownerUserId: ownerUserId,
            generation: nil
        )
        KnowledgeSyncCoordinator.shared.familyAuthorizationRefreshFailed(ownerUserId: ownerUserId)
        DigitalHumanContextStore.shared.reconcileFamilyAuthorization()
    }

    private func isOwnedBackendRecord(_ member: FamilyMember, ownerUserId: String) -> Bool {
        member.relationshipAuthoritySource == .backendInvitation
            && !ownerUserId.isEmpty
            && member.relationshipOwnerUserId == ownerUserId
    }

    @discardableResult
    private func upsert(
        _ member: FamilyMember,
        expectedGeneration: UUID,
        accountLease: AccountLease
    ) -> Bool {
        guard isCurrentAccountLease(
                  accountLease,
                  ownerUserId: member.relationshipOwnerUserId,
                  at: .commit
              ),
              userGeneration == expectedGeneration,
              !activeOwnerUserId.isEmpty,
              member.relationshipOwnerUserId == activeOwnerUserId else {
            return false
        }
        let updatedMember = applyLocalOverrides(to: member)
        if let index = members.firstIndex(where: { $0.id == updatedMember.id }) {
            members[index] = updatedMember
        } else if let phone = updatedMember.phone,
                  let index = members.firstIndex(where: { $0.phone == phone && !$0.isAcceptedFamilyRelationship }) {
            members[index] = updatedMember
        } else {
            members.append(updatedMember)
        }
        notifyMembersChanged(accountLease: accountLease)
        return true
    }

    private func activateUser(_ userId: String?, accountLease: AccountLease?) {
        let normalizedOwner = Self.normalizedUserId(userId)
        guard normalizedOwner != activeOwnerUserId else { return }
        activeOwnerUserId = normalizedOwner
        userGeneration = UUID()
        authorizationFreshness.reset()
        KBLiteManager.shared.familyAuthorizationGenerationDidChange(
            ownerUserId: normalizedOwner,
            generation: nil
        )
        members = []
        knowledgeCandidates = []
        modeOverrides = [:]
        voiceProfileOverrides = [:]
        loadModeOverrides()
        loadVoiceProfileOverrides()
        guard let accountLease,
              isCurrentAccountLease(
                  accountLease,
                  ownerUserId: normalizedOwner,
                  at: .commit
              ) else {
            return
        }
        notifyMembersChanged(accountLease: accountLease)
        notifyCandidatesChanged(accountLease: accountLease)
        syncFromKnowledgeBase(accountLease: accountLease)
    }

    private func loadModeOverrides() {
        guard let key = ownerScopedKey(
            base: modeOverridesBaseKey,
            ownerUserId: activeOwnerUserId
        ),
              let rawValues = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            modeOverrides = [:]
            return
        }
        modeOverrides = rawValues.reduce(into: [:]) { result, pair in
            if let mode = DigitalHumanMode(rawValue: pair.value) {
                result[pair.key] = mode
            }
        }
    }

    private func persistModeOverrides(accountLease: AccountLease) {
        guard isCurrentAccountLease(
                  accountLease,
                  ownerUserId: accountLease.subjectId,
                  at: .commit
              ),
              let key = ownerScopedKey(
                  base: modeOverridesBaseKey,
                  ownerUserId: accountLease.subjectId
              ) else {
            return
        }
        let rawValues = modeOverrides.mapValues(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: key)
    }

    private func loadVoiceProfileOverrides() {
        guard let key = ownerScopedKey(
            base: voiceProfileOverridesBaseKey,
            ownerUserId: activeOwnerUserId
        ),
              let data = UserDefaults.standard.data(forKey: key),
              let overrides = try? JSONDecoder().decode([String: VoiceProfileOverride].self, from: data) else {
            voiceProfileOverrides = [:]
            return
        }
        voiceProfileOverrides = overrides
    }

    private func persistVoiceProfileOverrides(accountLease: AccountLease) {
        guard isCurrentAccountLease(
                  accountLease,
                  ownerUserId: accountLease.subjectId,
                  at: .commit
              ),
              let key = ownerScopedKey(
                  base: voiceProfileOverridesBaseKey,
                  ownerUserId: accountLease.subjectId
              ) else {
            return
        }
        guard let data = try? JSONEncoder().encode(voiceProfileOverrides) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func ownerScopedKey(base: String, ownerUserId: String) -> String? {
        guard !ownerUserId.isEmpty else { return nil }
        return "\(base).\(ownerUserId)"
    }

    private func captureAccountLease(for ownerUserId: String) -> AccountLease? {
        guard !ownerUserId.isEmpty else { return nil }
        return accountLeaseRuntime.capture(forSubjectId: ownerUserId)
    }

    private func isCurrentAccountLease(
        _ accountLease: AccountLease,
        ownerUserId: String,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        guard !ownerUserId.isEmpty,
              ownerUserId == activeOwnerUserId,
              accountLease.subjectId == ownerUserId else {
            return false
        }
        return accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func deliver<T>(
        _ result: Result<T, Error>,
        accountLease: AccountLease,
        ownerUserId: String,
        completion: ((Result<T, Error>) -> Void)?
    ) {
        guard let completion,
              isCurrentAccountLease(accountLease, ownerUserId: ownerUserId, at: .ui) else {
            return
        }
        completion(result)
    }

    private func notifyMembersChanged(accountLease: AccountLease) {
        let ownerUserId = accountLease.subjectId
        let snapshot = members
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.isCurrentAccountLease(
                      accountLease,
                      ownerUserId: ownerUserId,
                      at: .ui
                  ) else {
                return
            }
            NotificationCenter.default.post(name: .djFamilyMembersDidChange, object: snapshot)
        }
    }

    private func notifyCandidatesChanged(accountLease: AccountLease) {
        let ownerUserId = accountLease.subjectId
        let snapshot = knowledgeCandidates
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.isCurrentAccountLease(
                      accountLease,
                      ownerUserId: ownerUserId,
                      at: .ui
                  ) else {
                return
            }
            NotificationCenter.default.post(
                name: .djFamilyRelationshipCandidatesDidChange,
                object: snapshot
            )
        }
    }

    private static func normalizedUserId(_ userId: String?) -> String {
        userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static var isUIQARuntime: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

extension Notification.Name {
    static let djFamilyMembersDidChange = Notification.Name("dj.family.membersDidChange")
    static let djFamilyRelationshipCandidatesDidChange = Notification.Name("dj.family.relationshipCandidatesDidChange")
}
