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
        make(type: selectedType(arguments: arguments, environment: environment))
    }

    static func selectedType(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DialogEngineType {
        if RealDeviceAcceptanceGate.isEnabled(arguments: arguments, environment: environment) {
            return .volcengine
        }

        if canUseMockDialogEngine(arguments: arguments, environment: environment) {
            return .mock
        }
        return .volcengine
    }

    private static func canUseMockDialogEngine(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        #if targetEnvironment(simulator) || MOCK_DIALOG_VERIFY
        return arguments.contains("--use-mock-dialog-engine") ||
            environment["DREAMJOURNEY_DIALOG_ENGINE"]?.lowercased() == "mock"
        #else
        return false
        #endif
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
