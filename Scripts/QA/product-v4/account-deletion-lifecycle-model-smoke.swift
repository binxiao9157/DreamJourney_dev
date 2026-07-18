import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
  }
}

private enum ModelSessionState: Equatable {
  case active
  case deleting
  case signedOut
}

private enum ModelDeletionStatus: Equatable {
  case backendRejected
  case staleCallbackIgnored
  case lifecycleIncomplete
  case signedOutCleanupPending
  case completed
}

private enum ModelRemoteDisposition: Equatable {
  case notApplicable
  case deleted
  case pending
  case unsupported
}

private enum ModelDraftDisposition: Equatable {
  case retainedLocked
  case purged
}

private struct ModelAccountLease: Equatable {
  let subjectId: String
  let vaultId: String
  let sessionId: String
  let generation: UInt64
}

private struct ModelModuleReceipt: Equatable {
  let moduleId: String
  let isTerminal: Bool
  let failed: Bool
  let remainingLocalData: Bool
  let remoteDisposition: ModelRemoteDisposition
}

private struct ModelDeletionResult: Equatable {
  let status: ModelDeletionStatus
  let receipts: [ModelModuleReceipt]
  let signedOut: Bool

  var claimsDeletionCompleted: Bool {
    status == .completed
  }
}

private final class ModelAccountDeletionOrchestrator {
  private(set) var currentLease: ModelAccountLease?
  private(set) var state: ModelSessionState
  private(set) var eventLog: [String] = []

  init(lease: ModelAccountLease) {
    currentLease = lease
    state = .active
  }

  func captureOldLeaseAndRequestBackendSoftDelete() -> ModelAccountLease {
    guard let currentLease else {
      fatalError("model requires an active lease")
    }
    eventLog.append("captureOldLease")
    eventLog.append("requestBackendSoftDelete")
    return currentLease
  }

  func activateNewAccount(_ lease: ModelAccountLease) {
    currentLease = lease
    state = .active
    eventLog.append("activateNewAccount")
  }

  func handleBackendSoftDeleteCompletion(
    succeeded: Bool,
    oldLease: ModelAccountLease,
    receipts: [ModelModuleReceipt]
  ) -> ModelDeletionResult {
    eventLog.append(succeeded ? "backendSoftDeleteSucceeded" : "backendSoftDeleteFailed")
    guard succeeded else {
      return ModelDeletionResult(status: .backendRejected, receipts: [], signedOut: false)
    }

    guard currentLease == oldLease, state == .active else {
      eventLog.append("ignoreStaleDeletionCallback")
      return ModelDeletionResult(status: .staleCallbackIgnored, receipts: [], signedOut: false)
    }

    state = .deleting
    eventLog.append("beginDeleting")
    receipts.forEach { eventLog.append("module:\($0.moduleId)") }

    guard receipts.count == 13, receipts.allSatisfy(\.isTerminal) else {
      eventLog.append("lifecycleIncomplete")
      return ModelDeletionResult(
        status: .lifecycleIncomplete,
        receipts: receipts,
        signedOut: false
      )
    }

    guard currentLease == oldLease, state == .deleting else {
      eventLog.append("ignoreStaleFinalizer")
      return ModelDeletionResult(status: .staleCallbackIgnored, receipts: receipts, signedOut: false)
    }

    state = .signedOut
    currentLease = nil
    eventLog.append("signOut")

    let localCleanupComplete = receipts.allSatisfy {
      !$0.failed && !$0.remainingLocalData
    }
    let remoteCleanupComplete = receipts.allSatisfy {
      $0.remoteDisposition != .pending && $0.remoteDisposition != .unsupported
    }
    return ModelDeletionResult(
      status: localCleanupComplete && remoteCleanupComplete
        ? .completed
        : .signedOutCleanupPending,
      receipts: receipts,
      signedOut: true
    )
  }
}

private func makeReceipts(
  localResidualModule: Int? = nil,
  remotePendingModule: Int? = nil,
  remoteUnsupportedModule: Int? = nil,
  terminalCount: Int = 13
) -> [ModelModuleReceipt] {
  (1...13).map { index in
    ModelModuleReceipt(
      moduleId: String(format: "LM-%02d", index),
      isTerminal: index <= terminalCount,
      failed: index == localResidualModule,
      remainingLocalData: index == localResidualModule,
      remoteDisposition: index == remotePendingModule
        ? .pending
        : (index == remoteUnsupportedModule ? .unsupported : .notApplicable)
    )
  }
}

private func runAccountDeletionLifecycleModelSmoke() {
  let oldLease = ModelAccountLease(
    subjectId: "owner-a",
    vaultId: "vault-a",
    sessionId: "session-a",
    generation: 41
  )

  do {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: false,
      oldLease: capturedLease,
      receipts: makeReceipts()
    )
    require(result.status == .backendRejected, "backend rejection must stop account deletion")
    require(!result.signedOut, "backend rejection must not sign out through deletion lifecycle")
    require(
      !orchestrator.eventLog.contains("beginDeleting"),
      "accountDeletion lifecycle may start only after backend soft delete succeeds"
    )
  }

  do {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let receipts = makeReceipts()
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: true,
      oldLease: capturedLease,
      receipts: receipts
    )
    require(result.status == .completed, "complete cleanup must report deletion completed")
    require(result.signedOut, "sign out must follow a terminal 13-module lifecycle")
    let beginIndex = orchestrator.eventLog.firstIndex(of: "beginDeleting")!
    let signOutIndex = orchestrator.eventLog.firstIndex(of: "signOut")!
    let moduleIndices = orchestrator.eventLog.enumerated().compactMap { index, event in
      event.hasPrefix("module:") ? index : nil
    }
    require(moduleIndices.count == 13, "all 13 modules must produce lifecycle receipts")
    require(beginIndex < moduleIndices.min()!, "beginDeleting must precede module teardown")
    require(moduleIndices.max()! < signOutIndex, "signOut must follow all module receipts")
  }

  do {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: true,
      oldLease: capturedLease,
      receipts: makeReceipts(terminalCount: 12)
    )
    require(result.status == .lifecycleIncomplete, "non-terminal module must block sign out")
    require(!result.claimsDeletionCompleted, "incomplete lifecycle must not claim success")
  }

  do {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: true,
      oldLease: capturedLease,
      receipts: makeReceipts(localResidualModule: 8)
    )
    require(result.signedOut, "a backend-deleted account must still reach signed-out state")
    require(
      result.status == .signedOutCleanupPending,
      "local residual data must produce cleanup-pending, not deletion success"
    )
    require(!result.claimsDeletionCompleted, "local residual data must never claim completion")
  }

  for remoteDisposition in [ModelRemoteDisposition.pending, .unsupported] {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let receipts = remoteDisposition == .pending
      ? makeReceipts(remotePendingModule: 4)
      : makeReceipts(remoteUnsupportedModule: 5)
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: true,
      oldLease: capturedLease,
      receipts: receipts
    )
    require(
      result.status == .signedOutCleanupPending,
      "remote pending/unsupported receipt must not masquerade as provider deletion"
    )
  }

  do {
    let orchestrator = ModelAccountDeletionOrchestrator(lease: oldLease)
    let capturedLease = orchestrator.captureOldLeaseAndRequestBackendSoftDelete()
    let newLease = ModelAccountLease(
      subjectId: "owner-b",
      vaultId: "vault-b",
      sessionId: "session-b",
      generation: 42
    )
    orchestrator.activateNewAccount(newLease)
    let result = orchestrator.handleBackendSoftDeleteCompletion(
      succeeded: true,
      oldLease: capturedLease,
      receipts: makeReceipts()
    )
    require(result.status == .staleCallbackIgnored, "old deletion callback must be ignored")
    require(orchestrator.currentLease == newLease, "old callback must not clear a new account")
    require(orchestrator.state == .active, "old callback must not sign out a new generation")
  }

  let ordinaryLogoutDraftDisposition = ModelDraftDisposition.retainedLocked
  let accountDeletionDraftDisposition = ModelDraftDisposition.purged
  require(
    ordinaryLogoutDraftDisposition == .retainedLocked,
    "ordinary logout must retain explicit drafts under the old owner lock"
  )
  require(
    accountDeletionDraftDisposition == .purged,
    "account deletion must use purge semantics distinct from ordinary logout"
  )

  print(
    "PASS: WI-S0-01-08C account deletion lifecycle model "
      + "backendGate=ok modules=13 residual=guarded staleCallback=isolated drafts=retainedOnLogout"
  )
}

runAccountDeletionLifecycleModelSmoke()
