# Context Packet v0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight CFL-Lite context packet so each Echo turn can report which archive, KB, persona, voice clone, and digital-human inputs were available.

**Architecture:** Keep the first version inside the existing FastAPI backend as `/context/build`. iOS consumes the packet only for diagnostics and trace logs; it does not change Echo reply generation or digital-human playback routing yet.

**Tech Stack:** FastAPI, existing DreamJourney store adapters, Swift Alamofire backend client, existing Echo logging and QA scripts.

---

### Task 1: Backend Context Packet

**Files:**
- Create: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/context_packet.py`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_core_services.py`

- [ ] Add failing tests for `/context/build` that require archive, KB, care, voice profile, digital-human runtime, fallbacks, source counts, and latency.
- [ ] Implement `ContextPacketBuilder` using existing store methods only.
- [ ] Add `POST /context/build`.
- [ ] Run the focused backend tests.

### Task 2: iOS Context Packet Client

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/context-packet-v0-check.swift`

- [ ] Add Swift parsing structs for `EchoContextPacket`.
- [ ] Add `buildEchoContextPacket(...)` to the backend client.
- [ ] Call it from Echo at the start of a user turn and log trace fields only.
- [ ] Add a static QA guard to prevent removing the context trace call.

### Task 3: Verification

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-07-01-current-implementation-prd-alignment.md`

- [ ] Add the static guard to release regression without making it a default live-backend dependency.
- [ ] Run backend tests, iOS static checks, `git diff --check`, and an iOS simulator build.
- [ ] Commit as one small feature commit if verification passes.
