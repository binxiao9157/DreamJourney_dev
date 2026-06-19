#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-archive-hidden-media-combo-gate}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/archive-hidden-media-combo-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
REPORT_PATH="$OUTPUT_DIR/report.md"
UIQA_OUTPUT_ROOT="$OUTPUT_DIR/archive-hidden-shell-smoke"
BACKEND_OUTPUT_ROOT="$OUTPUT_DIR/backend-hidden-media-sync-smoke"
UIQA_DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedDataArchiveHiddenMediaComboGate}"

mkdir -p "$OUTPUT_DIR"
touch "$COMMAND_LOG"

log() {
  echo "[ARCHIVE_HIDDEN_MEDIA_COMBO_GATE] $*"
}

run_child() {
  local name="$1"
  shift
  log "$name"
  echo "== $name ==" >> "$COMMAND_LOG"
  echo "$*" >> "$COMMAND_LOG"
  "$@"
}

run_child "UIQA hidden media detail smoke" \
  env \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$UIQA_OUTPUT_ROOT" \
    DERIVED_DATA_PATH="$UIQA_DERIVED_DATA_PATH" \
    "$SCRIPT_DIR/run-archive-hidden-shell-smoke.sh"

run_child "Deployed backend hidden media sync smoke" \
  env \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$BACKEND_OUTPUT_ROOT" \
    "$SCRIPT_DIR/run-backend-hidden-media-sync-smoke.sh"

python3 - "$OUTPUT_DIR" "$RUN_ID" "$REPORT_PATH" <<'PY'
import json
import sys
from pathlib import Path

output_dir = Path(sys.argv[1])
run_id = sys.argv[2]
report_path = Path(sys.argv[3])

uiqa_dir = output_dir / "archive-hidden-shell-smoke" / run_id
backend_dir = output_dir / "backend-hidden-media-sync-smoke" / run_id
uiqa_result_path = uiqa_dir / "archive-hidden-shell-smoke-result.json"
backend_result_path = backend_dir / "backend-hidden-media-sync-smoke-result.json"

required_snapshots = [
    "archive-hidden-audio-empty-detail.png",
    "archive-hidden-audio-transcription-failed-detail.png",
    "archive-hidden-video-failed-detail.png",
    "archive-hidden-time-letter-draft-detail.png",
    "archive-hidden-time-letter-sealed-detail.png",
]

with uiqa_result_path.open("r", encoding="utf-8") as handle:
    uiqa = json.load(handle)
with backend_result_path.open("r", encoding="utf-8") as handle:
    backend = json.load(handle)

if uiqa.get("completed") is not True:
    raise SystemExit("UIQA hidden media detail smoke did not complete")
if backend.get("completed") is not True:
    raise SystemExit("Backend hidden media sync smoke did not complete")

for key in [
    "audioDetailEmptyStateVisible",
    "audioDetailTranscriptionFailedStateVisible",
    "audioDetailTranscriptionRetryVisible",
    "videoDetailThumbnailPlaceholderVisible",
    "videoDetailFailedStateVisible",
    "videoDetailRetryActionVisible",
    "hiddenMediaRuntimeUploadModeVisible",
    "hiddenMediaRuntimeMockCopyVisible",
    "timeLetterDraftDetailVisible",
    "timeLetterSealedDetailVisible",
    "timeLetterEmptyBodyVisible",
]:
    if uiqa.get(key) is not True:
        raise SystemExit(f"UIQA result missing true {key}")

for name in required_snapshots:
    path = uiqa_dir / name
    if not path.exists() or path.stat().st_size <= 0:
        raise SystemExit(f"Missing UIQA detail snapshot: {name}")

listed_audio = backend.get("listedAudio") or {}
listed_video = backend.get("listedVideo") or {}
listed_letter = backend.get("listedTimeLetter") or {}
runtime_archive = backend.get("runtimeArchive") or {}
audio_metadata = listed_audio.get("metadata") or {}
video_metadata = listed_video.get("metadata") or {}
letter_metadata = listed_letter.get("metadata") or {}

if listed_audio.get("kind") != "audio" or audio_metadata.get("uploadStatus") != "uploaded":
    raise SystemExit("Backend audio archive contract is incomplete")
if listed_video.get("kind") != "video" or video_metadata.get("uploadStatus") != "uploaded":
    raise SystemExit("Backend video archive contract is incomplete")
if listed_letter.get("kind") != "timeLetter" or letter_metadata.get("deliveryDecisionRequired") != "true":
    raise SystemExit("Backend time-letter archive contract is incomplete")
if runtime_archive.get("storageProvider") != "mockObjectStorage" or runtime_archive.get("requiresClientUpload") is not False:
    raise SystemExit("Backend runtime provider switch contract is incomplete")

created_ids = backend.get("createdIds") or []
health = backend.get("health") or {}

report = f"""# Archive Hidden Media Combo Gate

Run ID: `{run_id}`

Status: passed

## Scope

- mock 媒体详情状态 + /archive/items 持久化字段
- UIQA hidden media detail smoke: audio/video/timeLetter empty, failed, retry, draft, and sealed states.
- Deployed backend hidden media sync smoke: mock audio/video upload intent, archive item persistence, time-letter metadata, and privacy filtering.

## Evidence

- UIQA result: `archive-hidden-shell-smoke/{run_id}/archive-hidden-shell-smoke-result.json`
- Backend result: `backend-hidden-media-sync-smoke/{run_id}/backend-hidden-media-sync-smoke-result.json`
- Backend report: `backend-hidden-media-sync-smoke/{run_id}/report.md`
- UIQA snapshots:
"""

for name in required_snapshots:
    report += f"  - `archive-hidden-shell-smoke/{run_id}/{name}`\n"

report += f"""
## Contract Summary

- Backend store: `{health.get("store")}`
- Runtime provider mode: `{runtime_archive.get("providerMode")}`
- Runtime requires client upload: `{runtime_archive.get("requiresClientUpload")}`
- Created IDs: `{created_ids}`
- Audio uploadStatus: `{audio_metadata.get("uploadStatus")}`
- Video uploadStatus: `{video_metadata.get("uploadStatus")}`
- Time-letter deliveryDecisionRequired: `{letter_metadata.get("deliveryDecisionRequired")}`

"""

report_path.write_text(report, encoding="utf-8")
PY

log "Report: $REPORT_PATH"
