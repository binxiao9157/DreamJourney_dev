# Digital Human Live Echo MVP

## Summary

This update adds a hidden QA-only digital human live panel inside Echo. It renders through `WKWebView` using the bundled Web assets and exposes a Swift-to-JavaScript bridge for Echo state, TTS playback lifecycle, and audio-level-driven digital human motion.

The feature is not public by default. It is only visible when `DJFeature.digitalHumanLivePanel` is enabled and the app is launched with `DJShowDigitalHumanLivePanel` or `DJRunDigitalHumanLivePanelSmoke`.

## Implemented

- `DigitalHumanLivePanelView` loads `DigitalHumanLive.html` from the app bundle.
- `DigitalHumanLive.html` wraps the existing `DHLiveMini.js`, `DHLiveMini.wasm`, `MiniLive2.js`, `MiniMateLoader.js`, `pako.min.js`, and the bundled real digital-human media asset `01.mp4`.
- Echo maps state into the panel:
  - idle -> `idle`
  - starting/listening -> `listening`
  - thinking/waitingReply -> `thinking`
  - speaking/replied -> `speaking`
  - error -> `failed`
- `EchoViewController` connects real Echo TTS lifecycle events to the panel:
  - `onTTSStarted` enters speaking and starts the SDK TTS playback fallback level source.
  - `onTTSFinished`, `onError`, and dialog end stop panel audio metering and reset the level.
- `DigitalHumanAudioLevelMeter` supports `AVAudioPlayer` metering via `averagePower(forChannel:)`.
- UIQA uses deterministic local `AVAudioPlayer` playback to prove mouth/dynamic movement follows measured playback loudness, not a simulated timer.
- The production SDK TTS path is explicitly reported as `sdkTTSPlaybackFallback` until the speech SDK exposes audio frames, player-level metering, or provider phoneme/viseme timing.
- `DigitalHumanLipSyncTimeline` defines the future provider contract:
  - `DigitalHumanLipSyncFrame`: `timeOffset`, `mouthShape`, `intensity`.
  - `DigitalHumanLipSyncTimeline`: source, duration, ordered frames, and safe JSON serialization for the Web bridge.
  - `DigitalHumanPlaybackEvent`: typed events for audio-level, provider timeline, stopped, and failed states.
- `DigitalHumanLive.html` exposes `setVisemeTimeline(...)` and `setMouthShape(...)`. The panel snapshot reports `lipSyncSource`, `currentMouthShape`, and `lipSyncFrameCount`.
- UIQA can run `DIGITAL_HUMAN_LIPSYNC_MODE=providerVisemeTimeline` to verify a mock provider timeline advances mouth shape without waiting for a real provider.
- The fake fallback avatar has been removed. QA must prove that the bundled real digital-human video asset is ready, or the feature should degrade back to ordinary Echo.
- UIQA launch arg `DJRunDigitalHumanLivePanelSmoke` opens Echo, shows the panel, drives state to speaking, plays a local metered probe audio file, writes result JSON, and captures a screenshot.

## Verification

Static checks:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift
git diff --check
```

Result: passed.

The static check also guards against reintroducing fake avatar markup and verifies that the HTML/renderer paths match Xcode's flattened app-bundle resource layout.

Simulator smoke:

```bash
RUN_ID=20260620-digital-human-real-asset-r4 tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh
RUN_ID=20260620-digital-human-tts-metering tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh
DIGITAL_HUMAN_LIPSYNC_MODE=providerVisemeTimeline RUN_ID=20260620-digital-human-provider-viseme-timeline tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh
RUN_ID=20260620-digital-human-metering-after-viseme tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh
```

Result: passed.

Evidence:

- Result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/digital-human-live-panel-smoke-result.json`
- Screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/01-digital-human-live-panel.png`
- Build log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/build.log`
- Runtime log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/runtime.log`
- OS log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/oslog.log`
- Metered result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-tts-metering/digital-human-live-panel-smoke-result.json`
- Metered screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-tts-metering/01-digital-human-live-panel.png`
- Metered build log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-tts-metering/build.log`
- Metered runtime log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-tts-metering/runtime.log`
- Metered OS log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-tts-metering/oslog.log`
- Provider timeline result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-provider-viseme-timeline/digital-human-live-panel-smoke-result.json`
- Provider timeline screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-provider-viseme-timeline/01-digital-human-live-panel.png`
- Metering-after-viseme result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-metering-after-viseme/digital-human-live-panel-smoke-result.json`
- Metering-after-viseme screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-metering-after-viseme/01-digital-human-live-panel.png`

Smoke result highlights:

- `completed=true`
- `panelVisible=true`
- `panelReady=true`
- `hasRealDigitalHumanAsset=true`
- `assetVideoReady=true`
- `hasFallbackAvatar=false`
- `stateName=speaking`
- `audioLevel=0.63310296587799986`
- `audioLevelSource=avAudioPlayerMetering`
- `meteringSampleCount=7`
- Provider timeline mode:
  - `audioLevelSource=providerVisemeTimeline`
  - `lipSyncSource=providerVisemeTimeline`
  - `currentMouthShape=aa`
  - `lipSyncFrameCount=9`

Device SDK build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260620-digital-human-live-panel-device-readiness/DerivedData -xcconfig DreamJourney/Config/YXJ.local.xcconfig -allowProvisioningUpdates build
```

Result: passed.

Device evidence:

- Device build log: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260620-digital-human-live-panel-device-readiness/device-build.log`

True-device install/launch status:

- `devicectl` detected iPhone as `unavailable`.
- `xctrace` listed iPhone under `Devices Offline`.
- `xcodebuild -showdestinations` did not expose an online physical iPhone destination.
- Therefore install/launch verification is blocked until the device is unlocked/trusted and appears online.

## Current Boundary

This proves an audio-reactive digital human preview, a real `AVAudioPlayer` metering bridge for QA-controlled playback, and a provider viseme timeline contract that can drive mouth-shape state from timestamped frames. It does not prove final provider-level phoneme lip sync quality.

Still not claimed:

- Real provider phoneme/viseme timeline delivery.
- Speech SDK internal TTS audio frame metering. Current SDK callbacks only provide `onTTSStarted` / `onTTSFinished`, so the production SDK path is `sdkTTSPlaybackFallback`.
- Production voice SDK quality.
- True-device visual/performance pass.

## Next Step

When the iPhone appears online, rerun a device install/launch smoke with `DJShowDigitalHumanLivePanel` and capture a device screenshot/log. The next technical step for finer sync is provider-level phoneme/viseme timing or SDK audio frame callbacks; without that API, the app must not claim production phoneme-level lip sync.
