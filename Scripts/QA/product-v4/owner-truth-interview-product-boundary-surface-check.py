#!/usr/bin/env python3
"""Guard the released Owner Truth interview-boundary product surface."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SURFACE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
PRODUCT_SMOKE = ROOT / (
    "Scripts/QA/prd-stitch-ui/"
    "run-owner-truth-interview-natural-input-product-surface-smoke.sh"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing surface: {marker}")
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
    for path in (SURFACE, PRODUCT_SMOKE):
        require(path.is_file(), f"missing product boundary artifact: {path}")

    surface = SURFACE.read_text(encoding="utf-8")
    smoke = PRODUCT_SMOKE.read_text(encoding="utf-8")
    natural_input_start = surface.find("final class OwnerTruthInterviewNaturalInputViewController")
    require(natural_input_start >= 0, "missing natural-input product surface")
    natural_input_surface = surface[natural_input_start:]
    configure_view = body(natural_input_surface, "private func configureView()")
    configure_boundary = body(natural_input_surface, "private func configureBoundaryControls()")
    submit_boundary = body(natural_input_surface, "private func submitBoundary(")
    restore_do_not_ask = body(natural_input_surface, "@objc private func restoreDoNotAskTapped()")
    restore_cooldown = body(natural_input_surface, "@objc private func restoreCooldownTapped()")
    topic_switch = body(natural_input_surface, "@objc private func topicSwitchTapped()")
    pacing = body(natural_input_surface, "private func submitPacing(")

    for snippet in (
        "private let productBoundaryActionsRow",
        "owner-truth-interview-boundary-skip-once",
        "owner-truth-interview-boundary-cooldown",
        "owner-truth-interview-boundary-do-not-ask",
        "owner-truth-interview-boundary-restore-do-not-ask",
        '"这次先跳过"',
        '"以后再聊"',
        '"不再问"',
    ):
        require(
            snippet in natural_input_surface,
            f"missing product boundary control: {snippet}",
        )

    for snippet in (
        "productBoundaryActionsRow.distribution = .fillEqually",
        "boundaryActionsStack.addArrangedSubview(productBoundaryActionsRow)",
        "boundaryActionsStack.addArrangedSubview(restoreDoNotAskButton)",
    ):
        require(
            snippet in configure_boundary,
            f"product restore action must remain on a separate row: {snippet}",
        )

    require(
        "case .product:" in configure_boundary,
        "product boundary controls must remain in release builds",
    )
    require(
        "stackView.addArrangedSubview(boundaryActionsStack)" in configure_view,
        "product natural-input sheet must host the boundary control group",
    )
    require(
        "presentation == .qa || presentation == .product" in configure_view,
        "boundary control group must be available to the product presentation",
    )
    require(
        "presentation == .qa || presentation == .product" in submit_boundary,
        "product actions must reuse the lease-fenced boundary command",
    )
    require(
        "presentation == .qa || presentation == .product" in restore_do_not_ask,
        "product do-not-ask recovery must use the typed restore contract",
    )
    require(
        "UIAlertController(" in restore_do_not_ask and "确认恢复" in restore_do_not_ask,
        "product do-not-ask recovery requires an explicit confirmation",
    )
    require(
        "presentation == .qa" in restore_cooldown,
        "cooldown recovery must remain QA-only until the product flow has a policy gate",
    )
    require(
        "presentation == .qa" in topic_switch and "presentation == .qa" in pacing,
        "topic switching and pacing controls must remain QA-only",
    )
    require(
        "setBoundary(.open)" not in natural_input_surface,
        "product surface must not reopen a topic through the generic boundary command",
    )
    for snippet in (
        '"productBoundaryControlsVisible"',
        '"qaOnlyBoundaryControlsHidden"',
        '"releasePolicyBypassedForPreview"',
    ):
        require(snippet in smoke, f"product UIQA smoke missing assertion: {snippet}")
    require(
        "DJEnableOwnerTruthCandidateReviewQA" not in smoke,
        "product UIQA must not depend on the QA-only launch gate",
    )

    print(
        "Owner Truth interview product-boundary surface check passed: "
        "released controls stay lease-fenced and QA-only controls stay hidden"
    )


if __name__ == "__main__":
    main()
