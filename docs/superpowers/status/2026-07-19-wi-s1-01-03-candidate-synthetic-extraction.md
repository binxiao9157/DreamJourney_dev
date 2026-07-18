# WI-S1-01-03 Candidate Synthetic Extraction 证据

日期：2026-07-19

## 本次完成边界

`WI-S1-01-03` 已建立可审计的内部 Source -> Candidate 基础链路：

```text
active Source -> ExtractionResult -> pending Candidate(s)
```

它只接受 deterministic fake 的 provider-neutral 结果，不启动 worker、不调用真实
模型、不暴露路由或 UI，也不会创建 DecisionReceipt、MemoryVersion、KBLite Projection 或
任何公开事实。

## 关键约束

1. ExtractionResult identity 由 Source effect、内容 hash、processor/model、prompt 和
   policy 版本稳定派生；同义重试只 replay，不能静默替换已保存结果。
2. Candidate 按原子事实保存，固定 `memoryKind`、视角、认知状态、敏感度、置信度、
   review mode、proposal hash 和可解析的 Source span。
3. 成功结果只能产生 `pending` Candidate；失败/可重试结果不产生 Candidate；未知/不合法
   ontology fail-closed。
4. 写入前后都保留 Source/vault 的 owner、state、epoch、version、content hash 边界；
   Source 已删除、撤权或过期时只产生 typed blocked completion。
5. Postgres adapter 还会验证 span 落在当前文本 Source 内，防止伪造来源引用。

## 已验证

- 后端实现 commit：`ae3d079`，已推送并部署。
- 本地 `scripts/verify_backend.sh` 通过：`660` 个单测和全部既有 smoke。
- 线上 migration head 仍为 `0013`，没有新增 schema migration。
- 线上 disposable Postgres smoke 已通过：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true
  candidateExtraction=true sourceTargetAdmission=true
  sourceBlockedCompletion=true workerLease=true schedulerLease=true
  consumerInbox=true rollback=true terminalGuard=true receiptsAppendOnly=true
  ```

- `/ready` 的 database/schema/auth/incident 均为 ready。

## Gate 结论

该 Work Item 达到 `INTERNAL_READY / scoped G0+G2`：可以证明待审核 Candidate 的
持久化、幂等、失败、来源和失效 Source 阻断边界。G3 真实 Provider 的质量、成本、区域和
隐私证据尚未关闭，因此不能宣称已完成真实 AI 提取。

下一项是 `WI-S1-01-04`：Owner-scoped Candidate Inbox 和 `accept/correct/reject` 的
不可变 DecisionReceipt。它仍不得提前创建 MemoryVersion 或更改公开 UI。
