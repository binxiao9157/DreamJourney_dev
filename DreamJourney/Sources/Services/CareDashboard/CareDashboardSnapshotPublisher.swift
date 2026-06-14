import Foundation

struct CareDashboardLocalSnapshot {
    let snapshot: CareSignalSnapshot
    let eligibleUserTurnCount: Int
}

final class CareDashboardSnapshotPublisher {
    static let shared = CareDashboardSnapshotPublisher()

    private let analyzer: CareSignalAnalyzer

    init(analyzer: CareSignalAnalyzer = CareSignalAnalyzer()) {
        self.analyzer = analyzer
    }

    func makeLocalSnapshot(
        from turns: [ConversationTurn],
        viewerFamilyMemberID: String? = nil
    ) -> CareDashboardLocalSnapshot {
        let eligibleTurns = CareDashboardInputPolicy.eligibleInputTurns(
            from: turns,
            viewerFamilyMemberID: viewerFamilyMemberID
        )
        return CareDashboardLocalSnapshot(
            snapshot: analyzer.analyze(turns: eligibleTurns),
            eligibleUserTurnCount: eligibleTurns.filter { $0.role.lowercased() == "user" }.count
        )
    }

    func publishLatestLocalSnapshotAfterConversationEnd() {
        let local = makeLocalSnapshot(
            from: ConversationMemoryManager.shared.getCareDashboardTranscriptHistory()
        )
        publish(snapshot: local.snapshot, viewerFamilyMemberID: nil) { result in
            switch result {
            case .success:
                print("[CareDashboard] 对话结束后已后台发布亲友关怀快照")
            case .failure(let error):
                print("[CareDashboard] 对话结束后关怀快照发布失败: \(error.localizedDescription)")
            }
        }
    }

    func publish(
        snapshot: CareSignalSnapshot,
        viewerFamilyMemberID: String?,
        completion: @escaping (Result<DreamJourneyBackendClient.CareSnapshotResponse, Error>) -> Void = { _ in }
    ) {
        guard snapshot.userTurnCount > 0,
              DreamJourneyBackendClient.shared.isConfigured,
              let currentUserId = UserManager.shared.currentUser?.id,
              let ownerUserId = FamilyRepository.shared.careOwnerUserID(for: viewerFamilyMemberID),
              ownerUserId == currentUserId else {
            return
        }
        DreamJourneyBackendClient.shared.syncCareSnapshot(
            userId: ownerUserId,
            viewerFamilyMemberID: viewerFamilyMemberID,
            snapshot: snapshot,
            completion: completion
        )
    }
}
