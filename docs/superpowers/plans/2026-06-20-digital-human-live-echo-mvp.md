# Digital Human Live Echo MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hidden QA-only digital human live panel to Echo, render bundled Web assets through `WKWebView`, drive mouth movement with simulated audio level, and verify simulator plus true-device readiness.

**Architecture:** Echo maps interaction state to a new `DigitalHumanLivePanelView`. The panel loads a bundled HTML wrapper and exposes a narrow Swift-to-JavaScript bridge. QA smoke uses an AppDelegate launch arg to show the panel, drive states, save JSON, and capture screenshots.

**Tech Stack:** UIKit, WebKit, bundled JavaScript/WASM resources, existing `UI_QA_SIMULATOR` harness, `xcodebuild`, `simctl`.

---

### Task 1: Static Contract and Release Guard

**Files:**
- Modify: `DreamJourney/Sources/App/FeatureFlagService.swift`
- Create: `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`

- [ ] Add `DJFeature.digitalHumanLivePanel`.
- [ ] Keep it out of `defaultEnabled`.
- [ ] Write a Swift static check that asserts the feature flag exists, is not default-enabled, and the QA launch args are the only activation path.
- [ ] Run `swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift` and confirm it fails before the implementation is wired.

### Task 2: Web Wrapper

**Files:**
- Create: `DreamJourney/Resources/web/DigitalHumanLive.html`
- Modify: `DreamJourney.xcodeproj/project.pbxproj`

- [ ] Create a standalone HTML wrapper that loads `pako.min.js`, `DHLiveMini.js`, `MiniLive2.js`, and `MiniMateLoader.js`.
- [ ] Add a defensive `window.DreamJourneyDigitalHuman` API with `setState`, `setAudioLevel`, `setPersona`, and `snapshot`.
- [x] Remove the fake fallback avatar. The panel must render a bundled real digital-human video asset (`01.mp4`) or report degradation back to ordinary Echo.
- [ ] Add the HTML file to Xcode resources.

### Task 3: iOS Panel View

**Files:**
- Create: `DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift`
- Modify: `DreamJourney.xcodeproj/project.pbxproj`

- [x] Implement `DigitalHumanLivePanelView` with `WKWebView`, load-state callbacks, real-asset readiness reporting, and JS helpers.
- [ ] Add methods `setInteractionState(_:)`, `setAudioLevel(_:)`, `setPersona(name:subtitle:)`, `startSimulatedAudioLevels()`, `stopSimulatedAudioLevels()`, and `snapshot(completion:)`.
- [ ] Keep all state changes on the main queue.

### Task 4: Echo Integration

**Files:**
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`

- [ ] Add the panel behind `FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)` and QA launch args.
- [ ] Layout the panel above the quote bubble without covering the tab bar or mic button.
- [ ] Map Echo states:
  - idle -> `idle`
  - starting/listening -> `listening`
  - thinking/waitingReply -> `thinking`
  - speaking/replied -> `speaking`
  - error -> `failed`
- [ ] Start simulated amplitude when speaking/listening previews run; stop it on idle/error.
- [ ] Add UIQA method `runUIQADigitalHumanLivePanelSmoke(completion:)`.

### Task 5: UIQA Harness and Script

**Files:**
- Modify: `DreamJourney/Sources/AppDelegate.swift`
- Create: `tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh`

- [ ] Add launch arg `DJRunDigitalHumanLivePanelSmoke`.
- [ ] Enable `digitalHumanLivePanel` only inside this QA path.
- [ ] Select Echo tab, run the Echo panel smoke, write result JSON, and leave the panel visible for screenshot capture.
- [ ] Script builds with `DEBUG UI_QA_SIMULATOR`, installs on simulator, launches with the smoke arg, waits for the completion log, saves screenshot and logs.

### Task 6: Validation and True-Device Readiness

**Files:**
- Create: `docs/superpowers/status/2026-06-20-digital-human-live-echo-mvp.md`

- [ ] Run static check.
- [ ] Run `git diff --check`.
- [ ] Run simulator build.
- [ ] Run `tmp/visual-qa/prd-stitch-ui/run-digital-human-live-panel-smoke.sh`.
- [ ] Run true-device build/install/launch readiness with existing local signing override if a connected device is available.
- [ ] Document result JSON, screenshot, build logs, true-device logs, and remaining limits.
