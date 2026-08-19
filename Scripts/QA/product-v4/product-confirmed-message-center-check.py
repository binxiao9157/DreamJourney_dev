#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(source: str, needle: str, message: str) -> None:
    if needle not in source:
        raise SystemExit(f"PC-B4 message center check failed: {message} ({needle})")


message_model = read("DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift")
message_runtime = read(
    "DreamJourney/Sources/Modules/Archive/AuthoritativeInAppMessageCenter.swift"
)
backend_client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
launch_registry = read("DreamJourney/Sources/App/FeatureFlagService.swift")
uiqa_runner = read(
    "Scripts/QA/product-v4/run-product-confirmed-message-center-uiqa-smoke.sh"
)

for needle, message in [
    ("final class AuthoritativeInAppMessageCenterStore", "one authoritative state source is required"),
    ("djInAppMessageCenterDidUpdate", "shared unread update notification is required"),
    ("UIApplication.didBecomeActiveNotification", "foreground refresh is required"),
    ("resetsItems && scopeChanged", "same-account refresh must preserve the visible unread state"),
]:
    require(message_runtime, needle, message)

for needle, message in [
    ("BackendInAppMessageCenterPage", "typed backend page contract is required"),
    ("BackendInAppMessageCommandReceipt", "typed command receipt is required"),
    ("case candidateReady", "Candidate messages must be supported"),
    ("case projectionStatus", "projection messages must be supported"),
    ("case authorizationRevoked", "revocation messages must be supported"),
]:
    require(message_model, needle, message)

for needle, message in [
    ("func fetchInAppMessages(", "typed list client is required"),
    ("func markInAppMessageRead(", "single-read command is required"),
    ("func markAllInAppMessagesRead(", "mark-all command is required"),
    ("func deleteReadInAppMessages(", "delete-read command is required"),
    ('hasPrefix("/v2/in-app-messages/")', "message-center requests need an explicit purpose"),
]:
    require(backend_client, needle, message)

for source, surface in [(archive, "Archive"), (echo, "Echo")]:
    require(source, "InAppMessageBellButton", f"{surface} must expose the shared bell")
    require(source, "AuthoritativeInAppMessageCenterStore.shared", f"{surface} must consume the authoritative store")

for needle, message in [
    ("case messageCenter", "Profile needs a message-center row"),
    ('return "消息中心"', "Profile message-center copy is required"),
    ("AuthoritativeInAppMessageCenterStore.shared", "Profile must consume the authoritative store"),
]:
    require(profile, needle, message)

for forbidden, message in [
    ("case .timeLetter:\n            return BackendInAppMessage", "time letters must remain closed"),
    ("case .echoReply:\n            return BackendInAppMessage", "delayed replies must remain closed"),
]:
    if forbidden in message_model:
        raise SystemExit(f"PC-B4 message center check failed: {message}")

for source, needle, message in [
    (
        launch_registry,
        'productConfirmedMessageCenterSmoke = "DJRunProductConfirmedMessageCenterSmoke"',
        "the UIQA scenario must be registered",
    ),
    (
        app_delegate,
        "runProductConfirmedMessageCenterSmoke()",
        "the UIQA scenario must be scheduled",
    ),
    (
        message_runtime,
        "func installUIQASnapshot(",
        "the UIQA scenario needs a provider-free authority snapshot",
    ),
    (
        uiqa_runner,
        '"message-center-accessibility" "accessibility-extra-large"',
        "Dynamic Type UIQA evidence is required",
    ),
    (
        uiqa_runner,
        'SECONDARY_SIMULATOR_NAME="${SECONDARY_SIMULATOR_NAME:-iPhone 17e}"',
        "compact-device UIQA evidence is required",
    ),
]:
    require(source, needle, message)

print("PC-B4 authoritative message center static check passed")
