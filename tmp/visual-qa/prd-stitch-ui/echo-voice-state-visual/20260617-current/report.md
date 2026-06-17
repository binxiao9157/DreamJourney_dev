# Echo Voice State Visual QA

Date: 2026-06-17

Scope:
- Keep the default Echo screen aligned with the Stitch/htmlCode target: scenic background, quote bubble, microphone-first CTA, and one floating tab bar.
- Add a compact voice-state capsule only when the user is in an active voice state.
- Provide a deterministic UIQA launch argument for the waiting-reply state.

Visual evidence:
- `00-echo-idle-default.png`: normal login, idle Echo state. The voice status capsule is collapsed.
- `01-echo-waiting-reply-state.png`: `DJShowEchoVoiceStatePreview`, waiting-reply state. The capsule shows `约 5 分钟后再听` between the quote bubble and mic button.
- `02-echo-listening-state.png`: `DJShowEchoListeningStatePreview`, listening state. The capsule shows `我在听，您慢慢说` and the mic button switches to stop.
- `03-echo-speaking-state.png`: `DJShowEchoSpeakingStatePreview`, speaking state. The capsule shows `回响正在抵达` and the mic button switches to waveform.

Checks:
- `swift tmp/visual-qa/prd-stitch-ui/echo-voice-state-visual-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Debug iOS Simulator build: `build-debug.log`
- Core archive-to-echo smoke: `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-212225/`

Result:
- Idle release surface stays visually close to Stitch.
- Listening, waiting, and speaking voice states now have visible feedback without exposing hidden text/image echo inputs.
- Archive-to-echo prompt context remains intact.
