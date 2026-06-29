# Tencent Digital Human PCM Drive POC

Date: 2026-06-29

## Goal

Validate Tencent digital-human audio-drive before connecting cloned TTS output. This POC keeps the normal Echo text-drive route unchanged and adds a QA-only path that sends deterministic local PCM into Tencent `sendAudio`.

## Implemented

- Added QA launch argument `DJRunTencentDigitalHumanPCMDriveSmoke`.
- Generated a deterministic local PCM signal in iOS code instead of committing binary audio:
  - 16 kHz sample rate
  - 16-bit PCM
  - mono channel
  - 100 ms paced chunks
  - empty final packet with `isFinal=true`
- Added optional stop probe launch argument `DJRunTencentDigitalHumanPCMDriveStopProbe`.
- Mapped Tencent audio-drive WebSocket statuses:
  - `AudioStart` enters provider speaking state.
  - `AudioOver` completes provider playback like text-drive completion.
- Added static guard `Scripts/QA/prd-stitch-ui/tencent-digital-human-pcm-drive-poc-check.swift`.
- Added the guard to `run-release-regression.sh` and `release-qa-package-check.swift`.

## Validation Evidence

True-device build and install used local signing config through `DreamJourney/Config/YXJ.local.xcconfig`; secrets are not recorded in this document.

- True-device evidence directory:
  - `tmp/visual-qa/prd-stitch-ui/true-device/20260629-pcm-drive-poc/`
- First PCM smoke log:
  - `pcm-drive-console.log`
  - Verified Tencent accepted PCM chunks and returned `AudioStart` / `AudioOver`.
- Fixed AudioOver mapping, then reran:
  - `pcm-drive-audioover-console.log`
  - Verified `AudioOver` immediately completed provider playback instead of waiting for timeout.
- Stop probe log:
  - `pcm-drive-stop-probe-console.log`
  - Verified `DJRunTencentDigitalHumanPCMDriveStopProbe` triggers provider interrupt while PCM chunks are in flight; Tencent then returns `AudioOver`.
- Simulator build log:
  - `xcodebuild-simulator-final.log`
- Release static gate report:
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260629-pcm-drive-poc-final-static/report.md`

## Current Boundary

This POC proves Tencent can accept app-supplied PCM and return audio-drive lifecycle events. It does not yet connect cloned TTS from the backend.

Next development step:

1. Add backend synthesis output mode for Tencent audio-drive compatible PCM.
2. Convert provider audio to PCM 16k/16-bit/mono on the backend or in a dedicated client adapter.
3. Feed chunks through the same `sendPCMChunk` path.
4. Keep iOS local audio playback disabled while Tencent owns the digital-human route.
