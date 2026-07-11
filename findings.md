# Findings

## Active Context

- Goal: 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态
- Closure Lodestar mode: Lodestar outer protocol plus recursive task ledgers.

## Explore Progress

- Initialized project memory.

## Confirmed Requirements

- 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态

## Constraints

- Keep Lodestar Markdown as project-level source of truth.
- Keep recursive `.complex-problems/` as task-level closure state.

## Available Skills

- Lodestar
- Closure Lodestar ledger engine
- closure-lodestar

## Task 14 Knowledge Architecture Findings

- `KBLiteManager` currently sends both user and assistant turns as one plain transcript to `/kb/extract`; the local regex fallback already filters to user turns. This creates a provider-side self-ingestion risk that must be closed with indexed structured turns and server-side source validation.
- Current extracted entities expose `sourceTurnIndices`, but the backend does not validate that indices point to user turns. A provider result can therefore claim no source or an assistant-only source and still be merged.
- `KBFact` already has `confidence`, but both backend Context Packet and iOS local generation fallback can include low/medium facts. P0 policy is high/confirmed only for generation; lower confidence remains a stored candidate.
- Archive is the source asset authority. The knowledge graph stores source references and normalized entities; it must not duplicate media files or become a fourth public Tab.
- Voice clone and digital-human runtime are execution state and trace only, never durable user facts.
- Context policy needs explicit regression for time-letter recipient mismatch and care viewer isolation in addition to existing not-due/pending-family cases.
- The existing root-level `docs/knowledge-base-design*.md` predates the backend revisioned pipeline. The canonical design is now `docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`; vector search remains threshold-driven rather than an immediate dependency.

## Task 14 Resolution

- `/kb/extract` v2 now accepts indexed turns and enforces `userEvidenceOnly`; every accepted entity must reference valid user turns, while legacy transcript remains compatible and the iOS legacy field is user-only.
- Backend and iOS generation paths now require `generationAllowed + high/confirmed` for facts. Low/medium candidates remain stored but are observable through filtered reasons.
- Family persona no longer consumes the viewer's personal KBLite in backend candidates or iOS fallback. Context packet user/persona/digital-human identity is checked before SDK submission.
- Time-letter recipient/openAt and care viewer-specific access have negative tests; owner care cannot silently replace missing viewer care.
- Backend 204 tests/full verify, release regression, simulator smoke, generic Simulator and generic iPhoneOS builds passed. No true-device test was run.
- Remaining P1 work is proposal normalization, persona-scoped entity metadata, source ingestion/retraction, change-feed productionization and local privacy/cache/log hardening.

## Task 15 Knowledge Proposal Findings

- `/kb/extract` currently returns provider-shaped entities only; iOS assigns random UUIDs and resolves duplicates by local name matching, so retries and multiple devices cannot share stable identity.
- The backend already owns the authoritative KB snapshot/revision and Mutation V2 validator, making it the correct place to build a non-persisting, revision-bound mutation proposal.
- Extracted relation fields are names, while stored graph relations are IDs. Resolution must use both existing snapshot entities and current proposal entities before the result reaches iOS.
- KBLite storage is per signed-in user, but entities do not yet carry persona metadata. Family Context currently blocks all KB facts; it can only safely consume facts after explicit `personaScope=family` and matching `digitalHumanId` are persisted.
- `ConversationMemoryManager.endSession()` starts extraction after clearing the active transcript and currently does not capture persona identity. The identity must be snapshotted with the transcript so later role changes cannot relabel asynchronous results.
- Backward compatibility requires old entities without persona fields to remain personal/self-only; they must never be inferred as family knowledge.

## Task 15 Resolution

- `/kb/extract` v2 now returns a non-persisting, revision-bound Mutation V2 proposal with stable IDs, snapshot legacy-ID reuse, normalized relationships, redacted sources and persona/evidence metadata.
- Backend Context uses one eligible fact set for memory, selection and generation. Personal legacy remains readable; family requires exact owner/family/digital-human metadata and observed/confirmed evidence.
- iOS decodes proposal envelopes strictly, snapshots canonical persona identity at session end, discards stale role callbacks, remaps proposal relationships to local legacy IDs and keeps old server/local graph compatibility.
- Existing summaries and local generation fallbacks are now privacy/persona/evidence filtered; family local fallback remains forbidden.
- Backend 213-test verify, release regression, Simulator smoke and generic Simulator/iPhoneOS builds passed. True-device verification was intentionally not run.

## Technical Decisions

- Use `.closure-lodestar/task-ledgers.json` to map Lodestar task files to recursive ledger IDs.

## Resolved Issues

- The configured trial speaker pool is currently selected by deterministic hash. Different logical profiles can collide on the same provider `S_` speaker and retrain/overwrite one another.
- `/voice/synthesis` currently forwards the caller-provided `voiceProfileId` to the provider without first proving that the profile belongs to the requesting user and is ready, enabled, and quality-accepted.
- Current status documentation predates the 2026-07-02/03 role-routing and trial-slot rotation commits and must be refreshed before handoff.
- All three issues were closed by Task 6 and verified through ledger `L20260710-115209`.

## Task 6 Decisions

- Keep app-facing `voiceProfileId` stable and provider-agnostic; store the VolcEngine `S_` identifier separately as `providerSpeakerId`.
- Allocate configured pool slots exclusively and atomically. Never use hash modulo as the production allocator.
- A deleted slot is retired rather than automatically recycled, preventing a subsequent user from inheriting residual provider voice data.
- Existing profiles whose logical ID is already an `S_` provider ID remain readable through a legacy compatibility path.
- Synthesis must resolve and authorize a persisted profile before calling the provider; provider failures remain explicit and do not silently switch voices.

## Task 7 Issues

- Session and PCM work use request/context IDs, but capability, realtime-token, synthesis completion, and delayed microphone-resume callbacks do not share one lifecycle generation.
- `didEnterBackground` releases the Tencent runtime immediately; there is no cancellable grace period for brief app switching.
- Tencent quota exhaustion is included in the one-shot automatic recovery path even though the product requirement is an immediate ordinary-Echo fallback.
- Existing stop/session/audio-owner behavior is mostly correct and should be strengthened rather than replaced.

## Task 7 Resolution

- A single lifecycle coordinator now separates session generation from interaction generation. Role/page/background expiry invalidates session work; stop and barge-in invalidate only the current interaction.
- Every session/runtime/capability/voice synthesis/PCM/delayed-resume path touched by Phase 2 validates its captured token before changing current Echo state.
- Runtime ownership is bound to lifecycle generation, duplicate runtime instances are closed before replacement, and page exit always releases the provider regardless of DialogEngine delegate ownership.
- Background release uses an 8-second cancellable lease. Foreground cancellation preserves the provider view and never auto-starts the microphone; expiry releases the session.
- Quota failures are terminal for the current provider attempt and fall back to ordinary Echo without retrying or retaining the prior role's audio.
- PCM send failure clears the failed provider request while preserving the pending microphone-resume state.
- Non-device evidence passed; real Tencent audio, rendered lip movement, AVAudioSession contention, tap interruption, and microphone recovery still require a later true-device pass.

## Task 8 Resolution

- Backend digital-human sessions now use a persisted lease contract with same-context reuse, same-device context replacement, heartbeat renewal, explicit idempotent release, TTL recovery, and structured capacity conflicts.
- Postgres arbitration takes transaction-scoped advisory locks for the device and provider resource before capacity decisions, so multiple workers cannot concurrently allocate the same single-capacity asset.
- Lease persistence contains identifiers, lifecycle metadata, timestamps, and status only; Tencent appkey, accesstoken, and credential payloads remain ephemeral.
- iOS keeps one active lease with the Tencent runtime, schedules heartbeat while its session generation is current, and releases on role switch, page exit, background grace expiry, provider terminal failure, and stale successful responses.
- User stop invalidates only the current conversation and does not release the provider lease, preserving continuous Echo behavior.
- The simulator runtime smoke now performs create, heartbeat, and release, preventing QA runs from leaving capacity occupied until TTL.
- Final non-device evidence: `tmp/visual-qa/prd-stitch-ui/digital-human-session-lease-gate/20260710-session-lease-final/report.md`.
- Backend commit `e9b3104` is deployed and the Postgres session smoke passed; real Tencent quota release timing and true-device audio/render behavior remain explicit follow-up acceptance boundaries.

## Task 10 Resolution

- A dedicated `CrossAccountAuthorizationPolicy` now distinguishes owner, accepted family viewer, time-letter recipient, invitation recipient, system-only, and legacy ownership fallback decisions.
- Care snapshot reads, time-letter detail, and invitation acceptance bind the verified bearer principal even while global ownership remains `shadow`; forged viewers no longer receive sensitive content.
- Middleware exposes fixed-enum authorization policy/decision/reason headers, marks legal delegation separately, and hashes identifiers in application logs.
- `/config/runtime` reports `crossAccountPolicy.contractVersion=1` and `productionEnforceReady=false` so deployments cannot mistake this slice for complete production authorization.
- Final non-device evidence: `tmp/visual-qa/prd-stitch-ui/release-regression/20260710-cross-account-auth-final/report.md`.
- Deployed Postgres shadow evidence and the full-route audit were completed by Task 11; SMS identity proof and global enforce promotion remain explicit follow-ups.

## Task 11 Resolution

- A single `RouteOwnershipRegistry` now classifies all 54 FastAPI business routes as public, authenticated service, user session, owner body/path, delegated, or system-only; tests fail for omissions or duplicates.
- Owner-bound mismatches and user calls to system-only routes now return 403 even while the global mode remains `shadow`; unknown/unclassified behavior is not globally promoted to enforce.
- Delegated family, invitation, care, and time-letter recipient policies remain explicit and passed both local and deployed Postgres smoke.
- Large JSON bodies no longer bypass principal inspection, and the immutable route registry is compiled once per process rather than once per request.
- iOS mailbox refresh no longer triggers global time-letter dispatch; the enabled server timer owns due delivery.
- Backend `275a4c2` is deployed. Online evidence reports `routeCount=54`, `unclassifiedCount=0`, principal-bound owner/system denies, valid delegated access, production Postgres health, and an active time-letter timer.

## Task 16 Exploration

- Existing Mutation V2 already supplies revision conflicts, operation-ID idempotency, atomic Postgres advisory locking, authoritative graph responses, tombstones, and change feed; governance should compose this layer rather than create another persistence system.
- Existing evidence policy already excludes `rejected/superseded` from backend Context and iOS generation. Governance therefore needs authoritative state transitions and audit metadata, not a second retrieval policy.
- Existing generic `/kb/mutations` accepts arbitrary entity upserts and cannot prove that a correction preserved history. A dedicated owner-only governance endpoint is required to build the mutation from the current server snapshot.
- A correction must create a replacement entity and mark the original `superseded`; editing the original ID would violate the canonical design requirement that user actions form a new mutation instead of silently rewriting history.
- Source deletion is an evidence revocation, not an entity tombstone. The conservative P1 contract marks every directly referencing entity `superseded`, removes the deleted source ref, and keeps the entity for audit/change-feed history.
- iOS already owns per-user base/pending persistence and authoritative three-way merge. Governance consumption should be serialized through `KnowledgeSyncCoordinator` and apply the server graph only while user/persona generation remains current.
- Postgres `archive_items.id` is globally unique and its generic upsert currently rewrites `user_id` on conflict. Source lifecycle work must first prevent a different owner from reusing an existing archive ID; otherwise a cascade target could be reassigned before deletion.
- Current Archive deletion removes only the Archive record/local item and does not touch knowledge `sourceRefs`; the production path therefore needs an explicit source-revocation step, not merely a new standalone governance API.
- Current proposal ingestion intentionally merges `observed` knowledge immediately and Context allows `observed/confirmed`. Task 16 adds user override/governance, not a mandatory approval queue; changing every extraction to pending would be a separate product decision and would materially change current Echo behavior.
- Existing image-analysis ingestion still uses session-derived source IDs rather than canonical Archive item IDs. New source-backed ingestion must use `memoryArchiveItem + archiveItem.id`; legacy records without that ref cannot be retroactively cascaded without a migration heuristic and must not be falsely reported as covered.

## Task 19 Resolution

- Task 16 对历史 `archiveImageAnalysis` 的推断已被代码审计纠正：这些 ref 来自 `AIRecordingViewController` 的对话照片，并非 `MemoryArchiveItem`，不能猜测迁成 Archive item。
- 新对话文字使用精确的 `conversationTurn + session-{sessionId}:turn-{turnIndex}`；新对话照片使用 `conversationPhoto + photo-{stableAssetId}`；Archive 仍使用 `memoryArchiveItem + archiveItem.id`。
- 后端忽略请求级 source refs，只根据服务端校验的 session/turn 证据生成 canonical refs；既有 refs 被保留，不静默删除 legacy 历史。
- `/kb/source-ref-audit/{userId}` 只返回聚合计数和建议动作，owner principal 绑定，跨账号访问被拒绝，不返回 graph、正文或 source ID。
- 跨仓 source identity gate 已进入默认 release regression。后端 `dd88f17` 已部署，线上 Postgres smoke 证明 canonical count、权限和聚合隐私边界；iOS `fc5772d` 已推送。
- 历史 legacy ref 的真实迁移仍需独立批准和可证明的来源映射，本任务没有 apply migration API。

## Task 20 Exploration

- V2 graph 会通过 `filter_syncable_graph` canonicalize source title，但 normalized mutation 原样保留客户端 title。
- 原始 mutation 同时进入首次响应、`kb_changes.mutation`、`kb_operation_receipts.result` 和 replay，构成独立于 snapshot 的持久化隐私旁路。
- 修复必须发生在 payload fingerprint 之前，否则同一 operation ID 仅因不可信 title 不同就会错误冲突。
- 存量修复必须同时规范 change mutation 与 receipt result；对 `kb.mutation` V2 receipt 可由 canonical mutation 安全重算 hash，其他 operation kind 不猜测原始输入。
- 本轮不混入 Widget、Family 权限、semantic cache 或 compaction，保持单一隐私闭环。
