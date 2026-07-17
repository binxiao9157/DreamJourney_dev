import Foundation

enum UserProfileSaveResult {
    case saved
    case savedWithRemoteWarning(String)
    case failed(String)
}

// MARK: - UserManager 单例：管理登录态
final class UserManager {

    static let shared = UserManager()
    private init() {
        loadFromDefaults()
        EchoTraceAccountLifecycle.activate(ownerUserId: currentUser?.id)
    }

    private let accountStateLock = NSRecursiveLock()
    private let kUserKey = "dj_current_user"
    private let kLoggedInKey = "dj_is_logged_in"

    private var storedCurrentUser: UserModel?
    var currentUser: UserModel? {
        accountStateLock.lock()
        defer { accountStateLock.unlock() }
        return storedCurrentUser
    }
    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - 登录
    func login(phone: String, nickname: String, id: String? = nil) {
        let user = UserModel(
            id: id ?? "user_\(phone.suffix(4))",
            nickname: nickname.isEmpty ? "寻梦环游用户" : nickname,
            phone: phone,
            avatarName: "person.circle.fill"
        )
        accountStateLock.lock()
        let previousOwnerUserId = storedCurrentUser?.id
        storedCurrentUser = user
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
        storedCurrentUser = nil
        EchoTraceAccountLifecycle.invalidateAndClear(ownerUserId: ownerUserId)
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        DreamJourneyBackendClient.shared.logoutAuthSession()
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
    static let djNewMemoryCreated = Notification.Name("dj.memory.newCreated")
}
