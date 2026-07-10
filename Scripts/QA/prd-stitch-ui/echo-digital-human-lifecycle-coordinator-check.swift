import Foundation

@main
enum EchoDigitalHumanLifecycleCoordinatorCheck {
    static func main() {
        let coordinator = DigitalHumanLifecycleCoordinator()

        let firstContextToken = coordinator.token(for: "viewer|self|sunlight")
        require(
            coordinator.isCurrent(firstContextToken, contextKey: "viewer|self|sunlight"),
            "first context token should be current"
        )

        let interactionToken = coordinator.invalidateInteraction(
            contextKey: "viewer|self|sunlight",
            reason: "userBargeIn"
        )
        require(
            !coordinator.isCurrent(firstContextToken, contextKey: "viewer|self|sunlight"),
            "interaction invalidation should reject the previous interaction token"
        )
        require(
            coordinator.isCurrentSession(firstContextToken, contextKey: "viewer|self|sunlight"),
            "interaction invalidation should preserve the current session generation"
        )
        require(
            coordinator.isCurrent(interactionToken, contextKey: "viewer|self|sunlight"),
            "new interaction token should be current"
        )

        let cancellableLease = coordinator.beginBackgroundReleaseLease(
            contextKey: "viewer|self|sunlight"
        )
        require(
            coordinator.isCurrentBackgroundReleaseLease(
                cancellableLease,
                contextKey: "viewer|self|sunlight"
            ),
            "new background lease should be current"
        )
        coordinator.cancelBackgroundReleaseLease()
        require(
            !coordinator.isCurrentBackgroundReleaseLease(
                cancellableLease,
                contextKey: "viewer|self|sunlight"
            ),
            "cancelled background lease should not fire"
        )

        let expiringLease = coordinator.beginBackgroundReleaseLease(
            contextKey: "viewer|self|sunlight"
        )
        let nextContextToken = coordinator.invalidate(
            contextKey: "viewer|family-member|sunlight",
            reason: "contextChanged"
        )
        require(
            !coordinator.isCurrentSession(interactionToken, contextKey: "viewer|family-member|sunlight"),
            "context switch should reject the previous session generation"
        )
        require(
            !coordinator.isCurrentBackgroundReleaseLease(
                expiringLease,
                contextKey: "viewer|family-member|sunlight"
            ),
            "lifecycle invalidation should cancel the previous background lease"
        )
        require(
            coordinator.isCurrent(nextContextToken, contextKey: "viewer|family-member|sunlight"),
            "new context token should be current"
        )

        let pageExitToken = coordinator.invalidate(
            contextKey: "viewer|family-member|sunlight",
            reason: "viewWillDisappear"
        )
        require(
            !coordinator.isCurrentSession(nextContextToken, contextKey: "viewer|family-member|sunlight"),
            "page exit should reject the previous session token"
        )
        require(
            coordinator.isCurrent(pageExitToken, contextKey: "viewer|family-member|sunlight"),
            "page exit should leave only its new generation current"
        )

        print("Echo digital-human lifecycle coordinator check passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Echo digital-human lifecycle coordinator check failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
