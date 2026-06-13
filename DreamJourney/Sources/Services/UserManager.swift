import Foundation

// MARK: - UserManager 单例：管理登录态
final class UserManager {

    static let shared = UserManager()
    private init() { loadFromDefaults() }

    private let kUserKey = "dj_current_user"
    private let kLoggedInKey = "dj_is_logged_in"

    private(set) var currentUser: UserModel?
    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - 登录
    func login(phone: String, nickname: String) {
        let user = UserModel(
            id: Self.stableUserID(for: phone),
            nickname: nickname.isEmpty ? "寻梦环游用户" : nickname,
            phone: phone,
            avatarName: "person.circle.fill"
        )
        currentUser = user
        saveToDefaults()
        KBLiteManager.shared.reloadForCurrentUser()
        NotificationCenter.default.post(name: .djUserDidLogin, object: nil)
    }

    // MARK: - 退出登录
    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: kUserKey)
        UserDefaults.standard.removeObject(forKey: kLoggedInKey)
        KBLiteManager.shared.clearForLoggedOutUser()
        NotificationCenter.default.post(name: .djUserDidLogout, object: nil)
    }

    // MARK: - 持久化
    private func saveToDefaults() {
        guard let user = currentUser,
              let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: kUserKey)
        UserDefaults.standard.set(true, forKey: kLoggedInKey)
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: kUserKey),
              let user = try? JSONDecoder().decode(UserModel.self, from: data) else { return }
        guard !Self.isLegacyRoadshowUser(user) else {
            UserDefaults.standard.removeObject(forKey: kUserKey)
            UserDefaults.standard.removeObject(forKey: kLoggedInKey)
            currentUser = nil
            return
        }
        currentUser = user
    }

    private static func isLegacyRoadshowUser(_ user: UserModel) -> Bool {
        user.nickname == "路演家庭" ||
            user.phone == "18800000001"
    }

    private static func stableUserID(for phone: String) -> String {
        let normalized = normalizedPhoneDigits(phone)
        let source = normalized.isEmpty ? phone.trimmingCharacters(in: .whitespacesAndNewlines) : normalized
        var hash = offsetBasis
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* fnvPrime
        }
        let hex = String(hash, radix: 16)
        return "user_" + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }

    private static func normalizedPhoneDigits(_ phone: String) -> String {
        String(phone.filter { $0.isNumber })
    }

    private static let offsetBasis: UInt64 = 1_469_598_103_934_665_603
    private static let fnvPrime: UInt64 = 1_099_511_628_211
}

// MARK: - Notification 名称
extension Notification.Name {
    static let djUserDidLogin  = Notification.Name("dj.user.didLogin")
    static let djUserDidLogout = Notification.Name("dj.user.didLogout")
    static let djNewMemoryCreated = Notification.Name("dj.memory.newCreated")
    static let djConversationKnowledgeExtractionFinished = Notification.Name("dj.conversation.knowledgeExtractionFinished")
}
