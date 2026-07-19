#!/usr/bin/env python3
"""Static and model gate for WI-S0-01-08B account lifecycle teardown."""

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def declaration_body(source: str, declaration: str) -> str:
    for keyword in ("final class", "class", "struct", "enum"):
        marker = f"{keyword} {declaration}"
        start = source.find(marker)
        if start >= 0:
            break
    else:
        raise AssertionError(f"missing declaration: {declaration}")
    return braced_body(source, source.find("{", start))


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    return braced_body(source, source.find("{", start))


def braced_body(source: str, opening_brace: int) -> str:
    require(opening_brace >= 0, "declaration has no body")
    depth = 0
    for index in range(opening_brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening_brace + 1:index]
    raise AssertionError("unterminated declaration")


def require_exact_lease_match(body: str, contract: str) -> None:
    for field in ("subjectId", "vaultId", "generation", "generationId", "authorityEpoch"):
        require(field in body, f"{contract} must match old lease field: {field}")


def static_check() -> None:
    delayed = read("DreamJourney/Sources/Services/EchoDelayedReplyStore.swift")
    scheduler = read(
        "DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift"
    )
    messages = read("DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift")
    push = read("DreamJourney/Sources/Services/PushDeviceTokenStore.swift")
    widget = read("DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift")
    lease = read("DreamJourney/Sources/App/AccountLease.swift")
    lifecycle = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")

    delayed_teardown = function_body(
        declaration_body(delayed, "EchoDelayedReplyStore"),
        "func teardownForAccountLifecycle(oldAccountLease:",
    )
    require("accountLeaseRuntime" not in delayed_teardown, "delayed teardown must not validate revoked runtime")
    require("dictionaryRepresentation" in delayed_teardown, "delayed teardown must enumerate old scoped artifacts")
    require("indexPrefix" in delayed_teardown, "delayed teardown must clear the operation index")
    require("EchoDelayedReplyEnvelope" in delayed_teardown, "delayed projection envelope must be verified")
    require("EchoDelayedReplyOperationIndexEnvelope" in delayed_teardown, "delayed index envelope must be verified")
    require_exact_lease_match(
        declaration_body(delayed, "EchoDelayedReplyEnvelope"),
        "delayed reply envelope",
    )
    require_exact_lease_match(
        declaration_body(delayed, "EchoDelayedReplyOperationIndexEnvelope"),
        "delayed reply index",
    )

    scheduler_teardown = function_body(
        declaration_body(scheduler, "EchoDelayedReplyNotificationScheduler"),
        "func teardownForAccountLifecycle(",
    )
    require("accountLeaseRuntime" not in scheduler_teardown, "notification teardown must use captured old lease")
    require(
        scheduler_teardown.count("getPendingNotificationRequests") >= 2,
        "notification teardown must verify removal before reporting success",
    )
    require("completion(false)" in scheduler_teardown, "notification teardown must report failure")
    require("byLifecycleLease" in scheduler_teardown, "notification teardown must filter the old generation")
    notification_match = function_body(scheduler, "private func requestIsOwned(\n        _ request: UNNotificationRequest,\n        byLifecycleLease")
    require_exact_lease_match(notification_match, "notification request")

    helper = function_body(messages, "private func teardownInAppMessageProjections(")
    require("dictionaryRepresentation" in helper, "message teardown must enumerate all old viewer operations")
    require("matchesLifecycleLease" in helper, "message teardown must verify envelope ownership")
    require("accountLeaseRuntime" not in helper, "message teardown must not recapture current runtime")
    require_exact_lease_match(
        declaration_body(messages, "InAppMessageLifecycleEnvelopeHeader"),
        "in-app message envelope",
    )
    aggregate = function_body(
        declaration_body(messages, "InAppMessageLifecycleProjectionStore"),
        "func teardownForAccountLifecycle(oldAccountLease:",
    )
    for surface in (".systemNotice", ".echoReply", ".localState", ".timeLetterMailbox"):
        require(surface in aggregate, f"aggregate message teardown must include {surface}")
    require("clear()" not in aggregate, "aggregate lifecycle path must not call compatibility clear")
    for store_name in ("SystemNoticeMessageStore", "EchoReplyMessageStore"):
        store = declaration_body(messages, store_name)
        teardown = function_body(store, "func teardownForAccountLifecycle(oldAccountLease:")
        require("teardownInAppMessageProjections" in teardown, f"{store_name} must use scoped teardown")
        require("clear()" not in teardown, f"{store_name} lifecycle path must not call compatibility clear")

    push_teardown = function_body(
        declaration_body(push, "PushDeviceTokenStore"),
        "func teardownForAccountLifecycle(oldAccountLease:",
    )
    require("matchesLifecycleLease" in push_teardown, "push teardown must verify the old registration envelope")
    require("deviceTokenBeforeTeardown" in push_teardown, "push teardown must preserve the device APNs token")
    require("removeObject(forKey: deviceTokenKey)" not in push_teardown, "lifecycle teardown must not delete APNs token")
    require("accountLeaseRuntime" not in push_teardown, "push teardown must not validate revoked runtime")
    require_exact_lease_match(
        declaration_body(push, "PushDeviceTokenRegistrationEnvelope"),
        "push registration envelope",
    )

    route_inbox = declaration_body(lease, "NotificationRuntimeRouteInbox")
    route_teardown = function_body(
        route_inbox,
        "func teardownForAccountLifecycle(oldAccountLease:",
    )
    require(
        "payload.matches(oldAccountLease)" in route_teardown,
        "route inbox teardown must retain only non-old-generation routes",
    )
    lifecycle_teardown = function_body(
        lifecycle,
        "private static func teardownMessageNotificationEffects(",
    )
    require(
        "NotificationRuntimeRouteInbox.shared.teardownForAccountLifecycle" in lifecycle_teardown,
        "message lifecycle teardown must clear pending runtime routes",
    )

    widget_teardown = function_body(
        declaration_body(widget, "KnowledgeWidgetSnapshotStore"),
        "func teardownForAccountLifecycle(oldAccountLease:",
    )
    require("KnowledgeWidgetProjectionOwnerEnvelope" in widget, "widget must persist generation ownership evidence")
    require("matchesLifecycleLease" in widget_teardown, "widget teardown must verify old projection ownership")
    require("snapshot?.ownerDigest" in widget_teardown, "widget teardown must verify snapshot owner digest")
    require("timelineReloader()" in widget_teardown, "widget teardown must reload its timeline")
    require("accountLeaseRuntime" not in widget_teardown, "widget teardown must not validate revoked runtime")
    require_exact_lease_match(
        declaration_body(widget, "KnowledgeWidgetProjectionOwnerEnvelope"),
        "widget projection envelope",
    )


@dataclass(frozen=True)
class Lease:
    subject: str
    vault: str
    generation: int
    generation_id: str
    authority_epoch: str


@dataclass(frozen=True)
class Artifact:
    kind: str
    lease: Lease


def teardown_owned(
    artifacts: List[Artifact], old_lease: Optional[Lease]
) -> Tuple[bool, List[Artifact]]:
    if old_lease is None:
        return False, artifacts
    return True, [artifact for artifact in artifacts if artifact.lease != old_lease]


def model_check() -> None:
    old = Lease("owner-a", "vault-a", 7, "generation-a", "epoch-a")
    refreshed = Lease("owner-a", "vault-a", 8, "generation-b", "epoch-b")
    other = Lease("owner-b", "vault-b", 2, "generation-c", "epoch-c")

    artifacts = [
        Artifact("delayed-projection", old),
        Artifact("delayed-index", old),
        Artifact("local-notification", old),
        Artifact("system-notice", old),
        Artifact("echo-reply", old),
        Artifact("message-local-state", old),
        Artifact("time-letter-mailbox", old),
        Artifact("notification-runtime-route", old),
        Artifact("same-subject-new-generation", refreshed),
        Artifact("other-owner", other),
    ]
    succeeded, remaining = teardown_owned(artifacts, old)
    require(succeeded, "captured old lease teardown must succeed")
    require(all(item.lease != old for item in remaining), "all old generation artifacts must be removed")
    require(Artifact("same-subject-new-generation", refreshed) in remaining, "new generation must survive")
    require(Artifact("other-owner", other) in remaining, "other owner must survive")

    missing_succeeded, unchanged = teardown_owned(artifacts, None)
    require(not missing_succeeded, "missing captured lease must be distinguishable as failure")
    require(unchanged == artifacts, "missing captured lease must not remove data")

    local_apns_token = "device-token-remains"
    push_registration = Artifact("push-registration", old)
    push_succeeded, push_remaining = teardown_owned([push_registration], old)
    require(push_succeeded and not push_remaining, "old push registration must be removed")
    require(local_apns_token == "device-token-remains", "device APNs token must remain available")

    new_push_registration = Artifact("push-registration", refreshed)
    _, new_push_remaining = teardown_owned([new_push_registration], old)
    require(new_push_remaining == [new_push_registration], "new account push registration must survive")

    widget_owner_evidence: Optional[Lease] = old
    require(widget_owner_evidence == old, "widget old-generation evidence must permit teardown")
    widget_owner_evidence = refreshed
    require(widget_owner_evidence != old, "widget new-generation evidence must prevent teardown")
    widget_owner_evidence = None
    require(widget_owner_evidence != old, "widget without ownership evidence must fail closed")


def main() -> None:
    static_check()
    model_check()
    print("PASS: WI-S0-01-08B message/notification/push/widget static check")
    print("PASS: WI-S0-01-08B old-lease teardown model")


if __name__ == "__main__":
    main()
