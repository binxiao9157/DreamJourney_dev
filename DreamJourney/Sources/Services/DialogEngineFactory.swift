import Foundation

// MARK: - DialogEngineFactory

enum DialogEngineType: String {
    case volcengine
    case appleFree
    case mock
}

final class DialogEngineFactory {
    static func makeDefault(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DialogEngineProtocol {
        if arguments.contains("--use-mock-dialog-engine") ||
            environment["DREAMJOURNEY_DIALOG_ENGINE"]?.lowercased() == "mock" {
            return make(type: .mock)
        }
        return make(type: .volcengine)
    }

    static func make(type: DialogEngineType = .volcengine) -> DialogEngineProtocol {
        switch type {
        case .volcengine:
            #if MOCK_DIALOG_VERIFY
            return MockDialogEngine()
            #else
            return DialogEngineManager.shared
            #endif
        case .appleFree:
            fatalError("Apple free dialog engine has not been integrated into DreamJourney_dev yet.")
        case .mock:
            return MockDialogEngine()
        }
    }
}
