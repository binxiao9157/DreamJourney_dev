import Foundation

struct CareDashboardLocalSnapshot {
    let snapshot: CareSignalSnapshot
    let eligibleUserTurnCount: Int
}

final class CareDashboardSnapshotPublisher {
    static let shared = CareDashboardSnapshotPublisher()

    enum PublishFailure: LocalizedError, Equatable {
        case noEligibleCareTurns
        case backendNotConfigured
        case missingCurrentUser
        case missingCareOwner
        case ownerMismatch

        var errorDescription: String? {
            switch self {
            case .noEligibleCareTurns:
                return "关怀快照没有可发布的真实亲友范围发言"
            case .backendNotConfigured:
                return "关怀快照后端未配置"
            case .missingCurrentUser:
                return "关怀快照缺少当前用户身份"
            case .missingCareOwner:
                return "关怀快照缺少被关怀长辈身份"
            case .ownerMismatch:
                return "关怀快照只能由被关怀长辈本人发布"
            }
        }
    }

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
        let now = Date()
        let preliminarySnapshot = analyzer.analyze(turns: eligibleTurns, now: now)
        let eligibleUserTurnCount = preliminarySnapshot.userTurnCount
        let sourceAudit = CareSignalSourceAudit(
            authorizedScopeText: "亲友范围",
            sourceKindText: "本机授权对话",
            eligibleUserTurnCount: eligibleUserTurnCount,
            contentRedactionText: "脱敏聚合",
            viewerFamilyMemberID: viewerFamilyMemberID
        )
        return CareDashboardLocalSnapshot(
            snapshot: analyzer.analyze(turns: eligibleTurns, now: now, sourceAudit: sourceAudit),
            eligibleUserTurnCount: eligibleUserTurnCount
        )
    }

    func publishLatestLocalSnapshotAfterConversationEnd() {
        let turns = ConversationMemoryManager.shared.getCareDashboardTranscriptHistory()
        let targets = backgroundPublishTargets(from: turns)
        guard !targets.isEmpty else { return }

        for viewerFamilyMemberID in targets {
            let local = makeLocalSnapshot(
                from: turns,
                viewerFamilyMemberID: viewerFamilyMemberID
            )
            publish(snapshot: local.snapshot, viewerFamilyMemberID: viewerFamilyMemberID) { result in
                let targetDescription = viewerFamilyMemberID ?? "all-family"
                switch result {
                case .success:
                    print("[CareDashboard] 对话结束后已后台发布亲友关怀快照 target=\(targetDescription)")
                case .failure(let error):
                    print("[CareDashboard] 对话结束后关怀快照发布失败 target=\(targetDescription): \(error.localizedDescription)")
                }
            }
        }
    }

    func backgroundPublishTargets(from turns: [ConversationTurn]) -> [String?] {
        var targets: [String?] = [nil]
        var seenMemberIDs: Set<String> = []

        for turn in turns where turn.privacyMetadata.scope == .familyCircle {
            let visibility = turn.privacyMetadata.familyVisibility
            guard !visibility.includesAllMembers else { continue }
            for memberID in visibility.allowedMemberIDs where !seenMemberIDs.contains(memberID) {
                seenMemberIDs.insert(memberID)
                targets.append(memberID)
            }
        }

        return targets
    }

    func publish(
        snapshot: CareSignalSnapshot,
        viewerFamilyMemberID: String?,
        completion: @escaping (Result<DreamJourneyBackendClient.CareSnapshotResponse, Error>) -> Void = { _ in }
    ) {
        guard snapshot.userTurnCount > 0 else {
            completion(.failure(PublishFailure.noEligibleCareTurns))
            return
        }
        guard DreamJourneyBackendClient.shared.isConfigured else {
            completion(.failure(PublishFailure.backendNotConfigured))
            return
        }
        guard let currentUserId = UserManager.shared.currentUser?.id else {
            completion(.failure(PublishFailure.missingCurrentUser))
            return
        }
        guard let ownerUserId = FamilyRepository.shared.careOwnerUserID(for: viewerFamilyMemberID) else {
            completion(.failure(PublishFailure.missingCareOwner))
            return
        }
        guard ownerUserId == currentUserId else {
            completion(.failure(PublishFailure.ownerMismatch))
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
