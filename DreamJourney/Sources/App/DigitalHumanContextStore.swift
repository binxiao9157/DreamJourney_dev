import Foundation

enum DigitalHumanMode: String, Codable, Equatable {
    case sunlight
    case star
    case silent

    var displayName: String {
        switch self {
        case .sunlight:
            return "阳光"
        case .star:
            return "星辰"
        case .silent:
            return "静默"
        }
    }

    var selectionDescription: String {
        switch self {
        case .sunlight:
            return "普通陪伴，不展示心境追踪"
        case .star:
            return "启用心理引导和心境追踪"
        case .silent:
            return "长期失联观察态，不公开展示"
        }
    }
}

struct DigitalHumanContext: Codable, Equatable {
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

    private let keyBase = "dj.digitalHuman.currentContext"
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    private init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    var current: DigitalHumanContext {
        get {
            let userId = normalizedUserId(UserManager.shared.currentUser?.id)
            guard !userId.isEmpty else { return .defaultContext(userId: "") }
            if let data = UserDefaults.standard.data(forKey: key(for: userId)),
               let context = try? JSONDecoder().decode(DigitalHumanContext.self, from: data),
               let validated = validatedContext(context, userId: userId) {
                return validated
            }
            return .defaultContext(userId: userId)
        }
        set {
            let sourceUserId = normalizedUserId(UserManager.shared.currentUser?.id)
            guard !sourceUserId.isEmpty,
                  let accountLease = accountLeaseRuntime.capture(forSubjectId: sourceUserId) else {
                return
            }
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self.applyCurrent(
                        newValue,
                        userId: sourceUserId,
                        accountLease: accountLease
                    )
                }
                return
            }
            applyCurrent(newValue, userId: sourceUserId, accountLease: accountLease)
        }
    }

    func reconcileFamilyAuthorization() {
        let sourceUserId = normalizedUserId(UserManager.shared.currentUser?.id)
        guard !sourceUserId.isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: sourceUserId) else {
            return
        }
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.reconcileFamilyAuthorization(
                    userId: sourceUserId,
                    accountLease: accountLease
                )
            }
            return
        }
        reconcileFamilyAuthorization(userId: sourceUserId, accountLease: accountLease)
    }

    private func applyCurrent(
        _ newValue: DigitalHumanContext,
        userId: String,
        accountLease: AccountLease
    ) {
        guard normalizedUserId(UserManager.shared.currentUser?.id) == userId,
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return
        }
        let safeContext = validatedContext(newValue, userId: userId) ?? .defaultContext(userId: userId)
        let storageKey = key(for: userId)
        let previousData = UserDefaults.standard.data(forKey: storageKey)
        let previousContext = storedContext(for: userId)
        guard let data = try? JSONEncoder().encode(safeContext) else { return }
        UserDefaults.standard.set(data, forKey: key(for: userId))
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if let previousData {
                UserDefaults.standard.set(previousData, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
            return
        }
        let identity = KBLiteManager.resolveAuthorizedPersonaIdentity(for: safeContext)
        KBLiteManager.shared.personaContextDidChange(to: identity)
        KnowledgeSyncCoordinator.shared.personaContextDidChange(to: identity)
        guard previousContext != safeContext else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        NotificationCenter.default.post(name: .djDigitalHumanContextDidChange, object: safeContext)
    }

    private func reconcileFamilyAuthorization(
        userId: String,
        accountLease: AccountLease
    ) {
        guard normalizedUserId(UserManager.shared.currentUser?.id) == userId,
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return
        }
        guard !userId.isEmpty,
              let data = UserDefaults.standard.data(forKey: key(for: userId)),
              let storedContext = try? JSONDecoder().decode(DigitalHumanContext.self, from: data) else {
            return
        }
        let hasAuthorizedFamilyMember = FamilyRepository.shared.acceptedMember(
            by: storedContext.ownerId
        ) != nil
        guard FamilyContextReconciliationPolicy.shouldFallbackToSelf(
            viewerUserId: userId,
            contextOwnerId: storedContext.ownerId,
            isSelfAssistant: storedContext.isSelfAssistant,
            hasAuthorizedFamilyMember: hasAuthorizedFamilyMember
        ) else { return }
        applyCurrent(
            .defaultContext(userId: userId),
            userId: userId,
            accountLease: accountLease
        )
    }

    private func validatedContext(_ context: DigitalHumanContext, userId: String) -> DigitalHumanContext? {
        let normalized = context.normalizedForCurrentViewer(userId)
        let ownerId = normalized.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ownerId.isEmpty else { return nil }

        if normalized.isSelfAssistant || ownerId == userId {
            return .defaultContext(userId: userId)
        }
        guard let member = FamilyRepository.shared.acceptedMember(by: ownerId) else {
            return nil
        }
        return DigitalHumanContext(
            viewerUserId: userId,
            ownerId: member.id,
            displayName: member.name,
            relation: member.relation,
            mode: member.digitalHumanMode,
            isSelfAssistant: false
        )
    }

    private func key(for userId: String) -> String {
        "\(keyBase).\(userId)"
    }

    private func storedContext(for userId: String) -> DigitalHumanContext? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(DigitalHumanContext.self, from: data)
    }

    private func normalizedUserId(_ userId: String?) -> String {
        userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension Notification.Name {
    static let djDigitalHumanContextDidChange = Notification.Name("dj.digitalHuman.contextDidChange")
}
