# Context Packet V2 Trace

日期：2026-07-02

## 目标

在不破坏现有 `/context/build` 合同的前提下，基于后端 `ContextPacketBuilder` 增量输出 Echo Context Builder V2 诊断信息，并让 iOS Echo 证据包可以导出本轮上下文的 selected / filtered / ranking trace。

## 兼容策略

- `/context/build` 继续返回 `schemaVersion=1`。
- 新增 `contextVersion=echo-context-v2`，用于标识本轮上下文构建已经带 V2 trace。
- 原有 `memory.archiveItems`、`voice`、`digitalHuman`、`policy`、`trace`、`fallbacks`、`debug` 结构保留。
- 旧 iOS 客户端即使不识别 V2 字段，也仍能使用原有 v1 packet。

## 后端新增字段

### selectedContext

记录本轮实际进入 Echo 上下文的候选。目前覆盖：

- `archive`：记忆档案条目。
- `kbFact`：KBLite facts。
- `persona`：当前 persona scope / digitalHumanId / lifecycleMode。
- `care`：摘要化后的 care snapshot 信号。

通用字段：

- `source`
- `refId`
- `kind`
- `title`
- `rank`
- `reason`
- `score`
- `confidence`
- `analysisStatus`
- `signals`

### filteredContext

记录没有进入 Echo 上下文的候选和原因：

- `scope_mismatch`：跨 persona scope / digitalHumanId，不可混入。
- `analysis_failed_empty_context`：AI 分析失败且没有用户文字说明、人物、地点、场景或标签。
- `time_letter_draft`：时间信件仍是草稿，不进入 Echo。
- `time_letter_not_open_for_recipient`：时间信件已经封存但未到 `openAt`，家庭收件人视角不可见。
- `family_viewer_not_active`：家庭成员邀请中、失败或未接受，不可使用 family 档案和 care snapshot。
- `empty_context`：没有可用上下文线索。

### rankingTrace

记录入选前的排序依据：

- `rank`
- `score`
- `scoreBreakdown.base`
- `scoreBreakdown.userText`
- `scoreBreakdown.analysisSignals`
- `scoreBreakdown.queryMatch`
- `reason`
- `source`
- `refId`

## iOS 证据包接入

`EchoContextPacket`、`EchoTraceRecord` 和 `EchoContextBuildEvidenceSummary` 已保留以下字段：

- `contextVersion`
- `selectedContextRefs`
- `filteredContextReasons`
- `selectedContextCount`
- `filteredContextCount`
- `rankingTraceCount`
- `selectedContextSourceCounts`

这些字段会进入 QA-only Echo trace evidence package。真机或模拟器复现问题后，可以通过 QA 面板导出的证据包确认：

- 本轮具体使用了哪些档案。
- 本轮具体使用了哪些 KBLite facts、persona 和 care 摘要信号。
- 各类 source 的数量分布。
- 哪些档案因为权限、失败分析或草稿状态被过滤。
- 上下文排序是否按预期发生。
- 是否存在跨个人/家庭数据混入。

## P0 Policy

- failed image analysis 不注入空人物、地点、场景线索。
- timeLetter 草稿不进入 Echo。
- timeLetter 未到 `openAt` 时，家庭收件人不可见。
- family 邀请中或失败状态不可用，`canUseFamilyData=false`，并输出 `family_viewer_not_active` fallback。
- care snapshot 默认摘要化，只输出 `riskLevel`、`summary`、`suggestions`、`trendSummary`、`metadataOnly`、`contentRedacted` 等聚合字段。
- voice / digitalHuman 只作为 runtime state 进入 packet，不参与 memory ranking。

## 验证

- 后端单测：
  - `tests.test_core_services.ArchiveAPITests.test_context_build_emits_v2_selected_filtered_and_ranking_trace`
  - `tests.test_core_services.ArchiveAPITests.test_context_build_includes_kblite_persona_and_care_signals_in_v2_trace`
  - `tests.test_core_services.ArchiveAPITests.test_context_build_filters_unopened_time_letter_for_family_recipient`
  - `tests.test_core_services.ArchiveAPITests.test_context_build_blocks_pending_family_viewer_and_summarizes_care_snapshot`
  - `tests.test_core_services.ArchiveAPITests.test_context_build_returns_cfl_lite_packet_without_cross_scope_archive_leak`
  - `tests.test_core_services.ArchiveAPITests.test_context_build_reports_fallbacks_when_voice_and_digital_human_are_unavailable`
- 后端 smoke：
  - `DreamJourneyBackend/scripts/backend-echo-context-builder-v2-smoke.py`
  - `DreamJourneyBackend/scripts/run-echo-context-builder-v2-smoke.sh`
- iOS 静态检查：
  - `Scripts/QA/prd-stitch-ui/context-packet-v1-check.swift`
  - `Scripts/QA/prd-stitch-ui/context-packet-v2-trace-check.swift`
  - `Scripts/QA/prd-stitch-ui/echo-trace-evidence-package-check.swift`
  - `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- release regression 可选开关：
  - `RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE=1`

## 后续

- 若引入 CFL-lite 的复杂排序或压缩策略，应继续保持 `/context/build` v1 字段兼容，只扩展 `contextVersion` 和诊断字段。
- 后续可以继续补 `filteredContext` 对 KBLite facts/persona/care 的更细粒度过滤原因，例如事实过期、care snapshot 过期、persona 生命周期不允许等。
