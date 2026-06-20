# Digital Human Live Echo MVP

## Summary

This update adds a hidden QA-only digital human live panel inside Echo. It renders through `WKWebView` using the bundled Web assets and exposes a small Swift-to-JavaScript bridge for Echo state and simulated mouth amplitude.

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
- Simulated audio amplitude drives the MVP mouth movement while listening/speaking.
- The fake fallback avatar has been removed. QA must prove that the bundled real digital-human video asset is ready, or the feature should degrade back to ordinary Echo.
- UIQA launch arg `DJRunDigitalHumanLivePanelSmoke` opens Echo, shows the panel, drives state to speaking, writes result JSON, and captures a screenshot.

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
```

Result: passed.

Evidence:

- Result JSON: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/digital-human-live-panel-smoke-result.json`
- Screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/01-digital-human-live-panel.png`
- Build log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/build.log`
- Runtime log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/runtime.log`
- OS log: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-smoke/20260620-digital-human-real-asset-r4/oslog.log`

Smoke result highlights:

- `completed=true`
- `panelVisible=true`
- `panelReady=true`
- `hasRealDigitalHumanAsset=true`
- `assetVideoReady=true`
- `hasFallbackAvatar=false`
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
