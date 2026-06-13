#!/usr/bin/env python3
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
service = ROOT / "DreamJourney/Sources/Memoir/VoiceCloneService.swift"
profile_store = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift"

service_text = service.read_text(encoding="utf-8")
profile_text = profile_store.read_text(encoding="utf-8")


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


if "persistAsCurrent: Bool = true" not in service_text:
    raise SystemExit(fail("VoiceCloneService.trainVoice should expose persistAsCurrent defaulting to true"))

start = service_text.find('let returnedSpeakerId = json["speaker_id"]')
end = service_text.find('DDLogInfo("[VoiceClone] 音色已提交训练', start)
if start == -1 or end == -1:
    raise SystemExit(fail("VoiceCloneService success block not found"))

success_block = service_text[start:end]
if "if persistAsCurrent" not in success_block:
    raise SystemExit(fail("VoiceCloneService should only save global speaker id when persistAsCurrent is true"))

if "VoiceCloneService.shared.trainVoice(" not in profile_text or "persistAsCurrent: false" not in profile_text:
    raise SystemExit(fail("per-person voice profile trainer must not persist speaker id as the global current voice"))

print("VoiceCloneProfilePersistence verification passed")
