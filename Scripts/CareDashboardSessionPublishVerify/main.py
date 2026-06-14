#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACADE = ROOT / "DreamJourney/Sources/Services/Stage1MemoryFacade.swift"
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PUBLISHER = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareDashboardSnapshotPublisher.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"CareDashboardSessionPublish verification failed: {message}", file=sys.stderr)
        sys.exit(1)


require(PUBLISHER.exists(), "CareDashboardSnapshotPublisher service should exist")

publisher = PUBLISHER.read_text()
facade = FACADE.read_text()
vc = VC.read_text()
phase1 = PHASE1.read_text()

require(
    "final class CareDashboardSnapshotPublisher" in publisher
    and "static let shared" in publisher,
    "publisher should expose a shared care snapshot publishing service",
)
require(
    "makeLocalSnapshot" in publisher
    and "CareDashboardInputPolicy.eligibleInputTurns" in publisher
    and "CareSignalAnalyzer" in publisher,
    "publisher should centralize care input filtering and local snapshot analysis",
)
require(
    "publishLatestLocalSnapshotAfterConversationEnd" in publisher
    and "ConversationMemoryManager.shared.getCareDashboardTranscriptHistory()" in publisher,
    "publisher should support background publishing after a family-scope conversation ends",
)
require(
    "DreamJourneyBackendClient.shared.syncCareSnapshot" in publisher
    and "ownerUserId == currentUserId" in publisher,
    "publisher should upload only owner-side redacted snapshots to the backend",
)
require(
    "CareDashboardSnapshotPublisher.shared.publishLatestLocalSnapshotAfterConversationEnd()" in facade,
    "finishConversationSession should trigger background care snapshot publishing",
)
require(
    "let previousSessionCount = conversationMemory.currentMemory.sessionCount" in facade
    and "conversationMemory.currentMemory.sessionCount > previousSessionCount" in facade,
    "finishConversationSession should publish only when a new conversation session was actually saved",
)
require(
    "CareDashboardSnapshotPublisher.shared.makeLocalSnapshot" in vc
    and "CareDashboardSnapshotPublisher.shared.publish" in vc
    and "snapshot: snapshot" in vc,
    "care dashboard UI should reuse the same publisher logic as conversation-end publishing",
)
require(
    "CareDashboardSessionPublishVerify/main.py" in phase1,
    "phase1 verification should include conversation-end care snapshot publishing coverage",
)

print("CareDashboardSessionPublish verification passed")
