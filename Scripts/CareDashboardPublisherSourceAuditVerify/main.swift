import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("CareDashboardPublisherSourceAudit verification failed: \(message)\n", stderr)
        exit(1)
    }
}

struct BackendUser {
    let id: String
}

final class UserManager {
    static let shared = UserManager()
    var currentUser: BackendUser? = BackendUser(id: "owner")
}

final class FamilyRepository {
    static let shared = FamilyRepository()

    func careOwnerUserID(for viewerFamilyMemberID: String?) -> String? {
        "owner"
    }
}

final class DreamJourneyBackendClient {
    struct CareSnapshotResponse {}

    static let shared = DreamJourneyBackendClient()
    var isConfigured = false

    func syncCareSnapshot(
        userId: String,
        viewerFamilyMemberID: String?,
        snapshot: CareSignalSnapshot,
        completion: @escaping (Result<CareSnapshotResponse, Error>) -> Void
    ) {}
}

final class ConversationMemoryManager {
    static let shared = ConversationMemoryManager()

    func getCareDashboardTranscriptHistory() -> [ConversationTurn] {
        []
    }
}

let now = Date()
let familyScope = MemoryPrivacyMetadata(scope: .familyCircle)
let localOnly = MemoryPrivacyMetadata(scope: .localOnly)
let turns = [
    ConversationTurn(
        role: "user",
        text: "三十天前说过睡不好，但不应该进入当前七天关怀审计。",
        timestamp: now.addingTimeInterval(-30 * 24 * 60 * 60),
        privacyMetadata: familyScope
    ),
    ConversationTurn(
        role: "user",
        text: "今天睡得还可以，下午散步半小时。",
        timestamp: now.addingTimeInterval(-60),
        privacyMetadata: familyScope
    ),
    ConversationTurn(
        role: "user",
        text: "本机私密内容不应该进入关怀审计。",
        timestamp: now.addingTimeInterval(-30),
        privacyMetadata: localOnly
    ),
]

let localSnapshot = CareDashboardSnapshotPublisher().makeLocalSnapshot(from: turns)
let auditCount = localSnapshot.snapshot.sourceAudit?.eligibleUserTurnCount

require(localSnapshot.snapshot.userTurnCount == 1, "care snapshot should only analyze recent family-circle user turns")
require(localSnapshot.eligibleUserTurnCount == 1, "local snapshot result should report only recent eligible user turns")
require(auditCount == 1, "source audit should count the same recent eligible user turns used by analysis")
require(
    localSnapshot.snapshot.sourceAudit?.displaySummary.contains("可用发言 1 轮") == true,
    "source audit display summary should not overstate stale authorized turns"
)

var didPublishCompletion = false
var didReportPublishFailure = false
CareDashboardSnapshotPublisher().publish(
    snapshot: localSnapshot.snapshot,
    viewerFamilyMemberID: nil
) { result in
    didPublishCompletion = true
    if case .failure = result {
        didReportPublishFailure = true
    }
}
require(didPublishCompletion, "care dashboard publish should call completion when backend publish is skipped")
require(didReportPublishFailure, "care dashboard publish should report skipped backend publishing as a failure")

let daughterOnlyScope = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_daughter"])
)
let sonOnlyScope = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_son"])
)
let selectedOnlyTargets = CareDashboardSnapshotPublisher().backgroundPublishTargets(from: [
    ConversationTurn(role: "user", text: "这句话只给女儿看。", timestamp: now, privacyMetadata: daughterOnlyScope),
    ConversationTurn(role: "user", text: "这句话只给儿子看。", timestamp: now, privacyMetadata: sonOnlyScope),
])
require(
    selectedOnlyTargets == ["fm_daughter", "fm_son"],
    "selected-member-only care turns should not publish an empty all-family snapshot"
)

let mixedTargets = CareDashboardSnapshotPublisher().backgroundPublishTargets(from: [
    ConversationTurn(role: "user", text: "这句话全体亲友可见。", timestamp: now, privacyMetadata: familyScope),
    ConversationTurn(role: "user", text: "这句话只给女儿看。", timestamp: now, privacyMetadata: daughterOnlyScope),
])
require(
    mixedTargets == [nil, "fm_daughter"],
    "all-family publish target should appear only when all-family visible care input exists"
)

print("CareDashboardPublisherSourceAudit verification passed")
