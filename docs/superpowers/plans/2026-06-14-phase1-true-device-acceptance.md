# Phase1 True Device Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drive DreamJourney from the current engineering baseline to phase-one true-device acceptance evidence without reopening frozen demo/visual tasks.

**Architecture:** This plan is validation-first. Each task starts from true-device or backend evidence, opens code work only for a proven failure, and updates the phase-one status report after the result is known.

**Tech Stack:** iOS UIKit/Swift, Xcode physical-device build, DreamJourneyBackend FastAPI/Postgres, KBLite local graph, VolcEngine realtime/TTS, DeepSeek image/KBLite extraction proxy, AMap district proxy.

---

## File Map

- Status report: `docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md`
- Acceptance ledger: `docs/superpowers/reports/2026-06-14-phase1-acceptance-task-ledger.md`
- Full phase-one verifier: `Scripts/verify_phase1.sh`
- iOS backend client: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Memory archive UI: `DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift`
- KBLite manager: `DreamJourney/Sources/Services/KBLiteManager.swift`
- Dialog grounding models: `DreamJourney/Sources/Services/DialogEngineModels.swift`
- Care dashboard UI: `DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift`
- Time mailbox UI: `DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift`
- Backend API: `DreamJourneyBackend/app/main.py`

## Task 1: P0 Memory Archive True Material Acceptance

**Files and artifacts:**
- Read/update: `docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md`
- Evidence folder: `docs/superpowers/evidence/phase1-memory-archive/`
- If fixing only: `DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift`
- If fixing only: `DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift`
- If fixing only: `DreamJourney/Sources/Services/KBLiteManager.swift`

- [ ] **Step 1: Create evidence folder**

Run:

```bash
mkdir -p docs/superpowers/evidence/phase1-memory-archive
```

Expected: folder exists and remains uncommitted until screenshots/logs are reviewed.

- [ ] **Step 2: Confirm local verifier baseline before true-device testing**

Run:

```bash
bash Scripts/verify_phase1.sh > /tmp/dreamjourney_phase1_before_memory_archive_acceptance.log 2>&1
```

Expected: command exits `0` and the log contains `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Perform true-device memory archive flow**

Manual true-device steps:

1. Launch app with no roadshow/offline/demo arguments.
2. Confirm privacy scope is `可生成`.
3. Add text material:

   ```text
   我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。林桂芳性格慢，常说慢慢来，日子要一张一张照好。
   ```

4. Add one real photo.
5. Add one real voice material.
6. Add two more voice materials for the same concrete person if available.
7. Wait 5-10 seconds after each save.

Expected:

- Text material produces people, places, events, facts, and source evidence in the knowledge base.
- Photo analysis either produces a real backend analysis or a friendly retry state; it must not fake a mock success.
- Voice material creates transcript/summary or a friendly retry state.
- Voice profile reaches `readyForTraining` when enough samples exist, or shows a friendly failure.

- [ ] **Step 4: Capture backend archive metadata**

Run on a configured backend endpoint:

```bash
curl -sS -H "Authorization: Bearer $DREAMJOURNEY_BACKEND_API_TOKEN" \
  "$DREAMJOURNEY_BACKEND_BASE_URL/archive/items/$DREAMJOURNEY_TEST_USER_ID" \
  > docs/superpowers/evidence/phase1-memory-archive/archive-items.json
```

Expected:

- JSON contains archive metadata.
- JSON does not contain `localPath`, raw image base64, raw audio bytes, or full local file URLs.

- [ ] **Step 5: Open defects only for failed acceptance points**

If Step 3 or Step 4 fails, record exact failing evidence in:

```text
docs/superpowers/evidence/phase1-memory-archive/failures.md
```

Expected: each failure has screenshot/log/backend response and one narrow next fix.

## Task 2: P0 Digital Human Memory Grounding Acceptance

**Files and artifacts:**
- Evidence folder: `docs/superpowers/evidence/phase1-digital-human-grounding/`
- If fixing only: `DreamJourney/Sources/Services/DialogEngineModels.swift`
- If fixing only: `DreamJourney/Sources/Services/DialogEngineManager.swift`
- If fixing only: `DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift`

- [ ] **Step 1: Create evidence folder**

Run:

```bash
mkdir -p docs/superpowers/evidence/phase1-digital-human-grounding
```

Expected: folder exists.

- [ ] **Step 2: Seed grounding via real memory archive data**

Use the memory created in Task 1. Do not use roadshow/demo seed.

Expected: knowledge base contains at least one verified fact about `林桂芳`, `杭州西湖`, or `小照相馆`.

- [ ] **Step 3: Perform true-device 3-5 round voice dialog**

Ask known facts:

```text
林桂芳以前常说什么？
我们以前在哪里开过照相馆？
```

Ask unknown facts:

```text
她最喜欢哪首歌？
她年轻时最喜欢哪部电影？
```

Expected:

- Known facts are answered with natural reference to the deposited memory.
- Unknown facts are not invented; assistant invites the user to tell the memory.
- The assistant does not interrupt while the user is still speaking.
- Audio plays and stops cleanly; mouth movement stops with audio.

- [ ] **Step 4: Collect device logs**

Capture logs that include:

```text
DialogMemoryGrounding
RAG
assistant_final
playback_finished
```

Expected: logs prove prompt-safe memory grounding was used and do not include API keys, tokens, raw audio, or unapproved private content.

- [ ] **Step 5: Run grounding static verifiers after any fix**

Run:

```bash
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  Scripts/DialogMemoryGroundingVerify/main.swift \
  -o /tmp/dreamjourney_dialog_memory_grounding_verify && \
  /tmp/dreamjourney_dialog_memory_grounding_verify

python3 Scripts/DialogRealtimeRAGFinalASRVerify/main.py
python3 Scripts/KBLitePromptGraphSanitizationVerify/main.py
```

Expected: all commands pass.

## Task 3: P1 Family Care Dashboard Cross-Device Acceptance

**Files and artifacts:**
- Evidence folder: `docs/superpowers/evidence/phase1-care-dashboard/`
- If fixing only: `DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift`
- If fixing only: `DreamJourney/Sources/Services/FamilyRepository.swift`
- If fixing only: `DreamJourneyBackend/app/main.py`

- [ ] **Step 1: Create evidence folder**

Run:

```bash
mkdir -p docs/superpowers/evidence/phase1-care-dashboard
```

Expected: folder exists.

- [ ] **Step 2: Accept invitation on a second account**

Manual true-device steps:

1. Device A logs in as the elder/main user.
2. Device A creates a family invitation.
3. Device B logs in as the invited phone number.
4. Device B accepts the invitation code or `dreamjourney://family/invite?code=...`.

Expected: Device B appears as `active` and `accepted`.

- [ ] **Step 3: Generate care data**

Device A uses `亲友` scope and completes 3-5 real conversation turns.

Expected: Device B can see only a care snapshot, trend, or weekly report. It must not show raw transcript.

- [ ] **Step 4: Verify revoke enforcement**

Device A revokes Device B access. Device B attempts to reload latest/history.

Expected: backend returns `403`, and App shows a permission expired/unauthorized state.

- [ ] **Step 5: Run care verification after any fix**

Run:

```bash
python3 Scripts/CareDashboardBackendSyncVerify/main.py
python3 Scripts/CareDashboardTrueBackendFlowVerify/main.py
python3 Scripts/CareDashboardBackendAccessStatusUIVerify/main.py
```

Expected: all commands pass.

## Task 4: P1 Time Mailbox Real Letter Acceptance

**Files and artifacts:**
- Evidence folder: `docs/superpowers/evidence/phase1-time-mailbox/`
- If fixing only: `DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift`
- If fixing only: `DreamJourney/Sources/Services/TimeMailbox/TimeMailboxRepository.swift`
- If fixing only: `DreamJourneyBackend/app/main.py`

- [ ] **Step 1: Create evidence folder**

Run:

```bash
mkdir -p docs/superpowers/evidence/phase1-time-mailbox
```

Expected: folder exists.

- [ ] **Step 2: Create and deliver a real letter**

Manual true-device steps:

1. Use an already deposited memory about a concrete person.
2. Create a letter to that person.
3. Choose `可生成` or `亲友`.
4. Set delivery to at least five minutes later. The current app enforces `TimeMailboxRepository.defaultMinimumDeliveryDelay = 5 * 60`.
5. Wait for local notification.

Expected: notification does not expose recipient or body text.

- [ ] **Step 3: Verify reading boundary**

Open the delivered letter.

Expected:

- Original letter is shown as local-only.
- Echo states it is not a real reply from the deceased.
- Echo uses authorized memory if available.

- [ ] **Step 4: Verify backend metadata-only sync**

Run:

```bash
curl -sS -H "Authorization: Bearer $DREAMJOURNEY_BACKEND_API_TOKEN" \
  "$DREAMJOURNEY_BACKEND_BASE_URL/mailbox/letters/$DREAMJOURNEY_TEST_USER_ID" \
  > docs/superpowers/evidence/phase1-time-mailbox/mailbox-letters.json
```

Expected: JSON has metadata and does not contain `body`, `replyText`, or `bodyPreview`.

- [ ] **Step 5: Run mailbox verification after any fix**

Run:

```bash
python3 Scripts/TimeMailboxBackendSyncVerify/main.py
python3 Scripts/TimeMailboxPayloadPrivacyVerify/main.py
python3 Scripts/TimeMailboxTrueBackendFlowVerify/main.py
```

Expected: all commands pass.

## Task 5: P2 Backend Smoke and Evidence Package

**Files and artifacts:**
- Evidence folder: `docs/superpowers/evidence/phase1-backend-smoke/`
- If fixing only: `DreamJourneyBackend/app/main.py`
- If fixing only: `DreamJourneyBackend/app/services/privacy.py`
- If fixing only: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`

- [ ] **Step 1: Create evidence folder**

Run:

```bash
mkdir -p docs/superpowers/evidence/phase1-backend-smoke
```

Expected: folder exists.

- [ ] **Step 2: Run backend smoke**

Run:

```bash
curl -sS "$DREAMJOURNEY_BACKEND_BASE_URL/health" \
  > docs/superpowers/evidence/phase1-backend-smoke/health.json

curl -sS -H "Authorization: Bearer $DREAMJOURNEY_BACKEND_API_TOKEN" \
  "$DREAMJOURNEY_BACKEND_BASE_URL/config/runtime" \
  > docs/superpowers/evidence/phase1-backend-smoke/runtime.json
```

Expected:

- `health.json` has `status: ok`.
- `runtime.json` shows configured/missing capability status and no raw key/token values.

- [ ] **Step 3: Verify backend auth**

Run:

```bash
curl -i -sS "$DREAMJOURNEY_BACKEND_BASE_URL/config/runtime" \
  > docs/superpowers/evidence/phase1-backend-smoke/runtime-without-token.txt
```

Expected: response is `401` when `DreamJourneyBackendAPIToken` is configured.

Deployment note: the server environment variable is `BACKEND_API_TOKEN`; the iOS configuration key is `DreamJourneyBackendAPIToken`. They must be configured as the same secret before authenticated smoke can pass.

- [ ] **Step 4: Run backend unit tests**

Run:

```bash
PYTHONPATH=DreamJourneyBackend python3 -m unittest discover DreamJourneyBackend/tests
```

Expected: tests pass.

- [ ] **Step 5: Produce acceptance summary**

Update:

```text
docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md
```

Expected:

- Each P0/P1/P2 item is marked with evidence path, pass/fail status, and one next action.
- Frozen tasks remain frozen unless new true-device evidence proves a regression.
