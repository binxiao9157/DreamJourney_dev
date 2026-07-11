#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-release-regression}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-regression}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMMAND_LOG="$OUTPUT_DIR/commands.log"
BUILD_LOG="$OUTPUT_DIR/build-debug.log"
STATIC_LOG_DIR="$OUTPUT_DIR/static-guards"

RUN_STANDARD_BUILD="${RUN_STANDARD_BUILD:-1}"
RUN_IPHONEOS_GENERIC_BUILD="${RUN_IPHONEOS_GENERIC_BUILD:-0}"
RUN_PUBLIC_MVP_REGRESSION="${RUN_PUBLIC_MVP_REGRESSION:-0}"
RUN_SIMULATOR_SMOKE="${RUN_SIMULATOR_SMOKE:-1}"
RUN_P0_ARCHIVE_ECHO_REGRESSION="${RUN_P0_ARCHIVE_ECHO_REGRESSION:-0}"
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE="${RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE:-1}"
RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE="${RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE:-0}"
RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE="${RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE:-0}"
RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE="${RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE:-0}"
RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE="${RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE:-0}"
RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE="${RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE:-0}"
RUN_ECHO_READINESS_REPORT="${RUN_ECHO_READINESS_REPORT:-0}"
RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE="${RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE:-0}"
RUN_BACKEND_ENV_SMOKE="${RUN_BACKEND_ENV_SMOKE:-0}"
RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE="${RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE:-0}"
RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE="${RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE:-0}"
RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE="${RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE:-0}"
RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE="${RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE:-0}"
RUN_KNOWLEDGE_V2_SYNC_GATE="${RUN_KNOWLEDGE_V2_SYNC_GATE:-0}"
RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE="${RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE:-0}"
RUN_KNOWLEDGE_GOVERNANCE_GATE="${RUN_KNOWLEDGE_GOVERNANCE_GATE:-0}"
RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE="${RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE:-1}"
RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE="${RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE:-0}"
RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE="${RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE:-0}"
RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE="${RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE:-0}"
RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE="${RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE:-0}"
RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE="${RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE:-0}"
RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE="${RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE:-0}"
RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE="${RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE:-0}"
RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE="${RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE:-0}"
RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE="${RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE:-0}"
RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE="${RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE:-0}"
RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE="${RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE:-0}"
RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE="${RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE:-0}"
RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE="${RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE:-0}"
RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE="${RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE:-0}"
RUN_DIGITAL_HUMAN_TTS_VISEME_GATE="${RUN_DIGITAL_HUMAN_TTS_VISEME_GATE:-0}"
RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE="${RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE:-0}"
RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE="${RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE:-0}"
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE="${RUN_ARCHIVE_HIDDEN_SHELL_SMOKE:-0}"
RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE="${RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE:-0}"
RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE="${RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE:-0}"
RUN_P0_PROFILE_CARE_REGRESSION="${RUN_P0_PROFILE_CARE_REGRESSION:-0}"
RUN_PROFILE_CARE_STATE_SMOKE="${RUN_PROFILE_CARE_STATE_SMOKE:-0}"
RUN_PROFILE_CARE_BACKEND_STATE_SMOKE="${RUN_PROFILE_CARE_BACKEND_STATE_SMOKE:-0}"
if [[ "$RUN_PUBLIC_MVP_REGRESSION" == "1" ]]; then
  # RUN_PUBLIC_MVP_REGRESSION forces RUN_P0_ARCHIVE_ECHO_REGRESSION and RUN_P0_PROFILE_CARE_REGRESSION
  # so the public MVP minimum acceptance package covers both primary loops.
  RUN_P0_ARCHIVE_ECHO_REGRESSION=1
  RUN_P0_PROFILE_CARE_REGRESSION=1
fi
if [[ "$RUN_P0_ARCHIVE_ECHO_REGRESSION" == "1" ]]; then
  # RUN_P0_ARCHIVE_ECHO_REGRESSION forces RUN_SIMULATOR_SMOKE so the public
  # MVP archive-to-echo loop cannot be skipped by a narrow release subset.
  RUN_SIMULATOR_SMOKE=1
fi
if [[ "$RUN_P0_PROFILE_CARE_REGRESSION" == "1" ]]; then
  # RUN_P0_PROFILE_CARE_REGRESSION forces RUN_PROFILE_CARE_STATE_SMOKE and RUN_PROFILE_CARE_BACKEND_STATE_SMOKE
  # so public MVP care regression cannot accidentally run only half of the gate.
  RUN_PROFILE_CARE_STATE_SMOKE=1
  RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=1
fi
if [[ "$RUN_KNOWLEDGE_V2_SYNC_GATE" == "1" ]]; then
  # The local three-way merge model always runs. This switch adds the deployed
  # Postgres V2 mutation/tombstone half to form one cross-repository gate.
  RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE=1
fi
RELEASE_HANDOFF_MODE="${RELEASE_HANDOFF_MODE:-0}"
if [[ "$RELEASE_HANDOFF_MODE" == "1" ]]; then
  # Release handoff mode forces release-like backend acceptance; do not allow
  # RUN_RELEASE_LIKE_BACKEND=0 to bypass the handoff backend gate.
  RUN_RELEASE_LIKE_BACKEND=1
  # Release handoff mode forces hidden media combo gate so mock audio/video
  # detail states and deployed /archive/items field persistence stay aligned.
  RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1
else
  RUN_RELEASE_LIKE_BACKEND="${RUN_RELEASE_LIKE_BACKEND:-0}"
fi

mkdir -p "$STATIC_LOG_DIR"
touch "$COMMAND_LOG"

run_step() {
  local name="$1"
  shift
  local log_path="$1"
  shift

  echo "== $name ==" | tee -a "$COMMAND_LOG"
  echo "$*" >> "$COMMAND_LOG"
  "$@" > "$log_path" 2>&1
}

append_report_header() {
  cat > "$REPORT_PATH" <<EOF
# Release Regression

Run ID: \`$RUN_ID\`

## Configuration

- Standard iOS build: \`$RUN_STANDARD_BUILD\`
- iPhoneOS generic build: \`$RUN_IPHONEOS_GENERIC_BUILD\`
- Public MVP minimum regression: \`$RUN_PUBLIC_MVP_REGRESSION\`
- P0 Archive -> Echo regression gate: \`$RUN_P0_ARCHIVE_ECHO_REGRESSION\`
- Archive -> Echo simulator smoke: \`$RUN_SIMULATOR_SMOKE\`
- Echo delayed reply notification smoke: \`$RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE\`
- Echo trace export UIQA smoke: \`$RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE\`
- Echo trace evidence package export UIQA smoke: \`$RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE\`
- Echo trace evidence package panel export UIQA smoke: \`$RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE\`
- Echo QA evidence bundle export UIQA smoke: \`$RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE\`
- Echo digital-human lifecycle UIQA smoke: \`$RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE\`
- Echo readiness report: \`$RUN_ECHO_READINESS_REPORT\`
- Echo Context Builder V2 backend smoke: \`$RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE\`
- Backend environment smoke: \`$RUN_BACKEND_ENV_SMOKE\`
- Backend auth session/ownership shadow smoke: \`$RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE\`
- Backend cross-account authorization shadow smoke: \`$RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE\`
- Backend route ownership audit smoke: \`$RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE\`
- Backend deployed knowledge pipeline smoke: \`$RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE\`
- Knowledge V2 three-way/deployed combo gate: \`$RUN_KNOWLEDGE_V2_SYNC_GATE\`
- Knowledge proposal/persona local combo gate: \`$RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE\`
- Knowledge governance/source-cascade local combo gate: \`$RUN_KNOWLEDGE_GOVERNANCE_GATE\`
- Knowledge source identity cross-repository gate: \`always\`
- Knowledge privacy maintenance local gate: \`$RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE\`
- Backend archive image-analysis smoke: \`$RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE\`
- Backend hidden media sync smoke: \`$RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE\`
- Backend time-letter lifecycle smoke: \`$RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE\`
- Time-letter dispatch reminder UIQA smoke: \`$RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE\`
- Backend family/voice contract smoke: \`$RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE\`
- Backend family/account lifecycle smoke: \`$RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE\`
- Backend digital-human session smoke: \`$RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE\`
- Backend voice clone deployed smoke: \`$RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE\`
- Voice clone profile selection UIQA smoke: \`$RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE\`
- Voice clone synthesis runtime UIQA smoke: \`$RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE\`
- Tencent backend PCM-drive mock UIQA smoke: \`$RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE\`
- Digital-human + voice-clone combo gate: \`$RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE\`
- Tencent digital-human Phase 1 non-device gate: \`$RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE\`
- Digital-human session lease non-device gate: \`$RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE\`
- Digital human TTS/viseme combo gate: \`$RUN_DIGITAL_HUMAN_TTS_VISEME_GATE\`
- Digital human runtime stub gate: \`$RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE\`
- Archive failed analysis retry UIQA smoke: \`$RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE\`
- Archive hidden media/time-letter shell UIQA smoke: \`$RUN_ARCHIVE_HIDDEN_SHELL_SMOKE\`
- Archive hidden media combo gate: \`$RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE\`
- Archive media -> Echo context smoke: \`$RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE\`
- P0 Profile care regression gate: \`$RUN_P0_PROFILE_CARE_REGRESSION\`
- Profile care state UIQA smoke: \`$RUN_PROFILE_CARE_STATE_SMOKE\`
- Profile care deployed backend state UIQA smoke: \`$RUN_PROFILE_CARE_BACKEND_STATE_SMOKE\`
- Release handoff mode: \`$RELEASE_HANDOFF_MODE\`
- Release-like FastAPI/Postgres backend: \`$RUN_RELEASE_LIKE_BACKEND\`
- Backend root: \`$BACKEND_ROOT\`

## Scope

- Backend unit/FastAPI smoke, if the sibling backend repo is present.
- Static PRD/UI/release guard scripts.
- iOS Debug simulator build, unless \`RUN_STANDARD_BUILD=0\`.
- Optional iPhoneOS generic build when \`RUN_IPHONEOS_GENERIC_BUILD=1\`; this validates arm64 iPhoneOS compilation, Tencent SDK linkage, and bundle-id override without requiring an online physical device.
- Optional public MVP minimum regression when \`RUN_PUBLIC_MVP_REGRESSION=1\`; this forces both P0 Archive -> Echo and P0 Profile Care gates.
- Optional P0 Archive -> Echo regression gate when \`RUN_P0_ARCHIVE_ECHO_REGRESSION=1\`; this forces the core archive seed -> analysis -> Echo context UIQA smoke.
- Core Archive -> Echo simulator smoke, unless \`RUN_SIMULATOR_SMOKE=0\`.
- Echo delayed reply persistence/local-notification smoke, unless \`RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0\`.
- Optional Echo trace export UIQA smoke when \`RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE=1\`; this verifies installable local simulator bundle id, trace retention, and JSON export.
- Optional Echo trace evidence package export UIQA smoke when \`RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE=1\`; this verifies iOS runtime diagnostics, \`/context/build\`, \`/digital-human/sessions\`, and \`/voice/synthesis\` summaries export as one redacted QA package.
- Optional Echo trace evidence package panel export UIQA smoke when \`RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE=1\`; this verifies the QA diagnostics panel has a visible export button and can generate the same redacted evidence package.
- Optional Echo QA evidence bundle export UIQA smoke when \`RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE=1\`; this verifies Context V2 clue summary, digital-human session, voice synthesis, fallback summary, runtime diagnostics, and trace package export as one redacted QA-only v2 bundle.
- Optional Echo digital-human lifecycle UIQA smoke when \`RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE=1\`; this verifies app lifecycle pause/restore preserves the provider view, avoids microphone auto-start, and exports audio-owner state.
- Optional Echo readiness report when \`RUN_ECHO_READINESS_REPORT=1\`; this produces a JSON/Markdown diagnostic package for backend, digital-human session, voice synthesis, APNs boundary, KBLite, context packet, and runtime diagnostics readiness.
- Optional Echo Context Builder V2 backend smoke when \`RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE=1\`; this verifies \`contextVersion=echo-context-v2\`, selected/filtered/ranking trace, \`kbFact\`/\`persona\`/\`care\` source signals, \`selectedContextSourceCounts\`, failed-analysis filtering, unopened time-letter recipient filtering, pending family viewer blocking, and care snapshot summarization against the backend test client.
- Optional backend environment smoke when \`RUN_BACKEND_ENV_SMOKE=1\` and backend URL/token are configured.
- Optional backend auth session/ownership shadow smoke when \`RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE=1\`; this verifies opaque login tokens, refresh rotation/replay rejection, logout revocation, and principal-bound owner mismatch rejection while global mode remains shadow.
- Optional backend cross-account authorization shadow smoke when \`RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE=1\`; this verifies owner/family/time-letter/invitation policy decisions, forged-viewer deny evidence, and retained production shadow mode without invoking global dispatch.
- Optional backend route ownership audit smoke when \`RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE=1\`; this verifies 57 classified routes, zero omissions, owner path/body denial (including knowledge governance), system-only denial, and retained global shadow mode without invoking global dispatch.
- Optional deployed knowledge pipeline smoke when \`RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE=1\`; this verifies login, revision sync, idempotent mutation, change feed, generation context, and stale-revision conflict against the configured backend.
- Optional knowledge governance/source-cascade gate when \`RUN_KNOWLEDGE_GOVERNANCE_GATE=1\`; this verifies typed iOS actions, durable outbox, generation gating, three-way compatibility, public UI non-exposure, and deterministic backend governance/Archive cascade behavior without a true device or deployed database.
- Local knowledge privacy maintenance gate when \`RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE=1\`; this verifies canonical mutation, dry-run/apply idempotency, rollback, redacted aggregate reporting, and default no-production-write behavior with fixtures only.
- Optional deployed backend archive image-analysis smoke when \`RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE=1\`.
- Optional deployed backend hidden media sync smoke when \`RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE=1\`; this verifies mock audio/video/time-letter archive contracts without true-device media capture.
- Optional deployed backend time-letter lifecycle smoke when \`RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE=1\`; this verifies draft edit, seal, upsert, delete, due dispatch, idempotency, and owner/recipient in-app reminder metadata contracts.
- Optional time-letter dispatch reminder UIQA smoke when \`RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE=1\`; this verifies iOS treats delivered time letters as final state and counts backend mailbox unread reminders exactly once.
- Optional deployed backend family/voice contract smoke when \`RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE=1\`; this verifies hidden family digital-human modes and voice profile lifecycle contracts.
- Optional deployed backend family/account lifecycle smoke when \`RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE=1\`; this verifies phone invitation, blocked family removal, account soft delete, one-time restore, and no-export retention policy.
- Optional deployed backend digital-human session smoke when \`RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE=1\`; this verifies \`/config/runtime.digitalHuman\` and \`/digital-human/sessions\` have switched to Tencent \`cloudRender\` with backend-issued appkey/accesstoken and asset/project identity.
- Optional deployed backend voice clone smoke when \`RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE=1\`; this verifies \`/config/runtime.voiceClone\`, ready \`S_\` synthesis, and Tencent audio-drive compatible \`pcm16kMono\` without printing raw audio.
- Optional voice clone profile selection UIQA smoke when \`RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE=1\`; this verifies ready \`S_\` profiles win over pending/deleted profiles and pending backend replies do not overwrite a usable ready voice.
- Optional voice clone synthesis runtime UIQA smoke when \`RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=1\`; this verifies iOS reads \`/config/runtime.voiceClone\`, calls \`/voice/synthesis\`, and receives Tencent audio-drive compatible PCM without printing raw audio.
- Optional Tencent backend PCM-drive mock UIQA smoke when \`RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE=1\`; this verifies deployed backend synthesis PCM is chunked into the fake Tencent runtime and stop/interruption cleanup works without a true device.
- Optional digital-human + voice-clone combo gate when \`RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE=1\`; this runs backend digital-human session, backend voice clone deployed, iOS synthesis runtime, and Tencent PCM-drive mock gates under one run id.
- Optional Tencent digital-human Phase 1 non-device gate when \`RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=1\`; this verifies backend-first asset source, QA-only local override, lifecycle, audio owner logs, runtime stub, PCM-drive mock, and build without true-device validation.
- Optional digital-human session lease gate when \`RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE=1\`; this verifies lease reuse, heartbeat, release, expiry, capacity arbitration, stale callback cleanup, and simulator create-heartbeat-release without true-device validation.
- Optional digital-human TTS/viseme combo gate when \`RUN_DIGITAL_HUMAN_TTS_VISEME_GATE=1\`; this verifies backend mock synthesis \`visemeTimeline\`, iOS provider timeline UIQA, and \`AVAudioPlayer\` metering fallback UIQA.
- Optional digital-human runtime stub gate when \`RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE=1\`; this verifies backend \`/digital-human/sessions\`, iOS \`TencentDigitalHumanRuntimeStub\`, and \`AudioOnlyDigitalHumanRuntime\` fallback without connecting the real Tencent SDK.
- Optional archive detail failed-analysis retry UIQA smoke when \`RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE=1\`.
- Optional hidden media/time-letter shell UIQA smoke when \`RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1\`.
- Optional hidden media combo gate when \`RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1\`; this runs the hidden media detail UIQA smoke and deployed backend hidden media sync smoke under one run-id.
- Optional archive media -> Echo context smoke when \`RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE=1\`; this verifies fake audio, pending video, and sealed/draft time-letter prompt injection rules.
- Media Echo context polish guard is documented in \`2026-06-19-archive-media-echo-context-polish.md\`.
- Optional P0 Profile care regression gate when \`RUN_P0_PROFILE_CARE_REGRESSION=1\`; this forces both local empty/stale/failed UIQA and deployed backend active/empty/stale/failed-retry UIQA.
- Optional Profile care empty/stale/failed state UIQA smoke when \`RUN_PROFILE_CARE_STATE_SMOKE=1\`.
- Optional deployed backend Profile care active/empty/stale UIQA smoke when \`RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=1\`.
- Optional release-like Postgres backend acceptance when \`RUN_RELEASE_LIKE_BACKEND=1\`.
- Release handoff mode forces release-like backend acceptance and hidden media combo gate; release-like backend acceptance cannot be disabled by \`RUN_RELEASE_LIKE_BACKEND=0\`.

EOF
}

append_report_footer() {
  cat >> "$REPORT_PATH" <<EOF
## Evidence

- Command log: \`commands.log\`
- Static guard logs: \`static-guards/\`
- Standard build log: \`build-debug.log\`
- iPhoneOS generic build: \`iphoneos-generic-build/$RUN_ID/\`
- Public MVP minimum regression: \`archive-to-echo-smoke/$RUN_ID/\`, \`profile-care-state-smoke/$RUN_ID/\`, and \`profile-care-backend-state-smoke/$RUN_ID/\`
- P0 Archive -> Echo regression gate: \`archive-to-echo-smoke/$RUN_ID/\`
- Archive -> Echo smoke: \`archive-to-echo-smoke/$RUN_ID/\`
- Echo delayed reply notification smoke: \`echo-delayed-reply-notification-smoke/$RUN_ID/\`
- Echo trace export UIQA smoke: \`echo-trace-export-smoke/$RUN_ID/\`
- Echo trace evidence package export UIQA smoke: \`echo-trace-evidence-package-export-smoke/$RUN_ID/\`
- Echo trace evidence package panel export UIQA smoke: \`echo-trace-evidence-package-panel-export-smoke/$RUN_ID/\`
- Echo QA evidence bundle export UIQA smoke: \`echo-qa-evidence-bundle-export-smoke/$RUN_ID/\`
- Echo digital-human lifecycle UIQA smoke: \`echo-digital-human-lifecycle-smoke/$RUN_ID/\`
- Echo Context Builder V2 backend smoke: \`echo-context-builder-v2-smoke/$RUN_ID/\`
- Backend env smoke: \`backend-env-smoke/$RUN_ID/\`
- Backend auth session/ownership shadow smoke: \`backend-auth-session-shadow-smoke/$RUN_ID/\`
- Backend cross-account authorization shadow smoke: \`backend-cross-account-authorization-shadow-smoke/$RUN_ID/\`
- Backend route ownership audit smoke: \`backend-route-ownership-audit-smoke/$RUN_ID/\`
- Backend deployed knowledge pipeline smoke: \`backend-knowledge-pipeline-smoke/$RUN_ID/\`
- Knowledge proposal/persona local smoke: \`knowledge-proposal-persona-smoke/$RUN_ID/\`
- Knowledge governance/source-cascade local gate: \`knowledge-governance-gate/$RUN_ID/\`
- Knowledge source identity cross-repository gate: \`static-guards/knowledge-source-identity-gate.log\`
- Knowledge privacy maintenance cross-repository gate: \`static-guards/knowledge-privacy-maintenance-gate.log\`
- Backend archive image-analysis smoke: \`backend-archive-image-analysis-smoke/$RUN_ID/\`
- Backend hidden media sync smoke: \`backend-hidden-media-sync-smoke/$RUN_ID/\`
- Backend time-letter lifecycle smoke: \`backend-time-letter-lifecycle-smoke/$RUN_ID/\`
- Backend family/voice contract smoke: \`backend-family-voice-contract-smoke/$RUN_ID/\`
- Backend family/account lifecycle smoke: \`backend-family-account-lifecycle-smoke/$RUN_ID/\`
- Backend digital-human session smoke: \`backend-digital-human-session-smoke/$RUN_ID/\`
- Backend voice clone deployed smoke: \`backend-voice-clone-deployed-smoke/$RUN_ID/\`
- Voice clone profile selection UIQA smoke: \`voice-clone-profile-selection-smoke/$RUN_ID/\`
- Voice clone synthesis runtime UIQA smoke: \`voice-clone-synthesis-runtime-smoke/$RUN_ID/\`
- Tencent backend PCM-drive mock UIQA smoke: \`tencent-backend-pcm-drive-mock-smoke/$RUN_ID/\`
- Digital-human + voice-clone combo gate: \`digital-human-voice-clone-combo-gate/$RUN_ID/\`
- Tencent digital-human Phase 1 non-device gate: \`tencent-digital-human-phase1-non-device-gate/$RUN_ID/\`
- Digital-human session lease gate: \`digital-human-session-lease-gate/$RUN_ID/\`
- Digital human TTS/viseme combo gate: \`digital-human-tts-viseme-gate/$RUN_ID/\`
- Digital human runtime stub gate: \`digital-human-runtime-stub-smoke/$RUN_ID/\`
- Archive failed analysis retry UIQA smoke: \`archive-failed-analysis-retry-smoke/$RUN_ID/\`
- Archive hidden media/time-letter shell UIQA smoke: \`archive-hidden-shell-smoke/$RUN_ID/\`
- Archive hidden media combo gate: \`archive-hidden-media-combo-gate/$RUN_ID/\`
- Archive media -> Echo context smoke: \`archive-media-echo-context-smoke/$RUN_ID/\`
- P0 Profile care regression gate: \`profile-care-state-smoke/$RUN_ID/\` and \`profile-care-backend-state-smoke/$RUN_ID/\`
- Profile care state UIQA smoke: \`profile-care-state-smoke/$RUN_ID/\`
- Profile care deployed backend state UIQA smoke: \`profile-care-backend-state-smoke/$RUN_ID/\`
- Release-like backend acceptance: \`release-like-backend/$RUN_ID/\`

EOF
}

append_report_header

cd "$ROOT_DIR"

if [[ -d "$BACKEND_ROOT" ]]; then
  run_step \
    "Backend verify" \
    "$STATIC_LOG_DIR/backend-verify.log" \
    bash -lc "cd '$BACKEND_ROOT' && BACKEND_API_TOKEN= BACKEND_BASE_URL= ./scripts/verify_backend.sh"
else
  echo "Backend repo missing at $BACKEND_ROOT; skipping backend verify." | tee "$STATIC_LOG_DIR/backend-verify.log"
fi

run_step "Python QA scripts compile" "$STATIC_LOG_DIR/python-qa-compile.log" \
  python3 -m py_compile \
    "$SCRIPT_DIR/backend-auth-token-contract-check.py" \
    "$SCRIPT_DIR/backend-auth-session-shadow-smoke.py" \
    "$SCRIPT_DIR/backend-cross-account-authorization-shadow-smoke.py" \
    "$SCRIPT_DIR/backend-route-ownership-audit-smoke.py" \
    "$SCRIPT_DIR/backend-integration-contract-check.py" \
    "$SCRIPT_DIR/backend-postgres-persistence-check.py" \
    "$SCRIPT_DIR/backend-archive-image-analysis-smoke.py" \
    "$SCRIPT_DIR/backend-hidden-media-sync-smoke.py" \
    "$SCRIPT_DIR/backend-time-letter-lifecycle-smoke.py" \
    "$SCRIPT_DIR/backend-family-voice-contract-smoke.py" \
    "$SCRIPT_DIR/backend-family-account-lifecycle-smoke.py" \
    "$SCRIPT_DIR/backend-digital-human-session-smoke.py" \
    "$SCRIPT_DIR/backend-voice-clone-deployed-smoke.py" \
    "$SCRIPT_DIR/backend-voice-synthesis-viseme-smoke.py"

run_step "Swift model guard profile-care-snapshot-check" "$STATIC_LOG_DIR/profile-care-snapshot-check.log" \
  bash -lc "swiftc -parse-as-library '$ROOT_DIR/DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift' '$SCRIPT_DIR/profile-care-snapshot-check.swift' -o '$STATIC_LOG_DIR/profile-care-snapshot-check' && '$STATIC_LOG_DIR/profile-care-snapshot-check' '$ROOT_DIR'"

run_step "Swift model guard archive-context-snapshot-check" "$STATIC_LOG_DIR/archive-context-snapshot-check.log" \
  bash -lc "swiftc -parse-as-library '$SCRIPT_DIR/archive-context-snapshot-check.swift' '$ROOT_DIR/DreamJourney/Sources/App/FeatureFlagService.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift' '$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift' -o '$STATIC_LOG_DIR/archive-context-snapshot-check' && '$STATIC_LOG_DIR/archive-context-snapshot-check'"

run_step "Swift model guard echo-digital-human-lifecycle-coordinator-check" "$STATIC_LOG_DIR/echo-digital-human-lifecycle-coordinator-check.log" \
  bash -lc "swiftc '$ROOT_DIR/DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift' '$SCRIPT_DIR/echo-digital-human-lifecycle-coordinator-check.swift' -o '$STATIC_LOG_DIR/echo-digital-human-lifecycle-coordinator-check' && '$STATIC_LOG_DIR/echo-digital-human-lifecycle-coordinator-check'"

run_step "Swift model guard knowledge-governance-model" "$STATIC_LOG_DIR/knowledge-governance-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-governance-model-smoke.sh"

run_step "Swift model guard knowledge-governance-outbox" "$STATIC_LOG_DIR/knowledge-governance-outbox-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-governance-outbox-model-smoke.sh"

run_step "Knowledge change-feed pagination cross-repository gate" "$STATIC_LOG_DIR/knowledge-change-feed-pagination-gate.log" \
  env BACKEND_ROOT="$BACKEND_ROOT" "$SCRIPT_DIR/run-knowledge-change-feed-pagination-gate.sh"

run_step "Knowledge source identity cross-repository gate" "$STATIC_LOG_DIR/knowledge-source-identity-gate.log" \
  env BACKEND_ROOT="$BACKEND_ROOT" "$SCRIPT_DIR/run-knowledge-source-identity-gate.sh"

if [[ "$RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE" == "1" ]]; then
  run_step "Knowledge privacy maintenance cross-repository gate" "$STATIC_LOG_DIR/knowledge-privacy-maintenance-gate.log" \
    env BACKEND_ROOT="$BACKEND_ROOT" "$SCRIPT_DIR/run-knowledge-privacy-maintenance-gate.sh"
else
  echo "Skipped by RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE=0" \
    > "$STATIC_LOG_DIR/knowledge-privacy-maintenance-gate.log"
fi

run_step "Swift model guard knowledge-governance-client" "$STATIC_LOG_DIR/knowledge-governance-client-check.log" \
  "$SCRIPT_DIR/run-knowledge-governance-client-check.sh"

run_step "Swift model guard knowledge-governance-coordinator" "$STATIC_LOG_DIR/knowledge-governance-coordinator-check.log" \
  "$SCRIPT_DIR/run-knowledge-governance-coordinator-check.sh"

run_step "Swift guard knowledge-governance-release-boundary" "$STATIC_LOG_DIR/knowledge-governance-release-boundary-check.log" \
  swift "$SCRIPT_DIR/knowledge-governance-release-boundary-check.swift" "$ROOT_DIR"

run_step "Swift model guard knowledge-three-way-merge" "$STATIC_LOG_DIR/knowledge-three-way-merge-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-three-way-merge-model-smoke.sh"

run_step "Swift model guard knowledge-context-policy" "$STATIC_LOG_DIR/knowledge-context-policy-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-context-policy-model-smoke.sh"

run_step "Swift model guard family-relationship-authorization" "$STATIC_LOG_DIR/family-relationship-authorization-policy-model-smoke.log" \
  "$SCRIPT_DIR/run-family-relationship-authorization-policy-model-smoke.sh"

run_step "Swift model guard family-authorization-freshness" "$STATIC_LOG_DIR/family-authorization-freshness-model-smoke.log" \
  "$SCRIPT_DIR/run-family-authorization-freshness-model-smoke.sh"

run_step "Swift model guard family-context-reconciliation" "$STATIC_LOG_DIR/family-context-reconciliation-model-smoke.log" \
  "$SCRIPT_DIR/run-family-context-reconciliation-model-smoke.sh"

run_step "Swift guard knowledge-async-authorization-snapshot" "$STATIC_LOG_DIR/knowledge-async-authorization-snapshot-check.log" \
  "$SCRIPT_DIR/run-knowledge-async-authorization-snapshot-check.sh"

run_step "Swift guard knowledge-coordinator-authorization-epoch" "$STATIC_LOG_DIR/knowledge-coordinator-authorization-epoch-check.log" \
  "$SCRIPT_DIR/run-knowledge-coordinator-authorization-epoch-check.sh"

run_step "Swift guard family-repository-authorization-lifecycle" "$STATIC_LOG_DIR/family-repository-authorization-lifecycle-check.log" \
  "$SCRIPT_DIR/run-family-repository-authorization-lifecycle-check.sh"

run_step "Swift guard echo-family-context-authorization" "$STATIC_LOG_DIR/echo-family-context-authorization-check.log" \
  "$SCRIPT_DIR/run-echo-family-context-authorization-check.sh"

run_step "Swift guard family-context-reconciliation" "$STATIC_LOG_DIR/family-context-reconciliation-check.log" \
  "$SCRIPT_DIR/run-family-context-reconciliation-check.sh"

run_step "Swift guard knowledge-family-sync-import-authorization" "$STATIC_LOG_DIR/knowledge-family-sync-import-authorization-check.log" \
  "$SCRIPT_DIR/run-knowledge-family-sync-import-authorization-check.sh"

run_step "Swift model guard knowledge-widget-privacy-policy" "$STATIC_LOG_DIR/knowledge-widget-privacy-policy-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-widget-privacy-policy-model-smoke.sh"

run_step "Swift model guard knowledge-widget-snapshot-store" "$STATIC_LOG_DIR/knowledge-widget-snapshot-store-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-widget-snapshot-store-model-smoke.sh"

run_step "Swift model guard knowledge-widget-snapshot-reader" "$STATIC_LOG_DIR/knowledge-widget-snapshot-reader-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-widget-snapshot-reader-model-smoke.sh"

run_step "Swift model guard knowledge-proposal" "$STATIC_LOG_DIR/knowledge-proposal-model-smoke.log" \
  "$SCRIPT_DIR/run-knowledge-proposal-model-smoke.sh"

for guard in \
  release-feature-matrix-check.swift \
  prd-coverage-matrix-check.swift \
  prd-full-feature-closure-decisions-check.swift \
  echo-state-machine-runtime-check.swift \
  echo-waiting-reply-policy-check.swift \
  echo-delayed-reply-notification-check.swift \
  echo-delayed-reply-push-contract-check.swift \
  echo-delayed-reply-dispatch-contract-check.swift \
  phase0-backend-alignment-check.swift \
  backend-voice-runtime-contract-check.swift \
  voice-sdk-readiness-boundary-check.swift \
  release-like-backend-acceptance-check.swift \
  backend-env-smoke-check.swift \
  backend-contract-gap-check.swift \
  care-snapshot-backend-state-fixtures-check.swift \
  login-password-contract-check.swift \
  auth-session-ownership-shadow-check.swift \
  cross-account-authorization-policy-check.swift \
  route-ownership-audit-check.swift \
  knowledge-pipeline-check.swift \
  knowledge-evidence-context-policy-check.swift \
  knowledge-proposal-persona-policy-check.swift \
  knowledge-widget-privacy-lifecycle-check.swift \
  profile-settings-save-state-check.swift \
  profile-account-fields-check.swift \
  profile-password-change-check.swift \
  profile-care-public-placeholder-check.swift \
  archive-ownership-visibility-check.swift \
  archive-analysis-disclaimer-check.swift \
  archive-sync-error-recovery-check.swift \
  archive-local-file-path-recovery-check.swift \
  archive-feature-card-ia-check.swift \
  archive-audio-ia-release-check.swift \
  archive-audio-lifecycle-smoke-check.swift \
  true-device-archive-audio-acceptance-check.swift \
  true-device-acceptance-evidence-package-check.swift \
  archive-media-backend-contract-check.swift \
  archive-media-upload-intent-contract-check.swift \
  archive-media-provider-switch-contract-check.swift \
  archive-hidden-media-timeletter-shell-check.swift \
  time-letter-delivery-policy-shell-check.swift \
  in-app-message-center-shell-check.swift \
  archive-hidden-media-backend-upload-lifecycle-check.swift \
  archive-time-letter-backend-lifecycle-check.swift \
  archive-hidden-media-detail-ui-check.swift \
  archive-video-hidden-readiness-check.swift \
  archive-hidden-media-runtime-ui-check.swift \
  archive-hidden-media-combo-gate-check.swift \
  archive-media-echo-context-polish-check.swift \
  archive-analysis-insights-contract-check.swift \
  archive-analysis-backend-payload-contract-check.swift \
  archive-image-analysis-live-chain-check.swift \
  archive-image-analysis-runtime-contract-check.swift \
  archive-image-analysis-runtime-ui-check.swift \
  backend-archive-image-analysis-smoke-check.swift \
  p0-archive-analysis-care-retry-check.swift \
  archive-failed-analysis-retry-smoke-check.swift \
  profile-care-state-smoke-check.swift \
  profile-care-backend-state-smoke-check.swift \
  family-digital-human-hidden-contract-check.swift \
  backend-family-voice-contract-smoke-check.swift \
  backend-digital-human-session-smoke-check.swift \
  backend-voice-clone-deployed-smoke-check.swift \
  voice-clone-profile-selection-smoke-check.swift \
  voice-clone-synthesis-runtime-smoke-check.swift \
  tencent-backend-pcm-drive-mock-smoke-check.swift \
  profile-family-account-lifecycle-check.swift \
  voice-synthesis-viseme-contract-check.swift \
  voice-synthesis-tencent-audio-drive-contract-check.swift \
  memoir-tts-cache-contract-check.swift \
  qa-script-location-check.swift \
  docs-qa-script-path-check.swift \
  digital-human-live-panel-check.swift \
  digital-human-conversation-coordinator-check.swift \
  digital-human-runtime-abstraction-check.swift \
  digital-human-session-client-check.swift \
  tencent-digital-human-sdk-handoff-check.swift \
  tencent-digital-human-pcm-drive-poc-check.swift \
  true-device-tencent-backend-pcm-drive-smoke-check.swift \
  tencent-digital-human-voice-clone-route-check.swift \
  echo-role-voice-profile-selection-check.swift \
  tencent-voice-clone-echo-contract-check.swift \
  context-packet-v1-check.swift \
  context-packet-v2-trace-check.swift \
  echo-context-v2-clue-panel-check.swift \
  echo-trace-export-check.swift \
  echo-runtime-diagnostics-check.swift \
  echo-trace-evidence-package-check.swift \
  echo-qa-evidence-bundle-check.swift \
  echo-readiness-report-check.swift \
  installable-simulator-uiqa-bundle-guard-check.swift \
  iphoneos-generic-build-check.swift \
  tencent-digital-human-provider-stability-check.swift \
  tencent-digital-human-phase1-stability-check.swift \
  digital-human-session-lease-check.swift \
  echo-digital-human-phase2-stability-check.swift \
  tencent-digital-human-audio-owner-stop-semantics-check.swift \
  echo-audio-owner-lifecycle-guard-check.swift \
  echo-digital-human-lifecycle-audio-route-check.swift \
  echo-digital-human-lifecycle-uiqa-smoke-check.swift \
  tencent-digital-human-trtc-compat-check.swift \
  tencent-digital-human-sdk-binary-check.swift \
  tencent-digital-human-cloud-runtime-smoke.swift \
  digital-human-tts-viseme-gate-check.swift \
  ios-family-voice-consumer-contract-check.swift \
  ios-family-voice-hidden-uiqa-smoke-check.swift \
  voice-clone-shell-contract-check.swift \
  voice-clone-stale-ready-state-check.swift \
  voice-clone-status-feedback-check.swift \
  voice-clone-runtime-capability-check.swift \
  voice-clone-backend-contract-check.swift \
  digital-human-voice-clone-combo-gate-check.swift \
  final-visual-qa-package-check.swift \
  release-qa-package-check.swift
do
  run_step "Swift guard $guard" "$STATIC_LOG_DIR/${guard%.swift}.log" \
    swift "$SCRIPT_DIR/$guard" "$ROOT_DIR"
done

run_step "iOS git diff --check" "$STATIC_LOG_DIR/ios-diff-check.log" \
  git diff --check

if [[ -d "$BACKEND_ROOT/.git" ]]; then
  run_step "Backend git diff --check" "$STATIC_LOG_DIR/backend-diff-check.log" \
    bash -lc "cd '$BACKEND_ROOT' && git diff --check"
fi

if [[ "$RUN_STANDARD_BUILD" == "1" ]]; then
  run_step "iOS Debug simulator build" "$BUILD_LOG" \
    xcodebuild \
      -workspace DreamJourney.xcworkspace \
      -scheme DreamJourney \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$OUTPUT_DIR/DerivedData" \
      CODE_SIGNING_ALLOWED=NO \
      build
else
  echo "Skipped by RUN_STANDARD_BUILD=0" > "$BUILD_LOG"
fi

if [[ "$RUN_IPHONEOS_GENERIC_BUILD" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/iphoneos-generic-build" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataIPhoneOSGenericBuild" \
  "$SCRIPT_DIR/run-iphoneos-generic-build.sh"
else
  mkdir -p "$OUTPUT_DIR/iphoneos-generic-build/$RUN_ID"
  echo "Skipped by RUN_IPHONEOS_GENERIC_BUILD=0" > "$OUTPUT_DIR/iphoneos-generic-build/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_SIMULATOR_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-to-echo-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveToEchoSmoke" \
  "$SCRIPT_DIR/run-archive-to-echo-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-to-echo-smoke/$RUN_ID"
  echo "Skipped by RUN_SIMULATOR_SMOKE=0" > "$OUTPUT_DIR/archive-to-echo-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-delayed-reply-notification-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoDelayedReplyNotificationSmoke" \
  "$SCRIPT_DIR/run-echo-delayed-reply-notification-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-delayed-reply-notification-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0" > "$OUTPUT_DIR/echo-delayed-reply-notification-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-trace-export-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoTraceExportSmoke" \
  "$SCRIPT_DIR/run-echo-trace-export-uiqa-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-trace-export-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE=0" > "$OUTPUT_DIR/echo-trace-export-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-trace-evidence-package-export-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoTraceEvidencePackageExportSmoke" \
  "$SCRIPT_DIR/run-echo-trace-evidence-package-export-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-trace-evidence-package-export-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE=0" > "$OUTPUT_DIR/echo-trace-evidence-package-export-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-trace-evidence-package-panel-export-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoTraceEvidencePackagePanelExportSmoke" \
  "$SCRIPT_DIR/run-echo-trace-evidence-package-panel-export-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-trace-evidence-package-panel-export-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE=0" > "$OUTPUT_DIR/echo-trace-evidence-package-panel-export-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-qa-evidence-bundle-export-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoQAEvidenceBundleExportSmoke" \
  "$SCRIPT_DIR/run-echo-qa-evidence-bundle-export-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-qa-evidence-bundle-export-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE=0" > "$OUTPUT_DIR/echo-qa-evidence-bundle-export-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-digital-human-lifecycle-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataEchoDigitalHumanLifecycleSmoke" \
  "$SCRIPT_DIR/run-echo-digital-human-lifecycle-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-digital-human-lifecycle-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE=0" > "$OUTPUT_DIR/echo-digital-human-lifecycle-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_READINESS_REPORT" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/echo-readiness-report" \
  "$SCRIPT_DIR/run-echo-readiness-report.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-readiness-report/$RUN_ID"
  echo "Skipped by RUN_ECHO_READINESS_REPORT=0" > "$OUTPUT_DIR/echo-readiness-report/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_ENV_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_ENV_SMOKE=1" >&2
    exit 1
  }
  [[ -n "${BACKEND_API_TOKEN:-}" ]] || {
    echo "BACKEND_API_TOKEN is required for RUN_BACKEND_ENV_SMOKE=1" >&2
    exit 1
  }
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-env-smoke" \
  "$SCRIPT_DIR/run-backend-env-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-env-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_ENV_SMOKE=0" > "$OUTPUT_DIR/backend-env-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE=1" >&2
    exit 1
  }
  DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  DREAMJOURNEY_BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  AUTH_SESSION_SMOKE_OUTPUT_DIR="$OUTPUT_DIR/backend-auth-session-shadow-smoke/$RUN_ID" \
  "$SCRIPT_DIR/run-backend-auth-session-shadow-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-auth-session-shadow-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_AUTH_SESSION_SHADOW_SMOKE=0" > "$OUTPUT_DIR/backend-auth-session-shadow-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE=1" >&2
    exit 1
  }
  DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  DREAMJOURNEY_BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  CROSS_ACCOUNT_AUTH_SMOKE_OUTPUT_DIR="$OUTPUT_DIR/backend-cross-account-authorization-shadow-smoke/$RUN_ID" \
  "$SCRIPT_DIR/run-backend-cross-account-authorization-shadow-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-cross-account-authorization-shadow-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_CROSS_ACCOUNT_AUTH_SHADOW_SMOKE=0" > "$OUTPUT_DIR/backend-cross-account-authorization-shadow-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE=1" >&2
    exit 1
  }
  DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  DREAMJOURNEY_BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  ROUTE_OWNERSHIP_AUDIT_OUTPUT_DIR="$OUTPUT_DIR/backend-route-ownership-audit-smoke/$RUN_ID" \
  "$SCRIPT_DIR/run-backend-route-ownership-audit-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-route-ownership-audit-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE=0" > "$OUTPUT_DIR/backend-route-ownership-audit-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE" == "1" ]]; then
  [[ -n "${BACKEND_BASE_URL:-}" ]] || {
    echo "BACKEND_BASE_URL is required for RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE=1" >&2
    exit 1
  }
  mkdir -p "$OUTPUT_DIR/backend-knowledge-pipeline-smoke/$RUN_ID"
  BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  BACKEND_API_TOKEN="${BACKEND_API_TOKEN:-}" \
  "$BACKEND_ROOT/scripts/run-backend-knowledge-deployed-smoke.sh" \
    | tee "$OUTPUT_DIR/backend-knowledge-pipeline-smoke/$RUN_ID/result.json"
else
  mkdir -p "$OUTPUT_DIR/backend-knowledge-pipeline-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE=0" > "$OUTPUT_DIR/backend-knowledge-pipeline-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE" == "1" ]]; then
  mkdir -p "$OUTPUT_DIR/knowledge-proposal-persona-smoke/$RUN_ID"
  "$BACKEND_ROOT/scripts/run-backend-knowledge-proposal-persona-smoke.sh" \
    | tee "$OUTPUT_DIR/knowledge-proposal-persona-smoke/$RUN_ID/result.log"
else
  mkdir -p "$OUTPUT_DIR/knowledge-proposal-persona-smoke/$RUN_ID"
  echo "Skipped by RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE=0" \
    > "$OUTPUT_DIR/knowledge-proposal-persona-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_KNOWLEDGE_GOVERNANCE_GATE" == "1" ]]; then
  mkdir -p "$OUTPUT_DIR/knowledge-governance-gate/$RUN_ID"
  run_step \
    "Knowledge governance/source-cascade cross-repository gate" \
    "$OUTPUT_DIR/knowledge-governance-gate/$RUN_ID/result.log" \
    env BACKEND_ROOT="$BACKEND_ROOT" "$SCRIPT_DIR/run-knowledge-governance-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/knowledge-governance-gate/$RUN_ID"
  echo "Skipped by RUN_KNOWLEDGE_GOVERNANCE_GATE=0" \
    > "$OUTPUT_DIR/knowledge-governance-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-archive-image-analysis-smoke" \
  "$SCRIPT_DIR/run-backend-archive-image-analysis-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-archive-image-analysis-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE=0" > "$OUTPUT_DIR/backend-archive-image-analysis-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-hidden-media-sync-smoke" \
  "$SCRIPT_DIR/run-backend-hidden-media-sync-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-hidden-media-sync-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE=0" > "$OUTPUT_DIR/backend-hidden-media-sync-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-time-letter-lifecycle-smoke" \
  "$SCRIPT_DIR/run-backend-time-letter-lifecycle-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-time-letter-lifecycle-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE=0" > "$OUTPUT_DIR/backend-time-letter-lifecycle-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/time-letter-dispatch-reminder-smoke" \
  "$SCRIPT_DIR/run-time-letter-dispatch-reminder-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/time-letter-dispatch-reminder-smoke/$RUN_ID"
  echo "Skipped by RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE=0" > "$OUTPUT_DIR/time-letter-dispatch-reminder-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE" == "1" ]]; then
  mkdir -p "$OUTPUT_DIR/echo-context-builder-v2-smoke/$RUN_ID"
  run_step \
    "Echo Context Builder V2 backend smoke" \
    "$OUTPUT_DIR/echo-context-builder-v2-smoke/$RUN_ID/echo-context-builder-v2-smoke.log" \
    bash -lc "cd '$BACKEND_ROOT' && ./scripts/run-echo-context-builder-v2-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/echo-context-builder-v2-smoke/$RUN_ID"
  echo "Skipped by RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE=0" > "$OUTPUT_DIR/echo-context-builder-v2-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-family-voice-contract-smoke" \
  "$SCRIPT_DIR/run-backend-family-voice-contract-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-family-voice-contract-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE=0" > "$OUTPUT_DIR/backend-family-voice-contract-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-family-account-lifecycle-smoke" \
  "$SCRIPT_DIR/run-backend-family-account-lifecycle-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-family-account-lifecycle-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE=0" > "$OUTPUT_DIR/backend-family-account-lifecycle-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-digital-human-session-smoke" \
  "$SCRIPT_DIR/run-backend-digital-human-session-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-digital-human-session-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE=0" > "$OUTPUT_DIR/backend-digital-human-session-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/backend-voice-clone-deployed-smoke" \
  "$SCRIPT_DIR/run-backend-voice-clone-deployed-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/backend-voice-clone-deployed-smoke/$RUN_ID"
  echo "Skipped by RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE=0" > "$OUTPUT_DIR/backend-voice-clone-deployed-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/voice-clone-profile-selection-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataVoiceCloneProfileSelectionSmoke" \
  "$SCRIPT_DIR/run-voice-clone-profile-selection-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/voice-clone-profile-selection-smoke/$RUN_ID"
  echo "Skipped by RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE=0" > "$OUTPUT_DIR/voice-clone-profile-selection-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/voice-clone-synthesis-runtime-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataVoiceCloneSynthesisRuntimeSmoke" \
  "$SCRIPT_DIR/run-voice-clone-synthesis-runtime-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/voice-clone-synthesis-runtime-smoke/$RUN_ID"
  echo "Skipped by RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=0" > "$OUTPUT_DIR/voice-clone-synthesis-runtime-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/tencent-backend-pcm-drive-mock-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataTencentBackendPCMDriveMockSmoke" \
  "$SCRIPT_DIR/run-tencent-backend-pcm-drive-mock-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/tencent-backend-pcm-drive-mock-smoke/$RUN_ID"
  echo "Skipped by RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE=0" > "$OUTPUT_DIR/tencent-backend-pcm-drive-mock-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/digital-human-voice-clone-combo-gate" \
  "$SCRIPT_DIR/run-digital-human-voice-clone-combo-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/digital-human-voice-clone-combo-gate/$RUN_ID"
  echo "Skipped by RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE=0" > "$OUTPUT_DIR/digital-human-voice-clone-combo-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/tencent-digital-human-phase1-non-device-gate" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataTencentPhase1NonDeviceGate" \
  RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=0 \
  "$SCRIPT_DIR/run-tencent-digital-human-phase1-non-device-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/tencent-digital-human-phase1-non-device-gate/$RUN_ID"
  echo "Skipped by RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=0" > "$OUTPUT_DIR/tencent-digital-human-phase1-non-device-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/digital-human-session-lease-gate" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataDigitalHumanSessionLeaseGate" \
  "$SCRIPT_DIR/run-digital-human-session-lease-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/digital-human-session-lease-gate/$RUN_ID"
  echo "Skipped by RUN_DIGITAL_HUMAN_SESSION_LEASE_GATE=0" > "$OUTPUT_DIR/digital-human-session-lease-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_DIGITAL_HUMAN_TTS_VISEME_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/digital-human-tts-viseme-gate" \
  "$SCRIPT_DIR/run-digital-human-tts-viseme-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/digital-human-tts-viseme-gate/$RUN_ID"
  echo "Skipped by RUN_DIGITAL_HUMAN_TTS_VISEME_GATE=0" > "$OUTPUT_DIR/digital-human-tts-viseme-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/digital-human-runtime-stub-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataDigitalHumanRuntimeStubSmoke" \
  "$SCRIPT_DIR/run-digital-human-runtime-stub-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/digital-human-runtime-stub-smoke/$RUN_ID"
  echo "Skipped by RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE=0" > "$OUTPUT_DIR/digital-human-runtime-stub-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-failed-analysis-retry-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveFailedAnalysisRetrySmoke" \
  "$SCRIPT_DIR/run-archive-failed-analysis-retry-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-failed-analysis-retry-smoke/$RUN_ID"
  echo "Skipped by RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE=0" > "$OUTPUT_DIR/archive-failed-analysis-retry-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ARCHIVE_HIDDEN_SHELL_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-hidden-shell-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveHiddenShellSmoke" \
  "$SCRIPT_DIR/run-archive-hidden-shell-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-hidden-shell-smoke/$RUN_ID"
  echo "Skipped by RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=0" > "$OUTPUT_DIR/archive-hidden-shell-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-hidden-media-combo-gate" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveHiddenMediaComboGate" \
  "$SCRIPT_DIR/run-archive-hidden-media-combo-gate.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-hidden-media-combo-gate/$RUN_ID"
  echo "Skipped by RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=0" > "$OUTPUT_DIR/archive-hidden-media-combo-gate/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/archive-media-echo-context-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataArchiveMediaEchoContextSmoke" \
  "$SCRIPT_DIR/run-archive-media-echo-context-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/archive-media-echo-context-smoke/$RUN_ID"
  echo "Skipped by RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE=0" > "$OUTPUT_DIR/archive-media-echo-context-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_PROFILE_CARE_STATE_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/profile-care-state-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataProfileCareStateSmoke" \
  "$SCRIPT_DIR/run-profile-care-state-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/profile-care-state-smoke/$RUN_ID"
  echo "Skipped by RUN_PROFILE_CARE_STATE_SMOKE=0" > "$OUTPUT_DIR/profile-care-state-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_PROFILE_CARE_BACKEND_STATE_SMOKE" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/profile-care-backend-state-smoke" \
  DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataProfileCareBackendStateSmoke" \
  "$SCRIPT_DIR/run-profile-care-backend-state-smoke.sh"
else
  mkdir -p "$OUTPUT_DIR/profile-care-backend-state-smoke/$RUN_ID"
  echo "Skipped by RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=0" > "$OUTPUT_DIR/profile-care-backend-state-smoke/$RUN_ID/skipped.txt"
fi

if [[ "$RUN_RELEASE_LIKE_BACKEND" == "1" ]]; then
  RUN_ID="$RUN_ID" \
  OUTPUT_ROOT="$OUTPUT_DIR/release-like-backend" \
  "$SCRIPT_DIR/run-release-like-backend-acceptance.sh"
else
  mkdir -p "$OUTPUT_DIR/release-like-backend/$RUN_ID"
  echo "Skipped by RUN_RELEASE_LIKE_BACKEND=0" > "$OUTPUT_DIR/release-like-backend/$RUN_ID/skipped.txt"
fi

append_report_footer

echo "[release-regression] Report: $REPORT_PATH"
echo "[release-regression] Command log: $COMMAND_LOG"
