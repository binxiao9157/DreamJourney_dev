import Foundation

enum UserProfileSaveResult {
    case saved
    case savedWithRemoteWarning(String)
    case failed(String)
}

// MARK: - UserManager 单例：管理登录态
final class UserManager {

    private enum PrivateAccessState {
        case signedOut
        case validating
        case authenticated
        case suspended
    }

    static let shared = UserManager()
    private init() {
        loadFromDefaults()
    }

    private let accountStateLock = NSRecursiveLock()
    private let kUserKey = "dj_current_user"
    private let kLoggedInKey = "dj_is_logged_in"
    private var lifecycleTransitionOwnerUserId: String?

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    private var syntheticPrivateUserId: String?
    #endif

    private var storedCurrentUser: UserModel?
    private var privateAccessState: PrivateAccessState = .signedOut
    var currentUser: UserModel? {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        return storedCurrentUser
    }
    var isLoggedIn: Bool { canEnterPrivateUI }

    var canEnterPrivateUI: Bool {
        accountStateLock.lock()
        let user = storedCurrentUser
        let state = privateAccessState
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        let syntheticUserId = syntheticPrivateUserId
        #endif
        accountStateLock.unlock()
        guard let user else { return false }
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if syntheticUserId == user.id {
            return true
        }
        #endif
        guard state == .authenticated else { return false }
        if let session = BackendAuthSessionStore.shared.currentSession,
           session.isPrivateAccessEligible(for: user.id) {
            return true
        }
        return false
    }

    var requiresPrivateAccessValidation: Bool {
        accountStateLock.lock()
        let state = privateAccessState
        accountStateLock.unlock()
        guard state == .validating else { return false }
        return BackendAuthSessionStore.shared.currentSession?.isPrivateAccessEligible == true
    }

    func accountSessionCredentialSnapshot() -> AccountSessionCredentialSnapshot? {
        accountStateLock.lock()
        let user = storedCurrentUser
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        let syntheticUserId = syntheticPrivateUserId
        #endif
        accountStateLock.unlock()

        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if let user, syntheticUserId == user.id {
            return AccountSessionCredentialSnapshot(
                subjectId: user.id,
                vaultId: user.id,
                sessionId: "uiqa-session-\(user.id)",
                tokenFamilyId: "uiqa-family-\(user.id)",
                sessionVersion: 1,
                isPrivateAccessEligible: true,
                trust: .prevalidatedTestOnly
            )
        }
        #endif

        guard let session = BackendAuthSessionStore.shared.currentSession,
              let tokenFamilyId = session.tokenFamilyId,
              let sessionVersion = session.sessionVersion else {
            return nil
        }
        return AccountSessionCredentialSnapshot(
            subjectId: session.userId,
            vaultId: session.userId,
            sessionId: session.sessionId,
            tokenFamilyId: tokenFamilyId,
            sessionVersion: sessionVersion,
            isPrivateAccessEligible: session.isPrivateAccessEligible,
            trust: .requiresOnlineValidation
        )
    }

    // MARK: - 登录
    @discardableResult
    func loginVerifiedAccount(phone: String, nickname: String, userId: String) -> Bool {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session = BackendAuthSessionStore.shared.currentSession,
              session.isPrivateAccessEligible(for: normalizedUserId) else {
            return false
        }
        activateUser(phone: phone, nickname: nickname, userId: normalizedUserId)
        return true
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    func login(phone: String, nickname: String, id: String? = nil) {
        let normalizedUserId = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = normalizedUserId?.isEmpty == false
            ? normalizedUserId!
            : "uiqa_\(phone.suffix(4))"
        syntheticPrivateUserId = userId
        activateUser(phone: phone, nickname: nickname, userId: userId)
    }
    #endif

    @discardableResult
    func reconcilePrivateAccessSession() -> Bool {
        let capturedUser = currentUser
        let capturedSession = BackendAuthSessionStore.shared.currentSession
        guard let session = capturedSession,
              session.isPrivateAccessEligible else {
            BackendAuthSessionStore.shared.clear()
            accountStateLock.lock()
            privateAccessState = .signedOut
            if storedCurrentUser?.id == capturedUser?.id {
                storedCurrentUser = nil
                UserDefaults.standard.removeObject(forKey: kUserKey)
                UserDefaults.standard.removeObject(forKey: kLoggedInKey)
            }
            accountStateLock.unlock()
            return false
        }
        accountStateLock.lock()
        if capturedUser?.id != session.userId {
            storedCurrentUser = nil
            UserDefaults.standard.removeObject(forKey: kUserKey)
            UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        }
        privateAccessState = .validating
        accountStateLock.unlock()
        return true
    }

    @discardableResult
    func prepareCachedProfileForValidatedSession(_ session: BackendAuthSessionContract) -> Bool {
        guard session.isPrivateAccessEligible else { return false }
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        if storedCurrentUser?.id != session.userId {
            storedCurrentUser = UserModel(
                id: session.userId,
                nickname: "寻梦环游用户",
                phone: "",
                avatarName: "person.circle.fill"
            )
        }
        privateAccessState = .validating
        guard let user = storedCurrentUser else { return false }
        return saveToDefaultsLocked(user: user)
    }

    @discardableResult
    func markPrivateAccessValidated(session: BackendAuthSessionContract) -> Bool {
        accountStateLock.lock()
        let userId = storedCurrentUser?.id
        accountStateLock.unlock()
        guard let userId,
              session.isPrivateAccessEligible(for: userId),
              BackendAuthSessionStore.shared.currentSession?.matchesCASIdentity(session) == true else {
            accountStateLock.lock()
            privateAccessState = .suspended
            accountStateLock.unlock()
            return false
        }
        accountStateLock.lock()
        guard storedCurrentUser?.id == userId else {
            accountStateLock.unlock()
            return false
        }
        privateAccessState = .authenticated
        accountStateLock.unlock()
        EchoTraceAccountLifecycle.activate(ownerUserId: userId)
        KnowledgeSyncCoordinator.shared.userDidChange(to: userId)
        KBLiteManager.shared.switchUser(to: userId)
        KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "privateAccessValidated")
        return true
    }

    func suspendPrivateAccess(for userId: String, reason: String, notify: Bool = true) {
        accountStateLock.lock()
        guard storedCurrentUser?.id == userId else {
            accountStateLock.unlock()
            return
        }
        let stateChanged = privateAccessState != .suspended
        privateAccessState = .suspended
        accountStateLock.unlock()

        guard notify && stateChanged else { return }
        let oldAccountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId)
        accountStateLock.lock()
        guard lifecycleTransitionOwnerUserId == nil else {
            accountStateLock.unlock()
            return
        }
        lifecycleTransitionOwnerUserId = userId
        accountStateLock.unlock()

        Task {
            let actorSnapshot = await AccountSessionActor.shared.snapshot()
            let resolvedOldAccountLease = oldAccountLease
                ?? self.lifecycleAccountLease(from: actorSnapshot.session)
            let oldGeneration = resolvedOldAccountLease?.generation ?? actorSnapshot.generation
            let result = await AccountLifecycleTransitionController.shared.perform(
                event: .privateSuspension,
                oldAccountLease: resolvedOldAccountLease,
                oldGeneration: oldGeneration,
                reason: reason
            )
            await MainActor.run {
                self.finalizePrivateSuspension(
                    expectedOwnerUserId: userId,
                    reason: reason,
                    lifecycleResult: result
                )
            }
        }
    }

    private func activateUser(phone: String, nickname: String, userId: String) {
        let user = UserModel(
            id: userId,
            nickname: nickname.isEmpty ? "寻梦环游用户" : nickname,
            phone: phone,
            avatarName: "person.circle.fill"
        )
        accountStateLock.lock()
        let previousOwnerUserId = storedCurrentUser?.id
        storedCurrentUser = user
        privateAccessState = .authenticated
        EchoTraceAccountLifecycle.switchOwner(from: previousOwnerUserId, to: user.id)
        _ = saveToDefaultsLocked(user: user)
        KnowledgeSyncCoordinator.shared.userDidChange(to: user.id)
        KBLiteManager.shared.switchUser(to: user.id)
        KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "loginCompleted")
        NotificationCenter.default.post(name: .djUserDidLogin, object: nil)
        accountStateLock.unlock()
    }

    func updateProfile(nickname: String) {
        _ = updateProfileLocally(nickname: nickname)
    }

    func saveProfile(nickname: String, completion: @escaping (UserProfileSaveResult) -> Void) {
        accountStateLock.lock()
        guard let user = storedCurrentUser else {
            accountStateLock.unlock()
            completion(.failed("请先登录后再保存"))
            return
        }
        let expectedUserId = user.id
        let gender = user.gender
        let region = user.region
        let avatarName = user.avatarName
        accountStateLock.unlock()
        saveProfile(
            nickname: nickname,
            gender: gender,
            region: region,
            avatarName: avatarName,
            expectedUserId: expectedUserId,
            completion: completion
        )
    }

    func saveProfile(nickname: String, gender: String?, region: String?, avatarName: String? = nil, completion: @escaping (UserProfileSaveResult) -> Void) {
        saveProfile(
            nickname: nickname,
            gender: gender,
            region: region,
            avatarName: avatarName,
            expectedUserId: nil,
            completion: completion
        )
    }

    private func saveProfile(
        nickname: String,
        gender: String?,
        region: String?,
        avatarName: String?,
        expectedUserId: String?,
        completion: @escaping (UserProfileSaveResult) -> Void
    ) {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            completion(.failed("昵称不能为空"))
            return
        }

        accountStateLock.lock()
        guard var user = storedCurrentUser else {
            accountStateLock.unlock()
            completion(.failed("请先登录后再保存"))
            return
        }
        guard expectedUserId == nil || expectedUserId == user.id else {
            accountStateLock.unlock()
            completion(.failed("账号已切换，请重新保存"))
            return
        }
        user.nickname = trimmedNickname
        user.gender = normalizedProfileField(gender)
        user.region = normalizedProfileField(region)
        if avatarName != nil {
            user.avatarName = normalizedProfileField(avatarName)
        }
        storedCurrentUser = user
        guard saveToDefaultsLocked(user: user) else {
            accountStateLock.unlock()
            completion(.failed("本地保存失败，请稍后再试"))
            return
        }
        NotificationCenter.default.post(name: .djUserDidUpdate, object: nil)
        accountStateLock.unlock()

        guard DreamJourneyBackendClient.shared.isProfileSyncConfigured else {
            completion(.saved)
            return
        }

        DreamJourneyBackendClient.shared.updateProfile(
            userId: user.id,
            nickname: trimmedNickname,
            gender: user.gender,
            region: user.region,
            avatarName: user.avatarName
        ) { result in
            switch result {
            case .success:
                completion(.saved)
            case .failure(let error):
                completion(.savedWithRemoteWarning(error.localizedDescription))
            }
        }
    }

    private func normalizedProfileField(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func updateProfileLocally(nickname: String) -> Bool {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        guard var user = storedCurrentUser else { return false }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        user.nickname = trimmedNickname.isEmpty ? "寻梦环游用户" : trimmedNickname
        storedCurrentUser = user
        guard saveToDefaultsLocked(user: user) else { return false }
        NotificationCenter.default.post(name: .djUserDidUpdate, object: nil)
        return true
    }

    // MARK: - 退出登录
    func logout() {
        accountStateLock.lock()
        let ownerUserId = storedCurrentUser?.id
            ?? BackendAuthSessionStore.shared.currentSession?.userId
        guard lifecycleTransitionOwnerUserId == nil else {
            accountStateLock.unlock()
            return
        }
        guard ownerUserId != nil else {
            accountStateLock.unlock()
            DreamJourneyBackendClient.shared.logoutAuthSession()
            return
        }
        lifecycleTransitionOwnerUserId = ownerUserId
        accountStateLock.unlock()

        let oldAccountLease = AccountLeaseRuntime.shared.capture(forSubjectId: ownerUserId)
        DreamJourneyBackendClient.shared.logoutAuthSession()
        Task {
            let actorSnapshot = await AccountSessionActor.shared.snapshot()
            let resolvedOldAccountLease = oldAccountLease
                ?? self.lifecycleAccountLease(from: actorSnapshot.session)
            let oldGeneration = resolvedOldAccountLease?.generation ?? actorSnapshot.generation
            let result = await AccountLifecycleTransitionController.shared.perform(
                event: .logout,
                oldAccountLease: resolvedOldAccountLease,
                oldGeneration: oldGeneration,
                reason: "userLoggedOut"
            )
            _ = await MainActor.run {
                self.finalizeLogout(
                    expectedOwnerUserId: ownerUserId,
                    lifecycleResult: result
                )
            }
        }
    }

    func invalidateBackendSession(for userId: String) {
        accountStateLock.lock()
        let isCurrentOwner = storedCurrentUser?.id == userId
        accountStateLock.unlock()
        guard isCurrentOwner else { return }
        logout()
    }

    func switchAccount(completion: @escaping (Bool) -> Void) {
        accountStateLock.lock()
        let ownerUserId = storedCurrentUser?.id
        guard ownerUserId != nil, lifecycleTransitionOwnerUserId == nil else {
            accountStateLock.unlock()
            completion(false)
            return
        }
        lifecycleTransitionOwnerUserId = ownerUserId
        accountStateLock.unlock()

        let oldAccountLease = AccountLeaseRuntime.shared.capture(forSubjectId: ownerUserId)
        DreamJourneyBackendClient.shared.logoutAuthSession()
        Task {
            let actorSnapshot = await AccountSessionActor.shared.snapshot()
            let resolvedOldAccountLease = oldAccountLease
                ?? self.lifecycleAccountLease(from: actorSnapshot.session)
            let oldGeneration = resolvedOldAccountLease?.generation ?? actorSnapshot.generation
            let result = await AccountLifecycleTransitionController.shared.perform(
                event: .switchAccount,
                oldAccountLease: resolvedOldAccountLease,
                oldGeneration: oldGeneration,
                reason: "accountSwitchRequested"
            )
            await MainActor.run {
                let finalized = self.finalizeLogout(
                    expectedOwnerUserId: ownerUserId,
                    lifecycleResult: result
                )
                completion(finalized)
            }
        }
    }

    @discardableResult
    func completeAccountDeletion(
        accountLease: AccountLease,
        completion: @escaping @MainActor (AccountLifecycleTransitionResult) -> Void
    ) -> Bool {
        let ownerUserId = accountLease.subjectId
        let oldGeneration = accountLease.generation
        accountStateLock.lock()
        guard storedCurrentUser?.id == ownerUserId,
              lifecycleTransitionOwnerUserId == nil else {
            accountStateLock.unlock()
            return false
        }
        lifecycleTransitionOwnerUserId = ownerUserId
        accountStateLock.unlock()

        Task {
            let result = await AccountLifecycleTransitionController.shared
                .performAccountDeletionAfterBackendSoftDelete(
                oldAccountLease: accountLease,
                oldGeneration: oldGeneration
            )
            await MainActor.run {
                self.finalizeAccountDeletion(
                    expectedOwnerUserId: ownerUserId,
                    expectedGeneration: oldGeneration,
                    lifecycleResult: result
                )
                completion(result)
            }
        }
        return true
    }

    @discardableResult
    func teardownProfileForAccountLifecycle(context: AccountLifecycleContext) -> Bool {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        let expectedOwnerUserId = context.oldAccountLease?.subjectId
        if let currentOwnerUserId = storedCurrentUser?.id,
           let expectedOwnerUserId,
           currentOwnerUserId != expectedOwnerUserId {
            return true
        }
        guard expectedOwnerUserId != nil || context.event == .coldStartRecovery else {
            return false
        }
        storedCurrentUser = nil
        privateAccessState = context.event == .privateSuspension ? .suspended : .signedOut
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        syntheticPrivateUserId = nil
        #endif
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        return true
    }

    @MainActor
    @discardableResult
    private func finalizeLogout(
        expectedOwnerUserId: String?,
        lifecycleResult: AccountLifecycleTransitionResult
    ) -> Bool {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        guard lifecycleTransitionOwnerUserId == expectedOwnerUserId else {
            return false
        }
        lifecycleTransitionOwnerUserId = nil
        guard lifecycleResult.canFinalize else { return false }
        if let currentOwnerUserId = storedCurrentUser?.id,
           let expectedOwnerUserId,
           currentOwnerUserId != expectedOwnerUserId {
            return false
        }
        storedCurrentUser = nil
        privateAccessState = .signedOut
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        syntheticPrivateUserId = nil
        #endif
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        NotificationCenter.default.post(name: .djUserDidLogout, object: nil)
        return true
    }

    @MainActor
    private func finalizePrivateSuspension(
        expectedOwnerUserId: String,
        reason: String,
        lifecycleResult: AccountLifecycleTransitionResult
    ) {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        guard lifecycleTransitionOwnerUserId == expectedOwnerUserId else { return }
        lifecycleTransitionOwnerUserId = nil
        guard lifecycleResult.canFinalize else { return }
        if let currentOwnerUserId = storedCurrentUser?.id,
           currentOwnerUserId != expectedOwnerUserId {
            return
        }
        NotificationCenter.default.post(
            name: .djPrivateAccessDidSuspend,
            object: nil,
            userInfo: ["reason": reason]
        )
    }

    @MainActor
    private func finalizeAccountDeletion(
        expectedOwnerUserId: String,
        expectedGeneration: UInt64,
        lifecycleResult: AccountLifecycleTransitionResult
    ) {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        guard lifecycleTransitionOwnerUserId == expectedOwnerUserId else { return }
        lifecycleTransitionOwnerUserId = nil
        let cleanupCompleted = lifecycleResult.cleanupCompleted
        guard lifecycleResult.lifecycleReceipt.isTerminal,
              lifecycleResult.lifecycleReceipt.oldGeneration == expectedGeneration,
              lifecycleResult.actorReceipt.accepted,
              lifecycleResult.actorReceipt.state == .signedOut else {
            return
        }
        if let currentOwnerUserId = storedCurrentUser?.id,
           currentOwnerUserId != expectedOwnerUserId {
            return
        }
        storedCurrentUser = nil
        privateAccessState = .signedOut
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        syntheticPrivateUserId = nil
        #endif
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        NotificationCenter.default.post(
            name: .djUserDidLogout,
            object: nil,
            userInfo: [
                "reason": "accountDeletion",
                "cleanupCompleted": cleanupCompleted,
            ]
        )
    }

    private func lifecycleAccountLease(from session: AccountSession?) -> AccountLease? {
        guard let session else { return nil }
        return AccountLease(
            subjectId: session.subjectId,
            vaultId: session.vaultId,
            sessionId: session.sessionId,
            generation: session.generation,
            generationId: session.generationId,
            authorityEpoch: RecoveryRuntimePolicyStore.shared.currentPolicy.authorityEpoch
        )
    }

    // MARK: - 持久化
    private func saveToDefaultsLocked(user: UserModel) -> Bool {
        guard let data = try? JSONEncoder().encode(user) else { return false }
        UserDefaults.standard.set(data, forKey: kUserKey)
        UserDefaults.standard.set(true, forKey: kLoggedInKey)
        return true
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: kUserKey),
              let user = try? JSONDecoder().decode(UserModel.self, from: data) else { return }
        storedCurrentUser = user
    }
}

// MARK: - Notification 名称
extension Notification.Name {
    static let djUserDidLogin  = Notification.Name("dj.user.didLogin")
    static let djUserDidLogout = Notification.Name("dj.user.didLogout")
    static let djUserDidUpdate = Notification.Name("dj.user.didUpdate")
    static let djPrivateAccessDidSuspend = Notification.Name("dj.privateAccess.didSuspend")
    static let djAccountLifecycleWillTeardown = Notification.Name("dj.accountLifecycle.willTeardown")
    static let djNewMemoryCreated = Notification.Name("dj.memory.newCreated")
}
