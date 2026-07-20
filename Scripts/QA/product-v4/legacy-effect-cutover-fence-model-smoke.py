#!/usr/bin/env python3
"""Model the G0 cutover fence for one legacy async-effect surface.

This is deliberately a pure model. It cannot enable a worker, issue a direct
dispatch, inspect a host, change a route, or approve a retirement candidate.
It encodes the fail-closed conditions that future G2 cutover evidence must
satisfy for every surface independently.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class CutoverDecision(str, Enum):
    HOLD_LEGACY_STILL_ACTIVE = "hold_legacy_still_active"
    HOLD_SUCCESSOR_NOT_ACTIVE = "hold_successor_not_active"
    HOLD_ZERO_USE_NOT_OBSERVED = "hold_zero_use_not_observed"
    HOLD_RESTORE_REPLAY_NOT_VERIFIED = "hold_restore_replay_not_verified"
    REOPEN_DUPLICATE_AUTHORITY = "reopen_duplicate_authority"
    REOPEN_STALE_LEGACY_CALLBACK = "reopen_stale_legacy_callback"
    REOPEN_UNKNOWN_IN_FLIGHT = "reopen_unknown_in_flight"
    REOPEN_OLD_CLIENT = "reopen_old_client"
    AWAIT_EXTERNAL_APPROVAL = "await_external_approval"
    READY_FOR_SEPARATE_AUTHORIZATION = "ready_for_separate_authorization"


@dataclass(frozen=True)
class CutoverEvidence:
    legacy_direct_effect_active: bool
    successor_worker_active: bool
    same_stable_key_seen_by_both: bool
    late_legacy_callback_after_successor: bool
    unknown_in_flight: bool
    old_client_hits: int
    zero_use_observed: bool
    restore_replay_verified: bool
    operations_approved: bool


def evaluate(evidence: CutoverEvidence) -> CutoverDecision:
    """Return the only safe G0 model outcome for the supplied evidence."""

    if evidence.legacy_direct_effect_active and evidence.successor_worker_active:
        return CutoverDecision.REOPEN_DUPLICATE_AUTHORITY
    if evidence.same_stable_key_seen_by_both:
        return CutoverDecision.REOPEN_DUPLICATE_AUTHORITY
    if evidence.late_legacy_callback_after_successor:
        return CutoverDecision.REOPEN_STALE_LEGACY_CALLBACK
    if evidence.unknown_in_flight:
        return CutoverDecision.REOPEN_UNKNOWN_IN_FLIGHT
    if evidence.old_client_hits > 0:
        return CutoverDecision.REOPEN_OLD_CLIENT
    if evidence.legacy_direct_effect_active:
        return CutoverDecision.HOLD_LEGACY_STILL_ACTIVE
    if not evidence.successor_worker_active:
        return CutoverDecision.HOLD_SUCCESSOR_NOT_ACTIVE
    if not evidence.zero_use_observed:
        return CutoverDecision.HOLD_ZERO_USE_NOT_OBSERVED
    if not evidence.restore_replay_verified:
        return CutoverDecision.HOLD_RESTORE_REPLAY_NOT_VERIFIED
    if not evidence.operations_approved:
        return CutoverDecision.AWAIT_EXTERNAL_APPROVAL
    return CutoverDecision.READY_FOR_SEPARATE_AUTHORIZATION


def assert_equal(actual: object, expected: object, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected={expected!r} actual={actual!r}")


def candidate_ready_evidence(**changes: object) -> CutoverEvidence:
    values: dict[str, object] = {
        "legacy_direct_effect_active": False,
        "successor_worker_active": True,
        "same_stable_key_seen_by_both": False,
        "late_legacy_callback_after_successor": False,
        "unknown_in_flight": False,
        "old_client_hits": 0,
        "zero_use_observed": True,
        "restore_replay_verified": True,
        "operations_approved": True,
    }
    values.update(changes)
    return CutoverEvidence(**values)  # type: ignore[arg-type]


def main() -> None:
    # No old/new double Authority, even where both executions share the same
    # stable key. The correct outcome is reopen, never dedupe-and-proceed.
    assert_equal(
        evaluate(candidate_ready_evidence(legacy_direct_effect_active=True, same_stable_key_seen_by_both=True)),
        CutoverDecision.REOPEN_DUPLICATE_AUTHORITY,
        "old/new duplicate authority must fail closed",
    )

    # A legacy callback after successor admission proves a late old path. It
    # resets the candidate rather than being silently accepted or retried.
    assert_equal(
        evaluate(candidate_ready_evidence(late_legacy_callback_after_successor=True)),
        CutoverDecision.REOPEN_STALE_LEGACY_CALLBACK,
        "late legacy callback must reopen candidate",
    )

    assert_equal(
        evaluate(candidate_ready_evidence(unknown_in_flight=True)),
        CutoverDecision.REOPEN_UNKNOWN_IN_FLIGHT,
        "unknown in-flight work must reopen candidate",
    )
    assert_equal(
        evaluate(candidate_ready_evidence(old_client_hits=1)),
        CutoverDecision.REOPEN_OLD_CLIENT,
        "old client use must reopen candidate",
    )

    # A restart without durable restore/replay proof cannot be treated as a
    # drain. It holds rather than claiming an observation window survived.
    assert_equal(
        evaluate(candidate_ready_evidence(restore_replay_verified=False)),
        CutoverDecision.HOLD_RESTORE_REPLAY_NOT_VERIFIED,
        "restart without restore/replay proof must hold",
    )
    assert_equal(
        evaluate(candidate_ready_evidence(zero_use_observed=False)),
        CutoverDecision.HOLD_ZERO_USE_NOT_OBSERVED,
        "missing zero-use evidence must hold",
    )
    assert_equal(
        evaluate(candidate_ready_evidence(successor_worker_active=False)),
        CutoverDecision.HOLD_SUCCESSOR_NOT_ACTIVE,
        "legacy cannot retire before successor is active",
    )
    assert_equal(
        evaluate(candidate_ready_evidence(legacy_direct_effect_active=True, successor_worker_active=False)),
        CutoverDecision.HOLD_LEGACY_STILL_ACTIVE,
        "active legacy path cannot retire itself",
    )

    assert_equal(
        evaluate(candidate_ready_evidence(operations_approved=False)),
        CutoverDecision.AWAIT_EXTERNAL_APPROVAL,
        "G0 evidence cannot self-approve a candidate",
    )
    assert_equal(
        evaluate(candidate_ready_evidence()),
        CutoverDecision.READY_FOR_SEPARATE_AUTHORIZATION,
        "all modeled evidence only prepares a separate authorization",
    )

    # The model never returns a retired/removal action; actual removal belongs
    # to a separately authorized C11 implementation after G2/G3 evidence.
    forbidden = {"retired", "remove", "delete", "revoke"}
    actual_values = {decision.value for decision in CutoverDecision}
    if forbidden & actual_values:
        raise AssertionError("G0 cutover model must not expose a removal action")

    print(
        "Legacy effect cutover fence model smoke passed: "
        "duplicate/late/unknown/old-client=reopen "
        "restart/zero-use/successor=hold approval=separate"
    )


if __name__ == "__main__":
    main()
