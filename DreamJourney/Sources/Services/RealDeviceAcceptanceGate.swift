import Foundation

enum RealDeviceAcceptanceGate {
    static func isEnabled(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        arguments.contains("--real-acceptance")
            || arguments.contains("--real-device-acceptance")
            || isTruthy(environment["DREAMJOURNEY_REAL_ACCEPTANCE"])
            || isTruthy(environment["DREAMJOURNEY_REAL_DEVICE_ACCEPTANCE"])
    }

    private static func isTruthy(_ value: String?) -> Bool {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
