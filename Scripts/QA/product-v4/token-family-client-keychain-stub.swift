import Foundation

public enum Accessibility {
    case afterFirstUnlockThisDeviceOnly
}

public final class Keychain {
    private static let lock = NSLock()
    private static var values: [String: Data] = [:]

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func accessibility(_ accessibility: Accessibility) -> Keychain {
        self
    }

    public func synchronizable(_ synchronizable: Bool) -> Keychain {
        self
    }

    public func set(_ value: Data, key: String) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        Self.values[storageKey(key)] = value
    }

    public func getData(_ key: String) throws -> Data? {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return Self.values[storageKey(key)]
    }

    public func remove(_ key: String) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        Self.values.removeValue(forKey: storageKey(key))
    }

    private func storageKey(_ key: String) -> String {
        "\(service):\(key)"
    }
}
