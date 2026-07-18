import Foundation

enum AccountLifecycleEvent: String, CaseIterable, Codable, Sendable {
    case coldStartRecovery
    case switchAccount
    case logout
    case privateSuspension
    case accountDeletion
}

enum AccountLifecyclePhase: Int, CaseIterable, Codable, Sendable {
    case fence
    case cancelEffects
    case unmountRuntime
    case clearProjection
    case clearNotification
    case retainOrPurgeDraft
    case finalize
}

enum AccountLifecycleModuleOutcome: String, CaseIterable, Codable, Sendable {
    case retainedLocked
    case unmounted
    case cancelled
    case cleared
    case purged
    case skipped
    case failed
}

struct AccountLifecycleModuleDescriptor: Codable, Equatable, Sendable {
    let moduleId: String
    let phase: AccountLifecyclePhase
    let coldStartPolicy: AccountLifecycleModuleOutcome
    let switchPolicy: AccountLifecycleModuleOutcome
    let logoutPolicy: AccountLifecycleModuleOutcome
    let suspensionPolicy: AccountLifecycleModuleOutcome
    let deletionPolicy: AccountLifecycleModuleOutcome

    func policy(for event: AccountLifecycleEvent) -> AccountLifecycleModuleOutcome {
        switch event {
        case .coldStartRecovery:
            return coldStartPolicy
        case .switchAccount:
            return switchPolicy
        case .logout:
            return logoutPolicy
        case .privateSuspension:
            return suspensionPolicy
        case .accountDeletion:
            return deletionPolicy
        }
    }
}

struct AccountLifecycleContext: Sendable {
    let operationId: UUID
    let event: AccountLifecycleEvent
    let oldAccountLease: AccountLease?
    let oldGeneration: UInt64
    let startedAt: Date
}

struct AccountLifecycleModuleResult: Equatable, Sendable {
    let outcome: AccountLifecycleModuleOutcome
    let remainingLocalData: Bool
    let detailCode: String

    static func completed(
        _ outcome: AccountLifecycleModuleOutcome,
        remainingLocalData: Bool,
        detailCode: String
    ) -> AccountLifecycleModuleResult {
        AccountLifecycleModuleResult(
            outcome: outcome,
            remainingLocalData: remainingLocalData,
            detailCode: detailCode
        )
    }
}

struct AccountLifecycleModuleReceipt: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let operationId: UUID
    let moduleId: String
    let event: AccountLifecycleEvent
    let phase: AccountLifecyclePhase
    let requestedOutcome: AccountLifecycleModuleOutcome
    let outcome: AccountLifecycleModuleOutcome
    let remainingLocalData: Bool
    let detailCode: String
    let completedAt: Date
}

struct AccountLifecycleOperationReceipt: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let operationId: UUID
    let event: AccountLifecycleEvent
    let oldGeneration: UInt64
    let startedAt: Date
    let completedAt: Date?
    let moduleReceipts: [AccountLifecycleModuleReceipt]
    let isTerminal: Bool

    var hasFailures: Bool {
        moduleReceipts.contains { $0.outcome == .failed }
    }

    var remainingLocalDataCount: Int {
        moduleReceipts.filter(\.remainingLocalData).count
    }
}

struct AccountLifecycleModuleRegistration: Sendable {
    typealias Handler = @Sendable (
        AccountLifecycleContext,
        AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult

    let descriptor: AccountLifecycleModuleDescriptor
    let handler: Handler
}

protocol AccountLifecycleReceiptPersisting: Sendable {
    func receipt(operationId: UUID) -> AccountLifecycleOperationReceipt?
    func save(_ receipt: AccountLifecycleOperationReceipt)
}

final class AccountLifecycleReceiptStore: AccountLifecycleReceiptPersisting, @unchecked Sendable {
    static let shared = AccountLifecycleReceiptStore()

    private let storageKey = "dj.accountLifecycle.receipts.v1"
    private let maximumReceiptCount = 30
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func receipt(operationId: UUID) -> AccountLifecycleOperationReceipt? {
        loadReceipts().first { $0.operationId == operationId }
    }

    func save(_ receipt: AccountLifecycleOperationReceipt) {
        lock.lock()
        var receipts = decodedReceiptsLocked()
        receipts.removeAll { $0.operationId == receipt.operationId }
        receipts.append(receipt)
        receipts.sort { $0.startedAt > $1.startedAt }
        if receipts.count > maximumReceiptCount {
            receipts.removeLast(receipts.count - maximumReceiptCount)
        }
        if let data = try? JSONEncoder().encode(receipts) {
            defaults.set(data, forKey: storageKey)
        }
        lock.unlock()
    }

    private func loadReceipts() -> [AccountLifecycleOperationReceipt] {
        lock.lock()
        let receipts = decodedReceiptsLocked()
        lock.unlock()
        return receipts
    }

    private func decodedReceiptsLocked() -> [AccountLifecycleOperationReceipt] {
        guard let data = defaults.data(forKey: storageKey),
              let receipts = try? JSONDecoder().decode(
                  [AccountLifecycleOperationReceipt].self,
                  from: data
              ) else {
            return []
        }
        return receipts
    }
}

actor AccountLifecycleCoordinator {
    static let shared = AccountLifecycleCoordinator()

    private let receiptStore: AccountLifecycleReceiptPersisting
    private var registrations: [AccountLifecycleModuleRegistration]

    init(
        receiptStore: AccountLifecycleReceiptPersisting = AccountLifecycleReceiptStore.shared,
        registrations: [AccountLifecycleModuleRegistration] = []
    ) {
        self.receiptStore = receiptStore
        self.registrations = Self.validatedRegistrations(registrations)
    }

    func replaceRegistrations(_ registrations: [AccountLifecycleModuleRegistration]) {
        self.registrations = Self.validatedRegistrations(registrations)
    }

    func perform(
        event: AccountLifecycleEvent,
        operationId: UUID,
        oldAccountLease: AccountLease?,
        oldGeneration: UInt64,
        startedAt: Date = Date()
    ) -> AccountLifecycleOperationReceipt {
        if let existing = receiptStore.receipt(operationId: operationId),
           existing.isTerminal {
            return existing
        }

        let priorReceipt = receiptStore.receipt(operationId: operationId)
        guard priorReceipt == nil
                || (priorReceipt?.event == event
                    && priorReceipt?.oldGeneration == oldGeneration) else {
            return operationIdentityConflictReceipt(
                event: event,
                operationId: operationId,
                oldGeneration: oldGeneration,
                startedAt: startedAt
            )
        }

        let context = AccountLifecycleContext(
            operationId: operationId,
            event: event,
            oldAccountLease: oldAccountLease,
            oldGeneration: oldGeneration,
            startedAt: priorReceipt?.startedAt ?? startedAt
        )
        guard !registrations.isEmpty else {
            return configurationFailureReceipt(
                context: context,
                detailCode: "moduleRegistryEmpty"
            )
        }
        var receiptsByModule = Dictionary(
            uniqueKeysWithValues: (priorReceipt?.moduleReceipts ?? []).map {
                ($0.moduleId, $0)
            }
        )
        let orderedRegistrations = registrations.sorted {
            if $0.descriptor.phase.rawValue == $1.descriptor.phase.rawValue {
                return $0.descriptor.moduleId < $1.descriptor.moduleId
            }
            return $0.descriptor.phase.rawValue < $1.descriptor.phase.rawValue
        }

        for registration in orderedRegistrations {
            let descriptor = registration.descriptor
            guard receiptsByModule[descriptor.moduleId] == nil else { continue }
            let requestedOutcome = descriptor.policy(for: event)
            let result = Self.validatedResult(
                registration.handler(context, requestedOutcome),
                requestedOutcome: requestedOutcome,
                event: event
            )
            let receipt = AccountLifecycleModuleReceipt(
                schemaVersion: 1,
                operationId: operationId,
                moduleId: Self.normalizedIdentifier(descriptor.moduleId),
                event: event,
                phase: descriptor.phase,
                requestedOutcome: requestedOutcome,
                outcome: result.outcome,
                remainingLocalData: result.remainingLocalData,
                detailCode: Self.normalizedDetailCode(result.detailCode),
                completedAt: Date()
            )
            receiptsByModule[descriptor.moduleId] = receipt
            savePartialReceipt(context: context, receiptsByModule: receiptsByModule)
        }

        let orderedReceipts = Self.orderedReceipts(
            Array(receiptsByModule.values),
            registrations: orderedRegistrations
        )
        let isTerminal = orderedReceipts.count == orderedRegistrations.count
        let receipt = AccountLifecycleOperationReceipt(
            schemaVersion: 1,
            operationId: operationId,
            event: event,
            oldGeneration: oldGeneration,
            startedAt: context.startedAt,
            completedAt: isTerminal ? Date() : nil,
            moduleReceipts: orderedReceipts,
            isTerminal: isTerminal
        )
        receiptStore.save(receipt)
        return receipt
    }

    private func savePartialReceipt(
        context: AccountLifecycleContext,
        receiptsByModule: [String: AccountLifecycleModuleReceipt]
    ) {
        receiptStore.save(
            AccountLifecycleOperationReceipt(
                schemaVersion: 1,
                operationId: context.operationId,
                event: context.event,
                oldGeneration: context.oldGeneration,
                startedAt: context.startedAt,
                completedAt: nil,
                moduleReceipts: Array(receiptsByModule.values).sorted {
                    $0.moduleId < $1.moduleId
                },
                isTerminal: false
            )
        )
    }

    private func operationIdentityConflictReceipt(
        event: AccountLifecycleEvent,
        operationId: UUID,
        oldGeneration: UInt64,
        startedAt: Date
    ) -> AccountLifecycleOperationReceipt {
        let moduleReceipt = AccountLifecycleModuleReceipt(
            schemaVersion: 1,
            operationId: operationId,
            moduleId: "account.lifecycle.operation",
            event: event,
            phase: .fence,
            requestedOutcome: .cancelled,
            outcome: .failed,
            remainingLocalData: true,
            detailCode: "operationIdentityConflict",
            completedAt: Date()
        )
        return AccountLifecycleOperationReceipt(
            schemaVersion: 1,
            operationId: operationId,
            event: event,
            oldGeneration: oldGeneration,
            startedAt: startedAt,
            completedAt: Date(),
            moduleReceipts: [moduleReceipt],
            isTerminal: true
        )
    }

    private func configurationFailureReceipt(
        context: AccountLifecycleContext,
        detailCode: String
    ) -> AccountLifecycleOperationReceipt {
        let moduleReceipt = AccountLifecycleModuleReceipt(
            schemaVersion: 1,
            operationId: context.operationId,
            moduleId: "account.lifecycle.registry",
            event: context.event,
            phase: .fence,
            requestedOutcome: .cancelled,
            outcome: .failed,
            remainingLocalData: true,
            detailCode: Self.normalizedDetailCode(detailCode),
            completedAt: Date()
        )
        let receipt = AccountLifecycleOperationReceipt(
            schemaVersion: 1,
            operationId: context.operationId,
            event: context.event,
            oldGeneration: context.oldGeneration,
            startedAt: context.startedAt,
            completedAt: Date(),
            moduleReceipts: [moduleReceipt],
            isTerminal: true
        )
        receiptStore.save(receipt)
        return receipt
    }

    private static func validatedRegistrations(
        _ registrations: [AccountLifecycleModuleRegistration]
    ) -> [AccountLifecycleModuleRegistration] {
        var seen = Set<String>()
        for registration in registrations {
            let moduleId = normalizedIdentifier(registration.descriptor.moduleId)
            precondition(
                !moduleId.isEmpty && moduleId == registration.descriptor.moduleId,
                "Account lifecycle moduleId must be a normalized non-empty identifier"
            )
            precondition(
                seen.insert(moduleId).inserted,
                "Account lifecycle moduleId must be unique: \(moduleId)"
            )
        }
        return registrations
    }

    private static func validatedResult(
        _ result: AccountLifecycleModuleResult,
        requestedOutcome: AccountLifecycleModuleOutcome,
        event: AccountLifecycleEvent
    ) -> AccountLifecycleModuleResult {
        guard result.outcome == requestedOutcome || result.outcome == .failed else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "moduleOutcomePolicyMismatch"
            )
        }
        if event == .accountDeletion,
           result.remainingLocalData,
           result.outcome != .failed {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "accountDeletionDataRemains"
            )
        }
        return result
    }

    private static func orderedReceipts(
        _ receipts: [AccountLifecycleModuleReceipt],
        registrations: [AccountLifecycleModuleRegistration]
    ) -> [AccountLifecycleModuleReceipt] {
        let ordering = Dictionary(
            uniqueKeysWithValues: registrations.enumerated().map {
                ($0.element.descriptor.moduleId, $0.offset)
            }
        )
        return receipts.sorted {
            let left = ordering[$0.moduleId] ?? Int.max
            let right = ordering[$1.moduleId] ?? Int.max
            if left == right { return $0.moduleId < $1.moduleId }
            return left < right
        }
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return String(value.unicodeScalars.filter { allowed.contains($0) }).prefix(80).description
    }

    private static func normalizedDetailCode(_ value: String) -> String {
        let normalized = normalizedIdentifier(value)
        return normalized.isEmpty ? "unspecified" : normalized
    }
}
