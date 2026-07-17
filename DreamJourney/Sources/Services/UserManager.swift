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
        EchoTraceAccountLifecycle.activate(ownerUserId: currentUser?.id)
    }

    private let accountStateLock = NSRecursiveLock()
    private let kUserKey = "dj_current_user"
    private let kLoggedInKey = "dj_is_logged_in"

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
        let user = storedCurrentUser
        let state = privateAccessState
        accountStateLock.unlock()
        guard state == .validating, let user else { return false }
        return BackendAuthSessionStore.shared.currentSession?.isPrivateAccessEligible(for: user.id) == true
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
        guard let user = capturedUser,
              let session = capturedSession,
              session.isPrivateAccessEligible(for: user.id) else {
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
        privateAccessState = .validating
        accountStateLock.unlock()
        return true
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

        let applySuspension = {
            KnowledgeSyncCoordinator.shared.userDidChange(to: nil)
            KBLiteManager.shared.switchUser(to: nil)
            if notify && stateChanged {
                NotificationCenter.default.post(
                    name: .djPrivateAccessDidSuspend,
                    object: nil,
                    userInfo: ["reason": reason]
                )
            }
        }
        if Thread.isMainThread {
            applySuspension()
        } else {
            DispatchQueue.main.async(execute: applySuspension)
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
        EchoTraceAccountLifecycle.invalidateAndClear(ownerUserId: ownerUserId)
        DreamJourneyBackendClient.shared.logoutAuthSession()
        storedCurrentUser = nil
        privateAccessState = .signedOut
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        syntheticPrivateUserId = nil
        #endif
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        KnowledgeSyncCoordinator.shared.userDidChange(to: nil)
        KBLiteManager.shared.switchUser(to: nil)
        NotificationCenter.default.post(name: .djUserDidLogout, object: nil)
        accountStateLock.unlock()
    }

    func invalidateBackendSession(for userId: String) {
        accountStateLock.lock()
        guard storedCurrentUser?.id == userId else {
            accountStateLock.unlock()
            return
        }
        let ownerUserId = storedCurrentUser?.id
        storedCurrentUser = nil
        privateAccessState = .signedOut
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        syntheticPrivateUserId = nil
        #endif
        EchoTraceAccountLifecycle.invalidateAndClear(ownerUserId: ownerUserId)
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        KnowledgeSyncCoordinator.shared.userDidChange(to: nil)
        KBLiteManager.shared.switchUser(to: nil)
        NotificationCenter.default.post(name: .djUserDidLogout, object: nil)
        accountStateLock.unlock()
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
    static let djNewMemoryCreated = Notification.Name("dj.memory.newCreated")
}
