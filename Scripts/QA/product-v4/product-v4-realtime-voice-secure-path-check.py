#!/usr/bin/env python3
"""Guard the backend-only, one-time-ticket realtime voice path."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT.parent / "DreamJourneyBackend"


def read(root: Path, path: str) -> str:
    return (root / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    client = read(ROOT, "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    dialog = read(ROOT, "DreamJourney/Sources/Services/DialogEngineManager.swift")
    echo = read(ROOT, "DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
    contracts = read(ROOT, "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
    broker = read(BACKEND, "app/services/realtime_voice_proxy.py")
    migration = read(BACKEND, "db/migrations/0091_realtime_voice_session_tickets.sql")
    entry_mode_migration = read(
        BACKEND,
        "db/migrations/0092_owner_truth_live_interview_entry_mode.sql",
    )

    for field in (
        "accessPath",
        "mobileDirectAllowed",
        "brokerStatus",
        "sessionToken",
        "sessionHeader",
        "expiresAt",
    ):
        require(field in client, f"Realtime voice client contract is missing {field}")

    require(
        'accessPath != "backendRealtimeProxy"' in client,
        "iOS must accept only the backend realtime proxy path",
    )
    require(
        'credentialMode != "oneTimeBackendProxyTicket"' in client,
        "iOS must accept only one-time proxy tickets",
    )
    require(
        "guard !runtimeConfig.mobileDirectAllowed" in dialog,
        "DialogEngine must reject contracts that enable direct mobile Provider access",
    )
    require(
        "SE_PARAMS_KEY_REQUEST_HEADERS_STRING" in dialog,
        "DialogEngine must send the one-time ticket as a WebSocket request header",
    )
    require(
        "SE_PARAMS_KEY_ENABLE_WS_RECONNECT_BOOL" in dialog,
        "DialogEngine must disable implicit replay of a one-use ticket",
    )
    require("VolcEngineAppToken" not in dialog, "iOS must not read a packaged Provider token")
    require("liveUserInactivityTimeout: TimeInterval = 60" in echo, "Live must auto-close after 60 seconds without user speech")
    require("finishLiveMemoryCaptureIfNeeded()" in echo, "Live close must enter the V4 pending-memory pipeline")
    require("entryMode: .live" in echo, "Live capture must use a session isolated from ordinary text interviews")
    require(
        "guard currentEntryMode == entryMode else" in contracts
        and "guard allowsEntryModeTransition else" in contracts,
        "Client must reject cross-mode resume unless an explicit transition is allowed",
    )
    require(
        "pauseCurrentSessionForEntryModeTransition(" in contracts,
        "An allowed Live transition must pause the existing session before starting another",
    )
    require("'live'" in entry_mode_migration, "Database must admit the isolated Live entry mode")

    for term in (
        "oneTimeBackendProxyTicket",
        "backendRealtimeProxy",
        "X-DreamJourney-Voice-Session",
        "ticket_hash",
        "is_realtime_voice_auth_session_active",
        "max_session_bytes",
    ):
        require(term in broker or term in migration, f"Backend proxy contract is missing {term}")
    require("Audio, transcripts and provider credentials never enter this table" in migration, "Ticket table must document its data boundary")

    print("Product V4 realtime voice secure-path check passed: backend proxy enabled, direct mobile Provider access closed")


if __name__ == "__main__":
    main()
