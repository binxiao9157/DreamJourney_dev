import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
  }
}

private enum ModelAccountLifecycleEvent: String, CaseIterable, Codable {
  case coldStartRecovery
  case switchAccount
  case logout
  case privateSuspension
  case accountDeletion
}

private enum ModelAccountLifecyclePhase: Int, CaseIterable, Codable {
  case fence
  case cancelEffects
  case unmountRuntime
  case clearProjection
  case clearNotification
  case retainOrPurgeDraft
  case finalize
}

private enum ModelAccountLifecycleModuleOutcome: String, CaseIterable, Codable {
  case retainedLocked
  case unmounted
  case cancelled
  case cleared
  case purged
  case skipped
  case failed
}

private enum ModelAccountLifecyclePolicy: String, Codable {
  case retainLocked
  case clear
  case purge
}

private struct ModelAccountLease {
  let subjectId: String
  let vaultId: String
  let sessionId: String
  let generation: UInt64
}

private struct ModelAccountLifecycleContext {
  let event: ModelAccountLifecycleEvent
  let priorLease: ModelAccountLease?
}

private struct ModelAccountLifecycleModuleDescriptor {
  let moduleId: String
  let phase: ModelAccountLifecyclePhase
  let policy: ModelAccountLifecyclePolicy
  let plannedOutcome: ModelAccountLifecycleModuleOutcome
  let remainingLocalData: Bool
  let detailCode: String
  let throwsDuringExecution: Bool
}

private struct ModelAccountLifecycleModuleReceipt: Codable, Equatable {
  let operationId: UUID
  let moduleId: String
  let event: ModelAccountLifecycleEvent
  let outcome: ModelAccountLifecycleModuleOutcome
  let remainingLocalData: Bool
  let detailCode: String
}

private struct ModelAccountLifecycleOperationReceipt: Codable, Equatable {
  let operationId: UUID
  let event: ModelAccountLifecycleEvent
  let moduleReceipts: [ModelAccountLifecycleModuleReceipt]
}

private enum ModelModuleFailure: Error {
  case planned
}

private final class ModelAccountLifecycleCoordinator {
  private var completedOperations: [UUID: ModelAccountLifecycleOperationReceipt] = [:]
  private var executionCounts: [String: Int] = [:]
  private var activeOperation: (operationId: UUID, generation: UInt64)?
  private var nextGeneration: UInt64 = 0
  private(set) var acceptedCallbacksByOperation: [UUID: Int] = [:]

  func execute(
    operationId: UUID,
    context: ModelAccountLifecycleContext,
    modules: [ModelAccountLifecycleModuleDescriptor]
  ) -> ModelAccountLifecycleOperationReceipt {
    if let completed = completedOperations[operationId] {
      return completed
    }

    _ = begin(operationId: operationId)
    let orderedModules = modules.enumerated().sorted { lhs, rhs in
      if lhs.element.phase.rawValue != rhs.element.phase.rawValue {
        return lhs.element.phase.rawValue < rhs.element.phase.rawValue
      }
      return lhs.offset < rhs.offset
    }.map(\.element)

    var receipts: [ModelAccountLifecycleModuleReceipt] = []
    for module in orderedModules {
      executionCounts[module.moduleId, default: 0] += 1
      do {
        if module.throwsDuringExecution {
          throw ModelModuleFailure.planned
        }
        receipts.append(
          ModelAccountLifecycleModuleReceipt(
            operationId: operationId,
            moduleId: module.moduleId,
            event: context.event,
            outcome: module.plannedOutcome,
            remainingLocalData: module.remainingLocalData,
            detailCode: module.detailCode
          )
        )
      } catch {
        receipts.append(
          ModelAccountLifecycleModuleReceipt(
            operationId: operationId,
            moduleId: module.moduleId,
            event: context.event,
            outcome: .failed,
            remainingLocalData: true,
            detailCode: "moduleExecutionFailed"
          )
        )
      }
    }

    let receipt = ModelAccountLifecycleOperationReceipt(
      operationId: operationId,
      event: context.event,
      moduleReceipts: receipts
    )
    completedOperations[operationId] = receipt
    return receipt
  }

  @discardableResult
  func begin(operationId: UUID) -> UInt64 {
    nextGeneration += 1
    activeOperation = (operationId, nextGeneration)
    return nextGeneration
  }

  func recordCallback(operationId: UUID, generation: UInt64) -> Bool {
    guard activeOperation?.operationId == operationId,
      activeOperation?.generation == generation
    else {
      return false
    }
    acceptedCallbacksByOperation[operationId, default: 0] += 1
    return true
  }

  func executionCount(for moduleId: String) -> Int {
    executionCounts[moduleId, default: 0]
  }
}

private func descriptor(
  _ moduleId: String,
  _ phase: ModelAccountLifecyclePhase,
  outcome: ModelAccountLifecycleModuleOutcome,
  policy: ModelAccountLifecyclePolicy = .clear,
  remainingLocalData: Bool = false,
  throwsDuringExecution: Bool = false
) -> ModelAccountLifecycleModuleDescriptor {
  ModelAccountLifecycleModuleDescriptor(
    moduleId: moduleId,
    phase: phase,
    policy: policy,
    plannedOutcome: outcome,
    remainingLocalData: remainingLocalData,
    detailCode: "\(moduleId).complete",
    throwsDuringExecution: throwsDuringExecution
  )
}

private func runAccountLifecycleCoordinatorModelSmoke() throws {
  require(
    Set(ModelAccountLifecycleEvent.allCases.map(\.rawValue))
      == Set([
        "coldStartRecovery", "switchAccount", "logout", "privateSuspension", "accountDeletion",
      ]),
    "all lifecycle events must remain modeled"
  )
  require(
    ModelAccountLifecyclePhase.allCases.map(\.rawValue) == Array(0...6),
    "lifecycle phases must have one stable total order"
  )
  require(
    Set(ModelAccountLifecycleModuleOutcome.allCases.map(\.rawValue))
      == Set([
        "retainedLocked", "unmounted", "cancelled", "cleared", "purged", "skipped", "failed",
      ]),
    "all lifecycle outcomes must remain modeled"
  )

  let oldLease = ModelAccountLease(
    subjectId: "raw-account-a",
    vaultId: "raw-vault-a",
    sessionId: "raw-session-a",
    generation: 41
  )
  let context = ModelAccountLifecycleContext(event: .switchAccount, priorLease: oldLease)
  require(context.priorLease?.generation == 41, "lifecycle context may retain the old AccountLease")

  let modules = [
    descriptor("finalizer", .finalize, outcome: .cleared),
    descriptor("notification", .clearNotification, outcome: .cleared),
    descriptor("cancel-failing", .cancelEffects, outcome: .cancelled, throwsDuringExecution: true),
    descriptor("fence-first", .fence, outcome: .cancelled),
    descriptor("runtime", .unmountRuntime, outcome: .unmounted),
    descriptor("projection", .clearProjection, outcome: .cleared),
    descriptor(
      "draft", .retainOrPurgeDraft, outcome: .retainedLocked, policy: .retainLocked,
      remainingLocalData: true),
    descriptor("fence-second", .fence, outcome: .skipped),
  ]

  let coordinator = ModelAccountLifecycleCoordinator()
  let operationId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
  let receipt = coordinator.execute(operationId: operationId, context: context, modules: modules)
  require(
    receipt.moduleReceipts.map(\.moduleId) == [
      "fence-first", "fence-second", "cancel-failing", "runtime",
      "projection", "notification", "draft", "finalizer",
    ],
    "modules must execute in stable phase and registration order"
  )
  require(
    receipt.moduleReceipts.first(where: { $0.moduleId == "cancel-failing" })?.outcome == .failed,
    "module failure must produce a failed receipt"
  )
  require(
    receipt.moduleReceipts.last?.moduleId == "finalizer",
    "a failed module must not prevent later phases from producing receipts"
  )

  let duplicate = coordinator.execute(
    operationId: operationId,
    context: context,
    modules: [descriptor("must-not-run", .fence, outcome: .purged)]
  )
  require(duplicate == receipt, "the same operation must return its original idempotent receipt")
  require(
    coordinator.executionCount(for: "fence-first") == 1,
    "an idempotent replay must not rerun modules")
  require(
    coordinator.executionCount(for: "must-not-run") == 0,
    "an idempotent replay must ignore new work")

  let staleOperationId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
  let currentOperationId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
  let staleGeneration = coordinator.begin(operationId: staleOperationId)
  let currentGeneration = coordinator.begin(operationId: currentOperationId)
  require(
    !coordinator.recordCallback(operationId: staleOperationId, generation: staleGeneration),
    "an old generation callback must not commit into a newer operation"
  )
  require(
    coordinator.recordCallback(operationId: currentOperationId, generation: currentGeneration),
    "the active operation callback must remain committable"
  )
  require(
    coordinator.acceptedCallbacksByOperation[staleOperationId] == nil,
    "a rejected stale callback must leave no operation receipt side effect"
  )

  let encodedReceipt = try JSONEncoder().encode(receipt)
  let receiptText = String(decoding: encodedReceipt, as: UTF8.self)
  for forbidden in [
    oldLease.subjectId,
    oldLease.vaultId,
    oldLease.sessionId,
    "access-token-secret",
    "refresh-token-secret",
  ] {
    require(
      !receiptText.contains(forbidden),
      "receipts must not serialize raw identity or credential values")
  }

  print("PASS: Product V4 AccountLifecycleCoordinator model smoke")
}

try runAccountLifecycleCoordinatorModelSmoke()
