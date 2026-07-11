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

## Task 20 Resolution

- V2 mutation 在 payload fingerprint 前规范 `privacyMetadata.sourceRefs[].title`，因此 raw/canonical title 重试保持同一语义 operation；source kind/id 或正文变化仍会冲突。
- 首次响应、change feed、operation receipt 和 duplicate replay 现在共享同一 canonical mutation，客户端 raw title 不再形成旁路。
- 历史维护工具默认 dry-run，使用单事务、5 秒 lock timeout、全局/用户 advisory lock 和知识表锁；无效历史结构拒绝 apply，SQL 中途失败整批回滚。
- 只有 `kb.mutation` V2 receipt 按 canonical mutation 重算 hash，其他 operation kind 保持原 hash。
- 生产 full Postgres 备份后完成 4 个 change mutation、2 个 receipt result 和 2 个 receipt hash 清洗；post-apply 和新 sentinel 写入后的 dry-run 均为零待更新。
- 后端 `d6d13be` 已部署，iOS/QA `190d65f` 已推送；release regression `20260711-task20-knowledge-privacy` 通过。
- 下一 P0 隐私问题是 Widget/App Group 共享时间线：需要按当前用户授权写入、退出/切换清除缓存，并防止旧 timeline 跨用户展示。

## Task 21 Exploration

- 当前 App Group 导出无条件包含所有 event title/description，不检查 owner、persona、evidenceStatus 或显式 Widget 授权；这是系统表面隐私泄露，不等同于 Echo 的 generationAllowed 权限。
- 主 App 与 Widget target 均未配置 `com.apple.security.application-groups`，现有共享容器调用没有完整签名合同；Widget extension bundle ID 也没有跟随主 App 的本地覆盖。
- `switchUser(to:)` 已尝试用新/空图谱替换共享文件，这是可复用基础，但共享 JSON 没有 schema/owner digest，Provider 无法识别旧用户或损坏快照。
- 当前没有 `WidgetCenter.reloadTimelines`，即使登出写空文件，系统已缓存的旧 entry 仍可能持续展示。
- Task 21 必须采用显式 `summaryAllowed` + confirmed personal owner 组合，默认/legacy 一律 deny；本轮不凭空开放产品授权入口。

## Task 21 Resolution

- Widget 知识快照升级为 schema v2，只包含显式 `summaryAllowed`、`generationAllowed`、confirmed、personal 且 owner 匹配的最小摘要；raw owner/event/source ID、description 和 sourceRefs 不进入 App Group。
- `KnowledgeWidgetSnapshotStore` 使用 owner digest 与 publication generation 阻断旧账号异步写，登出/切换/失败清理均撤销 active owner 并 reload `TodayInHistory` timeline。
- Widget reader 对 schema、active owner、快照 owner 和内容边界执行 fail-closed 校验；旧 schema、损坏文件和身份不匹配只返回空态。
- 主 App 与 Widget extension 的 App Group entitlement、bundle identifier 派生、嵌入和 target dependency 已接通；Simulator 与 generic iPhoneOS 构建产物均包含 `.appex`。
- 三个模型 smoke、静态隐私 gate、release QA package 和完整 release regression 均通过；实现提交 `fa8fb9c` 已推送，ledger `L20260711-145625-21` 已关闭。
- 真实 App Group provisioning、Widget Gallery 和锁屏隐私仍是明确排除的外部真机验收；公开授权入口未决前继续默认 deny。

## Task 22 Exploration

- Canonical 知识架构明确规定：对话中提取的 `KBPerson` 只能作为人物候选，不能自动成为 `active + accepted` 家庭成员；家庭关系必须来自手机号邀请、接受状态和后端授权合同。
- 当前 `FamilyRepository.syncFromKnowledgeBase()` 将 `KBPerson` 直接构造成 `FamilyMember`，而 `FamilyMember` 本地 initializer/legacy decoder 默认 `accessStatus=active`、`invitationStatus=accepted`，存在本地角色列表提前授权风险。
- 后端 `/context/build` 已验证 pending family viewer 不可使用家庭 Archive、care 或私有事实，因此下一 P0 应收敛 iOS 本地候选/授权语义，而不是重建后端 Context policy。
- `DigitalHumanContextStore` 恢复仅校验 viewer，`KBPersonaIdentityResolver` 又允许 relation-only personal 推断；旧/伪造 family context 可能绕到 personal fallback，必须与 repository authorization 一起收敛。
- 通用 knowledge sync 的 scope 判断不足以证明 owner/persona authorization；Task 22 需要让 Echo、family repository 和 sync 共用同一 fail-closed authority contract。

## Task 23 Resolution

- 旧语义 embedding cache 只按 entity ID 缓存，跨账号、跨类型、内容更新和旧 warm callback 都可能复用错误向量；全局 `isCacheWarm` 还会阻止后续账号预热。
- Task 23 使用 owner digest + user generation scope、kind/ID/text fingerprint key 和 lock-protected active scope；账号切换先激活新 scope，旧任务在提交前后均 fail closed。
- 独立审计发现 generation Context 先整图 ranking、后 persona 过滤会造成候选挤占；现已改为先构造 persona/privacy/evidence 可见候选图，再统一执行 semantic/keyword ranking，并保留结果后二次过滤。
- graph/base/pending/outbox/sync history 原有原子写入已收敛到统一 `KnowledgeLocalStoragePolicy`，最终 inode 使用 first-unlock protection 并排除备份，旧文件读取时 best-effort 加固。
- 独立复核发现并关闭三个问题：账号切换时旧最近摘要 fallback、文件已提交但加固失败被误报为业务写失败、并发切换导致旧 cache activation 覆盖新 scope。
- 完整 release regression `20260711-task23-knowledge-storage-cache-final3`、Simulator、generic iPhoneOS 和两个核心 Simulator smoke 通过；真机锁屏/备份行为保持外部验收。

## Task 25 Resolution

- 四类 Echo QA/诊断 Store 原先使用全局 UserDefaults key，账号切换后存在读取、导出和晚到 callback 重建旧数据的风险。
- 现在所有 Store 使用不可逆 owner digest key 和 active-owner scope；Evidence package、数字人 session、语音合成摘要均携带并校验 owner。
- 导出文件使用 owner digest 目录并在切换/登出时确定性删除；legacy 全局 key 和旧临时文件只清除、不迁移。
- UserManager 将账号字段、Echo scope、KBLite/Knowledge 和通知副作用串行化；nickname-only 保存用 expectedUserId 阻断跨账号旧写。
- Echo 账号变化会失效 lifecycle、无 diagnostics 释放旧 runtime/session、清除 capability/trace/provider/evidence 缓存；session/voice callback 使用请求发起时 owner。
- 新 model/static guard 已进入默认 release regression；三条实际模拟器导出 smoke 与两类非真机构建通过。

## Task 26 Exploration

- `kb_operation_receipts.result` 当前保存完整 graph 和 mutation，不是轻量摘要；随着 graph 增长，历史体积最坏接近所有操作时点 graph 大小总和。
- Receipt 行不能按固定 TTL 直接删除：iOS pending/governance outbox 没有 TTL，且 change 压缩后 receipt 是阻止旧 operationId 被再次执行、保留 payload conflict 语义的唯一权威。
- 安全方案是永久保留 kind/schema/payload hash 身份行，将 result 改为版本化 compact envelope；重放先查关联 change，change 已压缩才使用当前 snapshot 重建兼容响应。
- `KB_OPERATION_SYNC/MUTATION/GOVERNANCE/ARCHIVE_DELETE` 均需双读；governance 只需保留 action、entity/source link 等 ID-only summary，不应保留实体正文。
- server-generated legacy sync compatibility no-op 每次 operationId 都不同，没有重放价值，不应继续制造完整 receipt；真正产生 change 的首次 legacy sync 仍保留 receipt 作为 compaction 证明。
