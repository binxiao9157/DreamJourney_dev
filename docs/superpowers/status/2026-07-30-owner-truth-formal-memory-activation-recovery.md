# Owner Truth 正式记忆激活恢复闭环

日期：2026-07-30  
范围：`WI-S1-01-04/05` 的 default-off、正式确认后显式激活恢复切片。  
状态：`INTERNAL_READY`，未推送、未部署、未开放公开发布。

## 目标

正式确认的 Candidate 不会自动写入 `MemoryVersion`。若用户已经确认、但后续显式“纳入正式记忆”写入失败或 App 中断，客户端必须能重新发现该待办并让 Owner 再次明确确认，不能依赖易失的页面状态。

## 已实现

后端本地 `main@12102a2`：

- 新增 `GET /v2/vaults/{vault_id}/interview-memory-activation-inbox`。
- 响应 schema：`owner-truth-interview-candidate-memory-activation-inbox-v1`。
- 每项只返回 `reviewBatchId` 与 `candidateId`；不返回 Candidate 正文、Source、DecisionReceipt、`memoryId`、`memoryVersionId` 或 provider 数据。
- 仅接受正式 `ownerTruthCandidateReview` 的 captured release policy 和用户会话；QA header 不可绕过。
- 只保留 active owner/vault 中 formal accepted/corrected、尚未激活且来源仍有效的条目；拒绝、QA-only、已激活、跨 owner/vault 或失活来源会被过滤。

iOS 本地 `feature/prd-stitch-ui-adaptation@423c673` 和 `15053f0`：

- 新增严格的 value-minimized DTO、AccountLease 绑定的 inbox reader，以及只接受已绑定句柄的 activation retry use case。
- 新增“待纳入正式记忆”入口和列表；它仅在本人自传模式且正式 release gate 允许时显示，默认公开版本隐藏。
- 列表不显示任何 Candidate 内容或内部标识。用户必须二次确认“确认纳入”后才发送既有 typed activation 命令。
- 成功后重新读取 inbox；加载、空、失败和不可用状态均有明确收敛。

## 验证证据

- iOS：`OwnerTruthContractsTests` focused test 通过。
- iOS：
  - `Scripts/QA/product-v4/owner-truth-candidate-memory-activation-check.swift`
  - `Scripts/QA/product-v4/owner-truth-candidate-memory-activation-inbox-check.swift`
  - `Scripts/QA/product-v4/owner-truth-candidate-memory-activation-inbox-presentation-check.swift`
  均通过。
- iOS：generic iOS Simulator build 通过；仅保留既有第三方/弃用 warning。
- 后端：73 个相关单元测试通过，`compileall` 与 `git diff --check` 通过。
- 后端：formal Postgres disposable smoke 已补入 inbox 创建后可见、激活后消失和字段最小化断言；本轮未提供隔离数据库环境，未执行该 smoke。

## 未包含 / 不得误判

- 不推送、不部署，不视为线上可用。
- 不改变公开 Archive 三 Tab、Stitch 对齐或原有默认体验。
- 不自动创建 `MemoryVersion`；每一项仍需 Owner 的单独确认。
- 不把该 inbox 当作 Candidate 阅读页面，也不允许经它泄露正文或确认回执。
- 真实 Postgres 部署 smoke、release policy 放行和公开产品验收仍是后续 Gate。
