#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

seed_file = ROOT / "DreamJourney/Sources/Services/RoadshowDemoSeed.swift"
diagnostics_file = ROOT / "DreamJourney/Sources/Modules/Home/DigitalHumanDiagnosticsViewController.swift"

seed_text = seed_file.read_text(encoding="utf-8")
diagnostics_text = diagnostics_file.read_text(encoding="utf-8")

required_seed_fragments = [
    "enum LocalTestDataCleaner",
    "static func cleanForRealDeviceTesting",
    "dreamjourney.roadshow.seeded.v1",
    "dreamjourney.roadshow.offlineMode",
    "dreamjourney.timeMailbox.letters",
    "dreamjourney.memoryArchive.items",
    "dj.persistedMemories",
    "dj.readMemoryIds",
    "dj.bouncedMemoryIds",
    "conversation_memory.json",
    "knowledge_base",
    "archive_photos",
    "archive_screenshots",
    "archive_voice_samples",
    "memoirs",
    "RoadshowDemoRoute.resetCompletions",
    "ConversationMemoryManager.shared.resetLocalStorage()",
    "KBLiteManager.shared.reset(syncToBackend: false)",
    "FamilyRepository.shared.resetLocalAccessState()",
    "FamilyRepository.shared.removeDemoAndDerivedMembersForLocalTesting()",
    "FamilyDerivedMembers",
    "MemoryRepository.shared.resetLocalStorage()",
    "MemoirRepository.shared.resetLocalStorage()",
]

required_diagnostics_fragments = [
    "makeLocalTestDataCleanupCard",
    "清理本机测试数据",
    "confirmLocalTestDataCleanup",
    "LocalTestDataCleaner.cleanForRealDeviceTesting",
]

missing = []
for fragment in required_seed_fragments:
    if fragment not in seed_text:
        missing.append(f"{seed_file.name}: missing {fragment!r}")

for fragment in required_diagnostics_fragments:
    if fragment not in diagnostics_text:
        missing.append(f"{diagnostics_file.name}: missing {fragment!r}")

if missing:
    raise SystemExit("\n".join(missing))

print("LocalTestDataCleanup verification passed")
