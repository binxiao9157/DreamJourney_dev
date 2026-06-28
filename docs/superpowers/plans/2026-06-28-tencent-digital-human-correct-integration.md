# Tencent Digital Human Correct Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DreamJourney's Echo digital human mode use one correct Tencent cloud-render calling path, with synchronized Tencent-owned voice and lip movement, and with ordinary Echo still using the existing local Volcengine voice path.

**Architecture:** Digital human mode must have a single audible owner: Tencent cloud render owns video, TTS audio, and lip sync. The app may still use the existing Echo/Volcengine dialog chain to get recognized user text and final AI reply text, but local Volcengine TTS playback must be disabled while the Tencent route is active. Do not feed Volcengine `SEEventTTSResponse` binary chunks into Tencent `sendAudio`; Tencent audio-drive requires 16 kHz, mono, 16-bit PCM packets and a valid Tencent session command context.

**Tech Stack:** iOS UIKit, SpeechEngineToB, Tencent VirtualmanStreamSDK, FastAPI backend, Tencent cloud-render aPaaS session APIs, `xcodebuild`, `devicectl`, Swift static QA scripts.

---

## Current Evidence And Root Cause

### Evidence From True Device Logs

- Local route currently plays audible Volcengine TTS.
- Tencent cloud render also creates a remote TRTC audio/video stream.
- `TRTCCloud.sharedInstance().muteAllRemoteAudio(true)` mutes a different TRTC instance than the Virtualman SDK internal instance, so it is not a reliable visual-only strategy.
- Sending local TTS chunks into `virtualman.sendAudio(AudioParams(...))` produced:

```text
ErrorCode=100001
ErrorMsg=InvalidParameter:请求参数错误: Invalid ReqId.
ReqId=echo_audio_...
```

- The local SpeechEngine `SEEventTTSResponse = 3010` chunks are not proven to be Tencent-compatible PCM. Tencent's cloud-render demo states that audio drive must convert audio to PCM 16 kHz, mono, 16-bit, then packetize it.
- `VirtualmanStreamSDK.xcframework` imports `TXLiteAVSDK_TRTC` from its Swift interface, so the Pod dependency must stay for device builds. The app bug is not that the module exists; the bug is app-level code importing or controlling TRTC directly while the Virtualman SDK owns its internal TRTC session.

### Root Cause

The current implementation mixes three different control planes:

1. Volcengine local TTS playback.
2. Tencent project chat/text drive and remote stream playback.
3. Tencent audio-drive API.

These cannot be blended casually. For the next milestone, use **Tencent text drive as the only digital-human speech source**. Keep `sendAudio` out of the Echo route until a separate PCM conversion contract is implemented and tested.

## Product Calling Decision

### Digital Human Mode

Use this path:

```text
User speaks
  -> Existing Echo ASR / reply generation obtains final reply text
  -> Local Volcengine TTS player disabled
  -> Send final reply text to Tencent text-drive
  -> Tencent cloud render performs TTS + lip sync + audio/video playback
  -> Echo marks reply delivered only after Tencent TextOver / provider end event
```

### Ordinary Echo Mode

Use this existing path:

```text
User speaks
  -> Existing Echo ASR / reply generation
  -> Local Volcengine TTS playback
  -> No Tencent session
```

### Explicitly Not In Scope For This Fix

- Do not drive Tencent mouth from Volcengine `SEEventTTSResponse` chunks.
- Do not keep both local TTS audio and Tencent remote audio audible.
- Do not use `TRTCCloud.sharedInstance()` as the main way to mute Virtualman audio.
- Do not claim provider-level viseme/phoneme sync until Tencent exposes or confirms such a timeline contract.

## Tencent Contract Reference

Tencent cloud-render docs describe two access modes: API and SDK. Cloud-render needs valid digital-human assets and interaction concurrency. Official API overview lists these core session endpoints:

- `createsession` / `createsessionbyasset`
- `statsession`
- `startsession`
- `closesession`
- WebSocket command channel

The official cloud-render demo flow is:

```text
create session
wait session ready
start session
start player
create websocket connection
send text-drive or audio-drive command
close session
```

For text drive, send text over WebSocket and Tencent does TTS + lip sync. For audio drive, convert to PCM 16 kHz, mono, 16-bit, send 5120-byte packets, then send a final packet.

Sources:

- https://cloud.tencent.com/document/product/1240/100385
- https://cloud.tencent.com/document/product/1240/130451
- https://cloud.tencent.com/document/product/1240/132372

## Files And Responsibilities

- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
  - Owns Echo route selection.
  - Enables/disables local TTS playback.
  - Sends final Echo reply text to Tencent only in digital-human mode.
  - Completes UI state after Tencent provider end.

- `DreamJourney/Sources/Services/DialogEngineManager.swift`
  - Keeps existing ASR and reply callbacks.
  - Keeps local player switch `setLocalTTSPlaybackEnabled`.
  - Should not expose Tencent lip-sync audio chunk forwarding for this milestone.

- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift`
  - Defines SDK bridge methods.
  - Should expose text-drive and provider session state clearly.
  - Should not require app-level `TXLiteAVSDK_TRTC` imports.

- `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
  - Wraps `VirtualmanStreamSDK`.
  - Should open by project or asset.
  - Should send text through the correct text-drive API path, not project chat unless that is the intended Tencent QA bot path.

- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`
  - Translates bridge events into runtime states.
  - Keeps provider session id from `open`.
  - Emits speaking/ready/failed states for Echo.

- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
  - Parses backend runtime/session contract.
  - Should include provider mode, project id/asset key, and driver capability flags.

- `Podfile`
  - Must not duplicate TRTC if `VirtualmanStreamSDK` already embeds/exports it.

- `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`
  - Static gate for route correctness.

- New backend smoke:
  - `DreamJourneyBackend/scripts/smoke/tencent_digital_human_text_drive_smoke.py`
  - Verifies Tencent session create/stat/start/ws text-drive/close without iOS.

## Task 0: Freeze Current Debug State

**Files:**
- Modify: `docs/superpowers/status/2026-06-27-tencent-digital-human-true-device-cloudrender.md`

- [ ] **Step 1: Record true-device findings**

Add this section:

```markdown
## 2026-06-28 True Device Root Cause Update

- Local Volcengine TTS is audible.
- Tencent cloud render remote stream is also active.
- `TRTCCloud.sharedInstance()` muting does not control the Virtualman SDK internal stream reliably.
- Forwarding SpeechEngine 3010 chunks to Tencent `sendAudio` reached the SDK, but Tencent returned `Invalid ReqId`.
- This proves the audio-chunk experiment is not the correct Echo integration path.
- Next implementation uses Tencent text-drive as the sole digital-human audio/lip-sync owner.
```

- [ ] **Step 2: Run docs check**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: pass, or fail only if the script has a known path mismatch unrelated to digital human work. Record the result in the status doc.

## Task 1: Remove The Failed Local-Audio-Chunk Experiment

**Files:**
- Modify: `DreamJourney/Sources/Services/DialogEngineManager.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift`
- Modify: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`

- [ ] **Step 1: Update static check first**

In `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`, require the absence of the failed route:

```swift
assertNotContains(dialogEngine, "func onTTSAudioChunk(data: Data, isFinal: Bool)", "DialogEngine should not expose Volcengine TTS chunks to Tencent in the text-drive route")
assertNotContains(echo, "sendEchoAudioChunkToDigitalHumanRuntimeIfReady", "Echo should not feed Volcengine TTS chunks into Tencent sendAudio")
assertNotContains(echo, "shouldDriveTencentLipSyncWithLocalAudio", "Tencent local-audio visual-only mode is not the chosen route")
```

- [ ] **Step 2: Run check and confirm it fails before code cleanup**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fail while the experimental code still exists.

- [ ] **Step 3: Remove `onTTSAudioChunk` from delegate contracts**

Remove this method from both real and UIQA `DialogEngineDelegate` definitions:

```swift
func onTTSAudioChunk(data: Data, isFinal: Bool)
```

Remove the `SEEventTTSResponse` forwarding block and the helper:

```swift
case SEEventTTSResponse:
    ...

private func forwardTTSAudioChunkIfNeeded(...)
```

- [ ] **Step 4: Remove Echo local-audio-to-Tencent state**

Remove these members and methods from `EchoViewController`:

```swift
private var digitalHumanAudioDriveRequestID: String?
private var digitalHumanAudioDriveSequence = 0
private var didSendDigitalHumanAudioDriveChunks = false
private var shouldDriveTencentLipSyncWithLocalAudio: Bool
private func resetDigitalHumanAudioDriveState()
private func sendEchoAudioChunkToDigitalHumanRuntimeIfReady(_ data: Data, isFinal: Bool)
func onTTSAudioChunk(data: Data, isFinal: Bool)
```

- [ ] **Step 5: Remove no-op delegate method from `AIRecordingViewController`**

Delete:

```swift
func onTTSAudioChunk(data: Data, isFinal: Bool) {
    // 旧录音页不承载数字人口型；音频分片只由 Echo 数字人面板消费。
}
```

- [ ] **Step 6: Verify cleanup**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: pass.

## Task 2: Remove Duplicate TRTC Control Path

**Files:**
- Modify: `Podfile`
- Modify: `Podfile.lock`
- Modify: `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
- Modify: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`

- [ ] **Step 1: Update static check first**

Add:

```swift
let podfile = read("Podfile")
let podfileLock = read("Podfile.lock")
assertContains(podfile, "TXLiteAVSDK_TRTC", "VirtualmanStreamSDK requires TXLiteAVSDK_TRTC as a Swift module dependency")
assertContains(podfileLock, "TXLiteAVSDK_TRTC", "Podfile.lock should keep the TRTC module required by VirtualmanStreamSDK")
assertNotContains(tencentBridge, "import TXLiteAVSDK_TRTC", "Tencent bridge should not control a separate TRTC singleton")
assertNotContains(tencentBridge, "muteAllRemoteAudio(true)", "Tencent bridge should not rely on muting an unrelated TRTC singleton")
```

- [ ] **Step 2: Run check and confirm it fails**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fail until app-level TRTC imports and muting calls are removed.

- [ ] **Step 3: Keep the TRTC pod, remove app-level TRTC control**

In `Podfile`, keep:

```ruby
pod 'TXLiteAVSDK_TRTC', :podspec => 'https://liteav.sdk.qcloud.com/pod/liteavsdkspec/customer/TXLiteAVSDK_TRTC_shuziren_13.0.20262.podspec'
```

Run:

```bash
pod install
```

Expected: `Podfile.lock` lists `TXLiteAVSDK_TRTC`, because `VirtualmanStreamSDK.swiftinterface` imports that module for device builds.

- [ ] **Step 4: Remove TRTC muting code**

In `TencentVirtualmanSDKBridge.swift`, remove:

```swift
import TXLiteAVSDK_TRTC

private func enforceVisualOnlyAudioPolicy(reason: String) { ... }
```

Remove all calls to `enforceVisualOnlyAudioPolicy(...)`.

- [ ] **Step 5: Build**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -xcconfig DreamJourney/Config/YXJ.local.xcconfig \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-clean-trtc-build \
  build
```

Expected: build passes; no duplicate TRTC class warnings should appear on next device launch.

## Task 3: Make Tencent Text Drive The Only Digital-Human Speech Path

**Files:**
- Modify: `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift`
- Modify: `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
- Modify: `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`

- [ ] **Step 1: Update static check first**

Add assertions:

```swift
assertContains(echo, "routeEchoAudioThroughDigitalHuman", "Echo should centralize Tencent-owned audio route")
assertContains(echo, "setLocalTTSPlaybackEnabled(false)", "Echo must disable local TTS playback when Tencent owns speech")
assertContains(echo, "waiting for provider TextOver before finishing Echo reply", "Echo should finish Tencent speech from provider end event")
assertNotContains(tencentBridge, "virtualman.chat(ChatParams", "Echo reply text should not enter Tencent project chat mode")
assertContains(tencentBridge, "sendStreamText", "Tencent bridge should use direct stream text drive for app-generated Echo replies")
```

- [ ] **Step 2: Run check and confirm it fails on `virtualman.chat`**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fail until `virtualman.chat` is removed from the Echo text path.

- [ ] **Step 3: Change bridge text sending**

Replace the current final-text branch:

```swift
if sequence <= 1 && isFinal {
    let accepted = virtualman.chat(ChatParams(text: text, isNewChat: true))
    ...
    return
}
```

with direct stream text:

```swift
func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
    guard !text.isEmpty || isFinal else { return }
    virtualman.sendStreamText(
        StreamTextParams(
            reqId: requestID,
            text: text,
            seq: sequence,
            isFinal: isFinal
        )
    )
}
```

If `StreamTextParams` does not trigger Tencent TTS in true-device logs, stop and implement Task 4 backend WebSocket text-drive instead. Do not fall back to local TTS chunk forwarding.

- [ ] **Step 4: Keep local TTS disabled in digital-human mode**

In `EchoViewController.applyEchoAudioRoutePolicy()`, keep:

```swift
DialogEngineManager.shared.setLocalTTSPlaybackEnabled(false)
digitalHumanStatusDetailLabel.text = "腾讯数智人负责声音与口型同步"
```

Ensure `tencentCloudRenderProvidesAudibleTTS` is no longer hardcoded false once Task 2 duplicate TRTC cleanup is complete:

```swift
private var tencentCloudRenderProvidesAudibleTTS: Bool {
    true
}
```

- [ ] **Step 5: Provider completion is TextOver-driven**

Keep this behavior:

```swift
if self.routeEchoAudioThroughDigitalHuman,
   self.pendingTencentDigitalHumanReplyText != nil {
    print("[TencentDigitalHuman] waiting for provider TextOver before finishing Echo reply")
    return
}
```

`completeTencentDigitalHumanReplyIfNeeded()` should run only when runtime sees `.ready` after `.textOver`.

- [ ] **Step 6: Verify static and build**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -xcconfig DreamJourney/Config/YXJ.local.xcconfig \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-text-drive-build \
  build
```

Expected: all pass.

## Task 4: Backend Tencent Text-Drive Smoke

**Files:**
- Create: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/smoke/tencent_digital_human_text_drive_smoke.py`
- Create: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/run-tencent-digital-human-text-drive-smoke.sh`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/docs/deployment/tencent-digital-human.md`

- [ ] **Step 1: Create smoke script**

Script behavior:

```text
1. Read appkey/accesstoken/project id or asset key from backend .env.
2. Create session by project if virtualmanProjectId is set; otherwise by asset.
3. Poll statsession until ready, max 120 seconds.
4. Start session.
5. Open WebSocket command channel.
6. Send SEND_TEXT with:
   - ReqId: uuid without unsafe separators
   - SessionId: provider session id returned by Tencent
   - Command: SEND_TEXT
   - Data.Text: "你好，我正在测试寻梦环游数字人。"
   - Data.ChatCommand: "NotUseChat"
7. Wait for TextStart and TextOver or provider equivalent.
8. Close session.
9. Print JSON result without secrets.
```

- [ ] **Step 2: Add runner**

Runner:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
python scripts/smoke/tencent_digital_human_text_drive_smoke.py
```

- [ ] **Step 3: Run locally or on server**

Run:

```bash
RUN_TENCENT_DIGITAL_HUMAN_TEXT_DRIVE_SMOKE=1 \
  /Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/run-tencent-digital-human-text-drive-smoke.sh
```

Expected:

```json
{
  "ok": true,
  "created": true,
  "started": true,
  "textStart": true,
  "textOver": true,
  "closed": true
}
```

If `textStart=false`, the problem is Tencent project/config/resource, not iOS.

## Task 5: iOS True-Device Acceptance Gate

**Files:**
- Create: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/run-tencent-digital-human-device-smoke.sh`
- Modify: `docs/superpowers/status/2026-06-27-tencent-digital-human-true-device-cloudrender.md`

- [ ] **Step 1: Build and install**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'id=B7887DD8-3561-5F2A-8D62-A3FEACDC80D9' \
  -xcconfig DreamJourney/Config/YXJ.local.xcconfig \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-device-build \
  build

xcrun devicectl device install app \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  tmp/visual-qa/prd-stitch-ui/tencent-digital-human-device-build/Build/Products/Debug-iphoneos/DreamJourney.app
```

- [ ] **Step 2: Launch with panel flag and capture logs**

Run:

```bash
xcrun devicectl device process launch \
  --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 \
  --terminate-existing \
  --console \
  com.yxj.dreamjourney.app \
  --arguments DJShowDigitalHumanLivePanel \
  2>&1 | tee tmp/visual-qa/prd-stitch-ui/true-device-acceptance/tencent-digital-human-text-drive-console.log
```

- [ ] **Step 3: Manual true-device scenario**

On device:

```text
1. Open Echo.
2. Confirm Tencent digital human video appears.
3. Tap microphone.
4. Say one short test sentence.
5. Wait for answer.
6. Confirm exactly one audible answer.
7. Confirm mouth moves during the audible answer.
8. Tap stop.
9. Confirm audio stops and no delayed leftover Tencent voice plays.
```

- [ ] **Step 4: Log assertions**

The console log must contain:

```text
[TencentDigitalHuman] echo audio route=tencentDigitalHuman
[DialogEngine] local TTS playback disabled
[TencentDigitalHuman] sent reply text source=
SpeakStatus":"TextStart"
SpeakStatus":"TextOver"
```

The console log must not contain:

```text
sent local TTS audio chunk
Invalid ReqId
echo audio route=volcengineLocalTTS
```

The console may still contain duplicate TRTC class warnings while using the current Tencent
SDK package, because `VirtualmanStreamSDK.swiftinterface` imports `TXLiteAVSDK_TRTC` and
device builds fail if that module is removed. Treat duplicate TRTC warnings as a Tencent SDK
packaging/vendor issue unless they correlate with crash or audio failure. The app-level gate is:
no app source imports `TXLiteAVSDK_TRTC`, no app source calls TRTC mute APIs, and the app does
not feed local Volcengine audio chunks into Tencent.

## Task 6: Fallback Rules

**Files:**
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify: `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`

- [ ] **Step 1: Add provider-start timeout**

When `sendEchoReplyToDigitalHumanRuntimeIfReady(...)` sends text, start a timeout:

```swift
private var digitalHumanProviderSpeechTimeoutWorkItem: DispatchWorkItem?
private static let digitalHumanProviderSpeechStartTimeout: TimeInterval = 8
```

If no `.textStart` arrives in 8 seconds:

```swift
digitalHumanStatusDetailLabel.text = "数字人声音暂不可用，已回到普通回响"
DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true)
digitalHumanRuntime?.interrupt()
pendingTencentDigitalHumanReplyText = nil
viewModel.fail("数字人回响暂时没有响应，请稍后重试")
```

- [ ] **Step 2: Cancel timeout on TextStart/TextOver/error**

Cancel timeout in:

```swift
handleDigitalHumanRuntimeStateChange(.speaking)
handleDigitalHumanRuntimeStateChange(.ready)
handleDigitalHumanRuntimeStateChange(.failed)
interruptDigitalHumanPlayback(reason:)
resetDigitalHumanReplyDispatchState()
```

- [ ] **Step 3: Verify**

Run static check, build, and one device failure case by temporarily using an invalid project id in server config only on a non-production test environment.

Expected: no frozen loading state; app falls back cleanly.

## Acceptance Criteria

The Tencent digital human route is accepted only when all of these are true:

- Backend Tencent text-drive smoke passes.
- iOS static gate passes.
- iOS true-device build/install passes.
- App source does not import/control TRTC directly; duplicate TRTC class warnings are tracked as a vendor packaging issue.
- Device log shows local TTS disabled in digital-human mode.
- Device log shows Tencent TextStart/TextOver.
- User hears exactly one response.
- Mouth moves during that response.
- Stopping Echo stops both visual and audio response.

## Decision If SDK Text Drive Still Fails

If `VirtualmanStreamSDK.sendStreamText(...)` cannot produce TTS/lip sync for app-generated text, do not return to local audio chunk forwarding. Switch to backend-owned Tencent aPaaS WebSocket text-drive:

```text
iOS opens Virtualman stream for render
backend opens commandchannel and sends SEND_TEXT with ChatCommand=NotUseChat
iOS only observes provider state/log callbacks
```

That fallback keeps Tencent as the single digital-human audio/lip-sync owner and matches the official API flow.

## 2026-06-28 Implementation Notes

This pass moved the iOS route toward a single-owner Tencent text-drive model:

- Kept `TXLiteAVSDK_TRTC` in `Podfile` because `VirtualmanStreamSDK` requires it as a Swift module dependency.
- Removed app-level `TXLiteAVSDK_TRTC` import and app-level `TRTCCloud.sharedInstance().muteAllRemoteAudio(...)` control.
- Removed Volcengine `SEEventTTSResponse` binary chunk forwarding from `DialogEngineManager` and `EchoViewController`.
- Changed Tencent reply dispatch to `sendStreamText(...)` with a 32-character hyphen-free request id.
- Disabled SpeechEngine local player creation when Tencent owns audible speech using `SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL`.
- Skipped app-level AudioSession configure/restore while external Tencent TTS owns playback.
- Added `activeTencentDigitalHumanRequestID` so a new Tencent stream text request is not sent until the previous provider speech reaches `TextOver` or is explicitly interrupted.
- Disabled Tencent route chat-streaming prewarm; Tencent now waits for complete TTS sentence text instead of receiving partial fragments such as “你好呀！”.

Verification evidence:

- Static: `swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Static: `swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Static: `git diff --check`
- Build: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-text-drive-single-owner/build-after-active-reqid-guard-generic.log`
- Prior device logs before the final active-ReqId fix showed Tencent `TextStart/TextOver` working, but also exposed the protocol violation: `ReqId values for streaming text must be equal within the same time period`.

Pending true-device verification:

- The final active-ReqId build passed `generic/platform=iOS`, but the attached iPhone became `unavailable/offline` before final install and console capture.
- After reconnecting the device, install the latest `DreamJourney.app` from `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-text-drive-single-owner-device-build/Build/Products/Debug-iphoneos/DreamJourney.app` and verify no `ReqId values for streaming text must be equal within the same time period` appears.
