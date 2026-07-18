# WI-S1-01-05 Decision 到 MemoryVersion 证据

日期：2026-07-19

## 本次完成边界

后端已完成 Owner Truth 主链路中的一个受控内部切片：

```text
Source -> Candidate -> DecisionReceipt -> MemoryRecord + MemoryVersion
```

只有 `accept` 和 `correct` 能创建一条初始且 current 的不可变
`MemoryVersion`；`reject` 与 `invalidated` 不创建 memory。该能力仍是
QA-only 后端合同，没有新增公开 iOS UI，也没有改变三 Tab 或 Stitch 对齐视觉。

## 数据与事务保证

- 新鲜的 Owner 决策、不可变 `DecisionReceipt` 与初始 `MemoryVersion` 在同一个
  Postgres Unit of Work 内提交。
- `correct` 使用独立、不可变的 Owner 更正值；原 Candidate 提案不会被原地覆盖。
- 同一 command replay 只返回原 receipt 和原 memory/version ID，不会增加第二条版本。
- 每个 receipt 最多对应一个 MemoryRecord；每个新 MemoryRecord 只有 version `1`
  为 current。
- Source 已失效或 evidence 的 source version 已变化时，整个新鲜决策会 fail-closed
  回滚，不留下 terminal Candidate、receipt 或 memory。

`0015_owner_truth_memory_activation` 已在线上 Postgres 应用，添加 receipt 绑定、
唯一约束、修正值哈希验证和不可重绑触发器。旧 memory 仍保持无 receipt link，未被
回填或修改。

## 已验证

- 后端代码提交：`836d632 feat(v4): activate memory versions from owner decisions`。
- smoke 修正提交：`1abf1b0 test(v4): fix memory activation rollback smoke version`。
- 本地后端完整 `scripts/verify_backend.sh` 通过：`672` 个测试及 FastAPI/
  credential/knowledge 相关 smoke 全部通过。
- 定向 Owner Truth 套件通过：`22` 个测试。
- 线上迁移头为 `0015`；独立临时 Postgres smoke 通过：

  ```text
  decisionMemoryActivation=true
  correctedMemoryUsesOwnerValue=true
  rejectedDecisionNoMemory=true
  candidateMemoryActivationConcurrentSingleWriter=true
  decisionMemoryActivationRollback=true
  singleCurrentVersion=true
  status=passed
  ```

- 线上 route-auth smoke 通过，`routeCount=80`；QA review 路由只接受 Owner 的 user
  session，anonymous/machine credential 均被拒绝。
- 部署后 `/ready` 的 database/schema/auth/incident 全部为 ready。

## 不做的内容

- 不创建或写入 KBLite Projection。
- 不把 MemoryVersion 直接送入 Echo Context。
- 不新增 iOS Candidate Inbox、确认页或公开审核入口。
- 不发布、训练 Provider、创建家庭共享或 Visitor 可见内容。

## 状态与后续

本项在所需 `G0/G2` 范围达到 `INTERNAL_READY`。产品 Registry 按终版计划保持
`PLANNED/STOP/NO_GO` 的保守路线图状态；真实实现状态应由 current handoff 与本证据
文档读取，避免因静态 Registry 重复开发。

下一项不能直接假设 KBLite 已成为事实主库。应先按 `WI-S1-01-06` 及其依赖，建立从
active confirmed `MemoryVersion` 可重建的 Projection 和 typed Citation，再考虑接入
`/context/build` 与 iOS 组合层。
