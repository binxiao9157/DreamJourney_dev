# Echo Archive Context Indicator QA

Date: 2026-06-17

Scope:
- Surface existing archive context availability on the Echo screen without changing the Stitch-aligned scenic background, quote bubble, microphone, or custom tab bar.
- Keep the indicator hidden when no archive context is available.
- Preserve the archive-to-echo prompt path proven by the existing smoke harness.

Evidence:
- `00-echo-without-archive-context.png`: clean install, normal login, no archive context. The indicator is not shown.
- `01-echo-with-archive-context.png`: `DJSeedEchoArchiveContext` seed, available archive context count is 1. The indicator appears above the quote bubble.
- `build-debug.log`: Debug simulator build succeeded.

Checks:
- `swift tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swiftc -parse-as-library tmp/visual-qa/prd-stitch-ui/echo-archive-context-status-check.swift DreamJourney/Sources/Modules/Echo/EchoViewModel.swift -o /tmp/dj-echo-archive-context-status-check && /tmp/dj-echo-archive-context-status-check`
- `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`

Latest core smoke:
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-210257/`
