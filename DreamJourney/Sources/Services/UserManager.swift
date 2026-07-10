import Foundation

enum UserProfileSaveResult {
    case saved
    case savedWithRemoteWarning(String)
    case failed(String)
}

// MARK: - UserManager 单例：管理登录态
final class UserManager {

    static let shared = UserManager()
    private init() { loadFromDefaults() }

    private let kUserKey = "dj_current_user"
    private let kLoggedInKey = "dj_is_logged_in"

    private(set) var currentUser: UserModel?
    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - 登录
    func login(phone: String, nickname: String, id: String? = nil) {
        let user = UserModel(
            id: id ?? "user_\(phone.suffix(4))",
            nickname: nickname.isEmpty ? "寻梦环游用户" : nickname,
            phone: phone,
            avatarName: "person.circle.fill"
        )
        currentUser = user
        _ = saveToDefaults()
        NotificationCenter.default.post(name: .djUserDidLogin, object: nil)
    }

    func updateProfile(nickname: String) {
        _ = updateProfileLocally(nickname: nickname)
    }

    func saveProfile(nickname: String, completion: @escaping (UserProfileSaveResult) -> Void) {
        saveProfile(
            nickname: nickname,
            gender: currentUser?.gender,
            region: currentUser?.region,
            avatarName: currentUser?.avatarName,
            completion: completion
        )
    }

    func saveProfile(nickname: String, gender: String?, region: String?, avatarName: String? = nil, completion: @escaping (UserProfileSaveResult) -> Void) {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            completion(.failed("昵称不能为空"))
            return
        }

        guard var user = currentUser else {
            completion(.failed("请先登录后再保存"))
            return
        }
        user.nickname = trimmedNickname
        user.gender = normalizedProfileField(gender)
        user.region = normalizedProfileField(region)
        if avatarName != nil {
            user.avatarName = normalizedProfileField(avatarName)
        }
        currentUser = user
        guard saveToDefaults() else {
            completion(.failed("本地保存失败，请稍后再试"))
            return
        }
        NotificationCenter.default.post(name: .djUserDidUpdate, object: nil)

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
        guard var user = currentUser else { return false }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        user.nickname = trimmedNickname.isEmpty ? "寻梦环游用户" : trimmedNickname
        currentUser = user
        guard saveToDefaults() else { return false }
        NotificationCenter.default.post(name: .djUserDidUpdate, object: nil)
        return true
    }

    // MARK: - 退出登录
    func logout() {
        DreamJourneyBackendClient.shared.logoutAuthSession()
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        NotificationCenter.default.post(name: .djUserDidLogout, object: nil)
    }

    // MARK: - 持久化
    @discardableResult
    private func saveToDefaults() -> Bool {
        guard let user = currentUser,
              let data = try? JSONEncoder().encode(user) else { return false }
        UserDefaults.standard.set(data, forKey: kUserKey)
        UserDefaults.standard.set(true, forKey: kLoggedInKey)
        return true
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: kUserKey),
              let user = try? JSONDecoder().decode(UserModel.self, from: data) else { return }
        currentUser = user
    }
}

// MARK: - Notification 名称
extension Notification.Name {
    static let djUserDidLogin  = Notification.Name("dj.user.didLogin")
    static let djUserDidLogout = Notification.Name("dj.user.didLogout")
    static let djUserDidUpdate = Notification.Name("dj.user.didUpdate")
    static let djNewMemoryCreated = Notification.Name("dj.memory.newCreated")
}
