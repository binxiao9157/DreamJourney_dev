#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


feature_flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
runtime = read("DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift")
archive_controller = read(
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
)
archive_repository = read(
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"
)
echo_controller = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")


checks = {
    "dedicated delayed-reply feature": "case echoDelayedReplies" in feature_flags,
    "time letters are a product-closed client feature": (
        ".timeLetters," in client.split("productClosedFeatures", 1)[1].split("]", 1)[0]
    ),
    "delayed replies are a product-closed client feature": (
        ".echoDelayedReplies," in client.split("productClosedFeatures", 1)[1].split("]", 1)[0]
    ),
    "client route inventory separates delayed replies from Echo": (
        'normalizedPath.hasPrefix("/echo/delayed-replies") { return .echoDelayedReplies }'
        in client
    ),
    "runtime parses both closed capabilities": (
        "case timeLetters" in runtime and "case echoDelayedReplies" in runtime
    ),
    "ordinary Echo explicitly disables delayed reply scheduling": (
        "allowsDelayedReply: isEchoDelayedReplyProductEnabled" in echo_controller
        and "allowsDelayedReply: self.isEchoDelayedReplyProductEnabled" in echo_controller
    ),
    "ordinary Echo does not restore a closed wait state": (
        "isEchoDelayedReplyProductEnabled" in echo_controller
        and "refreshDelayedReplyAnswerReconciliation" in echo_controller
    ),
    "push scheduling is fail-closed in the client": (
        "guard FeatureGateService.shared.isServerPolicyManagedRouteAllowed(.echoDelayedReplies)"
        in client
    ),
    "ordinary message center excludes closed message kinds": (
        "includeTimeLetters: false" in archive_controller
        and "includeEchoReplies: false" in archive_controller
        and "includeTimeLetters: Bool = true" in archive_repository
        and "includeEchoReplies: Bool = true" in archive_repository
    ),
    "ordinary time-letter creation stays absent": "isTimeLettersEnabled: false"
    in archive_controller,
    "ordinary push registration remains available": "func registerPushDeviceToken("
    in client,
    "family/care/system message providers remain wired": all(
        token in archive_controller
        for token in (
            "familyInvitationSources:",
            "careSignalSources:",
            "systemNoticeSources:",
        )
    ),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("PC-00-02 closure check failed: " + "; ".join(failed))

print("PC-00-02 iOS time-letter/delayed-reply closure check passed")
