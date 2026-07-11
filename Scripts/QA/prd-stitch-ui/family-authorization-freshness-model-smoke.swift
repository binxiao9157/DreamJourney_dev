import Foundation

@main
enum FamilyAuthorizationFreshnessModelSmoke {
    static func main() {
        var freshness = FamilyAuthorizationFreshness()
        require(!freshness.allowsPreviouslyVerifiedUse, "unknown state must deny family authorization")
        require(!freshness.allowsKnowledgeSyncSnapshot, "unknown state must deny family sync")

        let initialGeneration = freshness.generation
        freshness.beginRefresh()
        let refreshA = freshness.generation
        require(freshness.generation != initialGeneration, "refresh start must invalidate async generations")
        require(!freshness.allowsKnowledgeSyncSnapshot, "refreshing must pause family sync")

        let userGeneration = UUID()
        freshness.beginRefresh()
        let refreshB = freshness.generation
        require(
            !FamilyAuthorizationRefreshResponsePolicy.accepts(
                capturedOwnerUserId: "owner",
                currentOwnerUserId: "owner",
                capturedUserGeneration: userGeneration,
                currentUserGeneration: userGeneration,
                capturedRefreshGeneration: refreshA,
                currentRefreshGeneration: refreshB
            ),
            "refresh A response must be stale after refresh B starts"
        )
        require(
            FamilyAuthorizationRefreshResponsePolicy.accepts(
                capturedOwnerUserId: "owner",
                currentOwnerUserId: "owner",
                capturedUserGeneration: userGeneration,
                currentUserGeneration: userGeneration,
                capturedRefreshGeneration: refreshB,
                currentRefreshGeneration: refreshB
            ),
            "the latest refresh response must be accepted"
        )

        freshness.completeSuccess(at: Date(timeIntervalSince1970: 100))
        require(
            !FamilyAuthorizationRefreshResponsePolicy.accepts(
                capturedOwnerUserId: "owner",
                currentOwnerUserId: "owner",
                capturedUserGeneration: userGeneration,
                currentUserGeneration: userGeneration,
                capturedRefreshGeneration: refreshB,
                currentRefreshGeneration: freshness.generation
            ),
            "a duplicate callback must be stale after the latest refresh commits"
        )
        require(freshness.allowsPreviouslyVerifiedUse, "successful refresh must allow accepted family use")
        require(freshness.allowsKnowledgeSyncSnapshot, "successful refresh must allow family sync")

        let readyGeneration = freshness.generation
        freshness.beginRefresh()
        require(freshness.allowsPreviouslyVerifiedUse, "refresh may retain the last verified UI/Echo snapshot")
        require(!freshness.allowsKnowledgeSyncSnapshot, "refresh must still pause new family sync")
        require(freshness.generation != readyGeneration, "refresh must invalidate old async callbacks")

        freshness.completeFailure()
        require(!freshness.allowsPreviouslyVerifiedUse, "failed refresh must revoke stale family authorization")
        require(!freshness.allowsKnowledgeSyncSnapshot, "failed refresh must keep family sync denied")

        freshness.completeSuccess()
        freshness.reset()
        require(freshness.state == .unknown, "account reset must return to unknown")
        require(!freshness.hasVerifiedSnapshot, "account reset must discard verified snapshot state")

        print("Family authorization freshness model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Family authorization freshness model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
