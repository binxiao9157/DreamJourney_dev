#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body_after(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated body: {marker}")


def main() -> None:
    view_model = VIEW_MODEL.read_text()
    view_controller = VIEW_CONTROLLER.read_text()
    combined = view_model + "\n" + view_controller

    for declaration in (
        "struct EchoDelayedReplyCallsiteContext",
        "final class EchoDelayedReplyCallsiteScopeStore",
        "private(set) var pendingDelayedReplyContext: EchoDelayedReplyCallsiteContext?",
    ):
        require(declaration in view_model, f"callsite scope declaration missing: {declaration}")

    explicit_finish = re.search(
        r"func finishUserVoice\(\s*text: String,\s*accountLease: AccountLease,\s*"
        r"resourceOwnerId: String,\s*roleContextKey: String",
        view_model,
    )
    require(explicit_finish is not None, "finishUserVoice must receive one originating scope")

    explicit_restore = re.search(
        r"func restoreStoredDelayedReplyIfAvailable\(\s*accountLease: AccountLease,\s*"
        r"resourceOwnerId: String,\s*roleContextKey: String,",
        view_model,
    )
    require(explicit_restore is not None, "restore must receive the page lease and role context")

    for snippet in (
        "resourceOwnerId: callsiteContext.resourceOwnerId",
        "operationId: callsiteContext.operationId",
        "accountLease: callsiteContext.accountLease",
    ):
        require(view_model.count(snippet) >= 3, f"explicit delayed-reply scope not propagated: {snippet}")

    arrived = body_after(view_model, "func markStoredDelayedReplyArrived(")
    for snippet in (
        "echoReplyMessageStore.saveArrivedReply(",
        "accountLease: callsiteContext.accountLease",
        "resourceOwnerId: callsiteContext.resourceOwnerId",
        "operationId: callsiteContext.operationId",
    ):
        require(snippet in arrived, f"arrived reply does not preserve origin scope: {snippet}")

    forbidden_patterns = (
        r"EchoDelayedReplyStore\.shared\.save\(delayedReply\)",
        r"EchoDelayedReplyStore\.shared\.load\(\)",
        r"EchoDelayedReplyStore\.shared\.clear\(\)",
        r"EchoDelayedReplyNotificationScheduler\.shared\.cancelPendingDelayedReply\(\)",
        r"EchoReplyMessageStore\.shared\.saveArrivedReply\(\s*id:[\s\S]{0,220}?trigger:[^\n]+\n\s*\)",
    )
    for pattern in forbidden_patterns:
        require(re.search(pattern, combined) is None, f"compatibility wrapper remains: {pattern}")

    schedule = body_after(view_controller, "private func scheduleDelayedReplyNotificationIfNeeded")
    require("capture(forSubjectId:" not in schedule, "schedule must not recapture an account lease")
    for snippet in (
        "viewModel.pendingDelayedReplyContext",
        "resourceOwnerId: callsiteContext.resourceOwnerId",
        "operationId: callsiteContext.operationId",
        "accountLease: callsiteContext.accountLease",
        "validateDelayedReplyCallsiteContext(",
    ):
        require(snippet in schedule, f"schedule callsite drops originating context: {snippet}")

    push = body_after(view_controller, "private func submitDelayedReplyPush(")
    require(
        re.search(
            r"private func submitDelayedReplyPush\([\s\S]{0,240}?"
            r"callsiteContext: EchoDelayedReplyCallsiteContext",
            view_controller,
        )
        is not None,
        "push submission must carry the originating callsite context",
    )
    for snippet in (
        "validateDelayedReplyCallsiteContext(",
        "at: .request",
        "at: .runtime",
    ):
        require(snippet in push, f"push callback is not fenced by origin scope: {snippet}")

    require(
        "private func validateDelayedReplyCallsiteContext(" in view_controller,
        "controller must validate account generation, operation, and role together",
    )
    validation = body_after(view_controller, "private func validateDelayedReplyCallsiteContext(")
    for snippet in (
        "callsiteContext.accountLease == echoAccountLease",
        "viewModel.matchesPendingDelayedReplyContext(callsiteContext)",
        "digitalHumanRuntimeContextKey(for: DigitalHumanContextStore.shared.current)",
        "callsiteContext.roleContextKey",
    ):
        require(snippet in validation, f"callsite validation omits: {snippet}")

    require(
        "viewModel.finishUserVoice(\n                text: text," in view_controller,
        "ASR path must pass the captured Echo lease explicitly",
    )
    require(
        re.search(
            r"viewModel\.restoreStoredDelayedReplyIfAvailable\(\s*accountLease:",
            view_controller,
        )
        is not None,
        "page restore must pass the captured Echo lease explicitly",
    )

    print("Echo delayed reply callsite static check passed")


if __name__ == "__main__":
    main()
