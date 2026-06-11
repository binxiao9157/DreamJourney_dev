import Foundation

// MARK: - DialogEngineFactory

enum DialogEngineType: String {
    case volcengine
    case appleFree
}

final class DialogEngineFactory {
    static func make(type: DialogEngineType = .volcengine) -> DialogEngineProtocol {
        switch type {
        case .volcengine:
            return DialogEngineManager.shared
        case .appleFree:
            fatalError("Apple free dialog engine has not been integrated into DreamJourney_dev yet.")
        }
    }
}
