# Digital Human Live Echo MVP Design

## Goal

Build a hidden QA-only MVP for a real-time digital human panel inside Echo. The MVP validates that the bundled `DHLiveMini.js`/`DHLiveMini.wasm` assets can render in-app, that Echo state can drive a speaking/listening visual state, and that a simulated audio level can drive mouth movement. It must not be visible in the default public release.

## Scope

This MVP is a technical and product-readiness probe, not the final production lip-sync solution.

Included:
- Hidden feature flag and QA launch argument.
- `WKWebView` digital human panel hosted inside Echo.
- Local HTML wrapper around bundled Web assets.
- Swift-to-JavaScript bridge for `idle`, `listening`, `thinking`, `speaking`, `stopped`, and `failed`.
- Simulated amplitude driver for mouth movement.
- Fallback to the existing Echo UI when Web assets fail to load.
- Simulator smoke with screenshot/result evidence.
- True-device build/install/launch readiness evidence.

Excluded:
- Public release exposure.
- Provider phoneme/viseme timestamp sync.
- Real cloned-voice TTS lip-sync quality claim.
- Replacing the current Echo voice flow.
- Backend changes.

## Architecture

`EchoViewController` remains the owner of Echo interaction state. A new focused `DigitalHumanLivePanelView` owns `WKWebView`, asset loading, and the JavaScript bridge. A small local HTML file hosts the existing Web renderer and adds a stable `window.DreamJourneyDigitalHuman` API that Swift can call.

The bridge is intentionally simple:
- `setState(stateName)` updates visual state labels and playback mode.
- `setAudioLevel(level)` accepts `0...1` and drives a mouth overlay/amplitude marker for MVP validation.
- `setPersona(name, subtitle)` updates QA-visible metadata.
- `snapshot()` returns readiness and last state for UIQA.

If the bundled renderer fails, the panel reports failure and hides itself so the normal Echo UI is still usable.

## Release Boundary

The feature is disabled by default. It can only show when both conditions are true:
- `DJFeature.digitalHumanLivePanel` is enabled.
- QA launch argument `DJShowDigitalHumanLivePanel` or `DJRunDigitalHumanLivePanelSmoke` is present.

Public MVP builds must not expose the panel or any visible entry text.

## Validation

Static checks:
- Feature flag exists but is not part of default enabled features.
- Echo guards the panel behind QA launch args.
- The HTML wrapper and existing Web assets are bundled in resources.

Simulator smoke:
- Launch with `DJRunDigitalHumanLivePanelSmoke`.
- Select Echo tab.
- Show the panel.
- Drive states through listening, thinking, speaking, stopped.
- Drive simulated audio level for several frames.
- Save result JSON and screenshot.

True-device readiness:
- Build with local signing override.
- Install and launch with QA argument if a connected device is available.
- Capture build/install/launch logs and mark manual visual verification status.

## Follow-Up Path

Phase 1 can replace simulated amplitude with actual TTS playback metering. Phase 2 can integrate provider phoneme/viseme timings if the voice provider exposes stable timestamps. Until those phases are verified, the product must describe this as "audio-reactive digital human preview", not production lip-sync.
