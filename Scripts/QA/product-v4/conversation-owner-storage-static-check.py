#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MANAGER = ROOT / "DreamJourney/Sources/Services/ConversationMemoryManager.swift"
STORAGE = ROOT / "DreamJourney/Sources/Services/ConversationLocalStorage.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


manager = MANAGER.read_text()
storage = STORAGE.read_text()
project = PROJECT.read_text()

for forbidden in (
    '?? "user_001"',
    'return sanitized.isEmpty ? "personal_user_001"',
    'fallbackPath',
    'pathToLoad',
    'currentMemoryScopeId',
    'data.write(to: filePath)',
):
    require(forbidden not in manager, f"retired Conversation fallback remains: {forbidden}")

for required in (
    "ConversationStorageLease",
    "transcriptStorageLease",
    "isCurrentConversationStorageLease(sessionLease, at: .commit)",
    "accountLeaseRuntime.validate(accountLease, at: .runtime)",
    "try localStorage.save(",
    "scope: sessionLease.scope",
    "isCurrentConversationStorageLease(sessionLease, at: .commit) == true",
    "unmountAndDiscardPendingTranscript",
    ".djUserDidLogout",
    ".djPrivateAccessDidSuspend",
):
    require(required in manager, f"Conversation lease fence missing: {required}")

for required in (
    "subjectId",
    "vaultId",
    "ownerId",
    "generationId",
    "ConversationStoreEnvelope",
    "ConversationLegacyMigrationReceipt",
    "ConversationQuarantineRecord",
    "observeGlobalLegacyIfNeeded",
    "scope.personaScope == .personal",
    "scope.ownerId == scope.subjectId",
    "legacyDocumentsRoot.appendingPathComponent(\"conversation_memory.json\")",
    "commitValidator: () -> Bool",
    "guard commitValidator()",
):
    require(required in storage, f"Conversation owner store contract missing: {required}")

require(
    'try data.write(to: destination, options: [.atomic])' in storage,
    "Conversation envelope writes must be atomic",
)
require(
    "ConversationLocalStorage.swift in Sources" in project,
    "ConversationLocalStorage must belong to the app target",
)

print("Conversation owner storage static check passed")
