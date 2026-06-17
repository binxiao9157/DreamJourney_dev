import Foundation

enum DigitalHumanMode: String, Codable {
    case sunlight
    case star
    case silent
}

struct DigitalHumanContext: Codable {
    var viewerUserId: String?
    var ownerId: String
    var displayName: String
    var relation: String?
    var mode: DigitalHumanMode
    var isSelfAssistant: Bool

    static func defaultContext(userId: String) -> DigitalHumanContext {
        DigitalHumanContext(
            viewerUserId: userId,
            ownerId: userId,
            displayName: "AI 助手",
            relation: nil,
            mode: .sunlight,
            isSelfAssistant: true
        )
    }

    var resolvedDisplayName: String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return isSelfAssistant ? "AI 助手" : "家人数字人"
    }

    func normalizedForCurrentViewer(_ viewerUserId: String) -> DigitalHumanContext {
        var normalized = self
        normalized.viewerUserId = viewerUserId
        if normalized.ownerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.ownerId = viewerUserId
        }
        normalized.displayName = normalized.resolvedDisplayName
        return normalized
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
               (context.viewerUserId ?? context.ownerId) == userId {
                return context.normalizedForCurrentViewer(userId)
            }
            return .defaultContext(userId: userId)
        }
        set {
            let userId = UserManager.shared.currentUser?.id ?? "user_001"
            let normalized = newValue.normalizedForCurrentViewer(userId)
            if let data = try? JSONEncoder().encode(normalized) {
                UserDefaults.standard.set(data, forKey: key)
                NotificationCenter.default.post(name: .djDigitalHumanContextDidChange, object: normalized)
            }
        }
    }
}

extension Notification.Name {
    static let djDigitalHumanContextDidChange = Notification.Name("dj.digitalHuman.contextDidChange")
}
