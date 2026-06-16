import Foundation

enum DigitalHumanMode: String, Codable {
    case sunlight
    case star
    case silent
}

struct DigitalHumanContext: Codable {
    var ownerId: String
    var displayName: String
    var relation: String?
    var mode: DigitalHumanMode
    var isSelfAssistant: Bool

    static func defaultContext(userId: String) -> DigitalHumanContext {
        DigitalHumanContext(
            ownerId: userId,
            displayName: "",
            relation: nil,
            mode: .sunlight,
            isSelfAssistant: true
        )
    }
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()

    private let key = "dj.digitalHuman.currentContext"

    private init() {}

    var current: DigitalHumanContext {
        get {
            let userId = UserManager.shared.currentUser?.id ?? "user_001"
            if let data = UserDefaults.standard.data(forKey: key),
               let context = try? JSONDecoder().decode(DigitalHumanContext.self, from: data),
               context.ownerId == userId {
                return context
            }
            return .defaultContext(userId: userId)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
