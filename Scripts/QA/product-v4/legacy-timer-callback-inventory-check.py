#!/usr/bin/env python3
"""Keep the WI-S1-02-10 iOS timer/callback inventory aligned with source.

This is a value-free static guard. It deliberately does not schedule a local
notification, start a voice poll, make a digital-human heartbeat, or change a
timer's runtime behavior.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INVENTORY = ROOT / "Scripts/QA/product-v4/legacy-timer-callback-inventory-v1.json"
SOURCES_ROOT = ROOT / "DreamJourney/Sources"

EXPECTED_IDS = {
    "echo-delayed-reply-local-notification",
    "time-letter-local-notification",
    "voice-clone-training-poll",
    "digital-human-session-heartbeat",
    "dialog-engine-silence-timeout",
    "digital-human-audio-level-meter",
    "memoir-audio-progress",
    "archive-audio-recording-duration",
    "footprint-banner-dismiss",
}

FORBIDDEN_VALUE_KEYS = {
    "accessToken",
    "apiKey",
    "authorization",
    "body",
    "content",
    "credential",
    "headers",
    "payload",
    "rawValue",
    "secret",
    "secretKey",
    "token",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def assert_value_free(value: object, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            require(key not in FORBIDDEN_VALUE_KEYS, f"forbidden value field at {path}.{key}")
            assert_value_free(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_value_free(child, f"{path}[{index}]")


def main() -> None:
    inventory = json.loads(read(INVENTORY))
    assert_value_free(inventory)
    require(
        inventory.get("schemaVersion") == "dreamjourney.ios-legacy-timer-callback-inventory.v1",
        "unsupported iOS legacy timer/callback inventory schema",
    )
    entries = inventory.get("entries")
    require(isinstance(entries, list) and entries, "timer/callback inventory entries are required")
    entries_by_id = {entry.get("id"): entry for entry in entries if isinstance(entry, dict)}
    require(set(entries_by_id) == EXPECTED_IDS, "iOS timer/callback inventory entry set drifted")
    require(len(entries_by_id) == len(entries), "iOS timer/callback inventory contains duplicate IDs")

    for entry_id, entry in entries_by_id.items():
        for field in (
            "surface",
            "classification",
            "ownerBoundary",
            "generationFence",
            "lifecycleDisposition",
            "retirementState",
        ):
            require(isinstance(entry.get(field), str) and entry[field].strip(), f"{entry_id}.{field} is required")
        sources = entry.get("sources")
        require(isinstance(sources, list) and sources, f"{entry_id}.sources are required")
        for source in sources:
            require(isinstance(source, dict), f"{entry_id}.source must be an object")
            source_path = source.get("path")
            markers = source.get("markers")
            require(isinstance(source_path, str) and source_path and not source_path.startswith("/"), f"{entry_id} source path invalid")
            require(isinstance(markers, list) and markers, f"{entry_id} source markers missing")
            text = read(ROOT / source_path)
            for marker in markers:
                require(marker in text, f"source marker drifted: {entry_id} -> {source_path} -> {marker}")

    # This small source-wide allowlist prevents new Timer surfaces from being
    # silently omitted from the V4 migration inventory. Dispatch async delays
    # are intentionally out of scope until they own a product effect.
    timer_sources = {
        path.relative_to(ROOT).as_posix()
        for path in SOURCES_ROOT.rglob("*.swift")
        if "Timer.scheduledTimer" in path.read_text(encoding="utf-8")
    }
    expected_timer_sources = {
        "DreamJourney/Sources/Services/DialogEngineManager.swift",
        "DreamJourney/Sources/Memoir/VoiceCloneService.swift",
        "DreamJourney/Sources/Modules/Map/FootprintNotificationBanner.swift",
        "DreamJourney/Sources/Memoir/MemoirAudioPlayer.swift",
        "DreamJourney/Sources/Modules/Echo/DigitalHumanAudioLevelMeter.swift",
        "DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift",
    }
    require(timer_sources == expected_timer_sources, f"unclassified iOS Timer source(s): {sorted(timer_sources ^ expected_timer_sources)}")

    time_letter = entries_by_id["time-letter-local-notification"]
    require(
        time_letter["lifecycleDisposition"].startswith("account-lifecycle teardown is implemented"),
        "time-letter notification lifecycle teardown inventory must remain explicit",
    )
    pure_ui_entries = [
        entry for entry in entries_by_id.values()
        if entry["retirementState"] == "EXCLUDED_PURE_UI_OR_PLAYBACK"
    ]
    require(len(pure_ui_entries) == 4, "pure UI/playback timer exclusion inventory drifted")

    print(
        "iOS legacy timer/callback inventory check passed: "
        f"entries={len(entries_by_id)} timerSources={len(timer_sources)} "
        f"productOrRuntime={len(entries_by_id) - len(pure_ui_entries)} pureUI={len(pure_ui_entries)} "
        "timeLetterLifecycleTeardown=implemented"
    )


if __name__ == "__main__":
    main()
