# Digital Human Live Echo MVP

## Summary

This update adds a hidden QA-only digital human live panel inside Echo. It renders through `WKWebView` using the bundled Web assets and exposes a small Swift-to-JavaScript bridge for Echo state and simulated mouth amplitude.

The feature is not public by default. It is only visible when `DJFeature.digitalHumanLivePanel` is enabled and the app is launched with `DJShowDigitalHumanLivePanel` or `DJRunDigitalHumanLivePanelSmoke`.

## Implemented

- `DigitalHumanLivePanelView` loads `DigitalHumanLive.html` from the app bundle.
- `DigitalHumanLive.html` wraps the existing `DHLiveMini.js`, `DHLiveMini.wasm`, `MiniLive2.js`, `MiniMateLoader.js`, `pako.min.js`, and existing media assets.
- Echo maps state into the panel:
  - idle -> `idle`
  - starting/listening -> `listening`
  - thinking/waitingReply -> `thinking`
  - speaking/replied -> `speaking`
  - error -> `failed`
- Simulated audio amplitude drives the MVP mouth movement while listening/speaking.
- Fallback avatar remains available even if the vendor renderer fails.
- UIQA launch arg `DJRunDigitalHumanLivePanelSmoke` opens Echo, shows the panel, drives state to speaking, writes result JSON, and captures a screenshot.

## Verification

Static checks:

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift
git diff --check
```

Result: passed.

Simulator smoke:

```bash
RUN_ID=20260620-digital-human-live-panel tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh
```

Result: passed.

Evidence:

- Result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-live-panel/digital-human-live-panel-smoke-result.json`
- Screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-live-panel/01-digital-human-live-panel.png`
- Build log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-live-panel/build.log`
- Runtime log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-live-panel/runtime.log`
- OS log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-live-panel/oslog.log`

Smoke result highlights:

- `completed=true`
- `panelVisible=true`
- `panelReady=true`
- `stateName=speaking`
- `audioLevel=0.63310296587799986`

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

This proves an audio-reactive digital human preview, not final phoneme-level lip sync.

Still not claimed:

- Real provider phoneme/viseme lip sync.
- Real TTS playback metering sync.
- Production voice SDK quality.
- True-device visual/performance pass.

## Next Step

When the iPhone appears online, rerun a device install/launch smoke with `DJShowDigitalHumanLivePanel` and capture a device screenshot/log. After that, the next development step is replacing simulated amplitude with actual TTS/SDK playback metering.
