#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(source: str, start: str, end: str) -> str:
    start_index = source.index(start)
    end_index = source.index(end, start_index)
    return source[start_index:end_index]


safety_policy = read("DreamJourney/Sources/Modules/Echo/EchoSafetyPolicy.swift")
view_model = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
view_controller = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
backend_client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
delayed_reply_store = read("DreamJourney/Sources/Services/EchoDelayedReplyStore.swift")
dialog_engine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
project = read("DreamJourney.xcodeproj/project.pbxproj")

for token in [
    "case neutralSafety(EchoSafetyDecision)",
    "EchoSafetyPolicy.evaluate(text: normalizedText)",
    "var isNeutralSafetyMode: Bool",
    "var neutralSafetyDecision: EchoSafetyDecision?",
]:
    require(token in view_model, f"EchoViewModel missing safety integration: {token}")

finish_user_voice = section(view_model, "func finishUserVoice(text: String)", "func receiveAIReply")
for side_effect in [
    "memoryManager.refreshForCurrentContext()",
    "memoryManager.recordUserTurn",
    "EchoReplyPacingPolicy.shouldWaitForReply",
    "EchoDelayedReplyStore.shared.save",
]:
    require(
        finish_user_voice.index("EchoSafetyPolicy.evaluate") < finish_user_voice.index(side_effect),
        f"safety evaluation must precede side effect: {side_effect}",
    )
require(
    "enterNeutralSafetyMode(safetyDecision" in finish_user_voice,
    "crisis decision must enter neutralSafety before ordinary turn handling",
)

view_model_safety = section(view_model, "private func enterNeutralSafetyMode", "\n    }")
for token in [
    "cancelPendingDelayedReply()",
    "EchoDelayedReplyStore.shared.clear()",
    "updateState(.neutralSafety(decision))",
]:
    require(token in view_model_safety, f"neutralSafety cleanup missing: {token}")
require(
    "guard EchoSafetyPolicy.evaluate(text: userText).allowsDelayedReply" in view_model,
    "delayed-reply pacing must independently reject safety-diverted text",
)

asr_final = section(view_controller, "func onASRResult(text: String, isFinal: Bool)", "func onTTSStarted")
safety_branch_index = asr_final.index("if let safetyDecision = self.viewModel.neutralSafetyDecision")
require(
    asr_final.index("self.viewModel.finishUserVoice(text: text)") < safety_branch_index,
    "ASR final must evaluate through EchoViewModel before branching",
)
for side_effect in [
    "preserveTencentProviderSessionAfterLocalDialogStop",
    "digitalHumanConversation.startUserTurn",
    "recordEchoContextPacketForUserTurn",
    "scheduleDelayedReplyNotificationIfNeeded",
]:
    require(
        safety_branch_index < asr_final.index(side_effect),
        f"ASR safety branch must precede effect: {side_effect}",
    )

controller_safety = section(view_controller, "private func enterNeutralSafetyMode", "private func beginDelayedReplyWait")
for token in [
    "cancelPendingDelayedReply()",
    "invalidateDigitalHumanLifecycle(reason: \"neutralSafety\")",
    "interruptDigitalHumanPlayback(reason: \"neutralSafety\")",
    "DialogEngineManager.shared.interruptAI()",
    "DialogEngineManager.shared.stopDialog()",
]:
    require(token in controller_safety, f"controller safety shutdown missing: {token}")
for token in [
    "case .neutralSafety(let decision)",
    "decision.responseText",
    "!self.viewModel.isNeutralSafetyMode",
]:
    require(token in view_controller, f"Echo UI safety state/callback guard missing: {token}")

for token in [
    '"自己 · AI 助手"',
    '"\\(context.resolvedDisplayName) · AI 数字分身"',
    "EchoAIIdentityDisclosure.persistent.label",
]:
    require(token in view_controller, f"persistent self/family AI disclosure missing: {token}")
require("AI 助手生成，非真人本人" in safety_policy, "visible disclosure must identify AI and non-person status")
require("你不是机器人" not in dialog_engine, "dialog prompt must not deny AI identity")
require("AI 助手" in dialog_engine and "不是真人" in dialog_engine, "dialog prompt must disclose AI/non-person identity")

delayed_request = section(backend_client, "func scheduleEchoDelayedReplyPush", "private func requestJSON")
require("rawTranscript: String" in delayed_request, "delayed reply request must accept rawTranscript")
require('"rawTranscript": rawTranscript' in delayed_request, "delayed reply payload must send rawTranscript")
require("rawTranscript" not in delayed_reply_store, "rawTranscript must not be added to the persisted delayed-reply model")
for persistence_token in ["UserDefaults", ".write(", "data.write", "EchoDelayedReplyStore"]:
    require(persistence_token not in delayed_request, f"rawTranscript request path must remain transient: {persistence_token}")
require("scheduleDelayedReplyNotificationIfNeeded(rawTranscript: text)" in asr_final, "ASR transcript must flow directly to scheduling")

refresh_failure = section(
    app_delegate,
    "private func invalidateReleasePolicyAuthorityAfterRefreshFailure",
    "private func syncStoredPushDeviceTokenIfPossible",
)
for token in [
    "invalidateCachedReleasePolicyAuthority",
    "FeatureGateService.shared.invalidateCapturedRoutes()",
    "RuntimeCapabilitySnapshotStore.shared.invalidate()",
]:
    require(token in refresh_failure, f"release refresh failure invalidation missing: {token}")
require(
    "self.invalidateReleasePolicyAuthorityAfterRefreshFailure(error)" in app_delegate,
    "release refresh failure must invoke fail-closed invalidation",
)
require(
    "releasePolicyStore.remove(scope: releasePolicyCacheScope" in backend_client,
    "backend client must remove current account/build release authority",
)

require(
    project.count("/* EchoSafetyPolicy.swift in Sources */") == 2,
    "EchoSafetyPolicy.swift must have one build-file declaration and one Sources membership",
)
require(
    sum(
        "/* EchoSafetyPolicy.swift */" in line and "PBXFileReference" in line
        for line in project.splitlines()
    ) == 1,
    "EchoSafetyPolicy.swift must have one file reference",
)
require(
    sum(
        line.strip().endswith("/* EchoSafetyPolicy.swift */,")
        for line in project.splitlines()
    ) == 1,
    "EchoSafetyPolicy.swift must have one Echo group membership",
)

print("Product V4 WI-S0-06-09 iOS safety integration checks passed")
