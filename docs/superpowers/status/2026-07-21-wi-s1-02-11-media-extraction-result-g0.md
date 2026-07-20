# WI-S1-02-11 媒体 ExtractionResult G0 合同预检

日期：2026-07-21

## 本轮范围

为已通过准入的、未来 `sourceExtraction` 处理建立一个纯内存、默认关闭的
`VerifiedMediaExtractionResultShadow` 合同。该合同只承载：

- 已获准处理计划的 request fingerprint；
- processor / policy / mediaKind 的版本化摘要；
- 段落 locator/content 的指纹、置信度和数量；
- `succeeded`、`failed`、`quarantined` 与 retryable 结果状态。

它不是 provider 返回，也不是数据库记录；没有读取媒体、没有派发 job、没有写
`ExtractionResult`、`Candidate`、`Memory`、`Persona` 或对象存储。

## 已锁定的边界

1. 只有 `would_enqueue_source_extraction` 或 retry admission 才能构造结果。
2. 成功但空结果不要求 Candidate proposal；成功且有段落时只声明
   `requiresSeparateCandidateProposal=true`，不产生 Candidate。
3. 失败或隔离结果不能携带段落；隔离结果不可 retry。
4. 对外摘要不暴露段落 ID、locator/content 指纹、vault、SourceObject ID、媒体正文或 URL。
5. 现有文字 `OwnerTruthCandidateExtractionService` 仍只接收 text/conversation Source；
   本合同不能绕过该限制进入其持久化器。

## 验证

后端定向 G0 gate：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
bash scripts/run-backend-verified-media-processor-shadow-gate.sh
```

该 gate 覆盖：verified / disabled / revoked / retry / terminal / unknown admission，
值最小化结果、空结果、失败可重试、无权 admission 拒绝，以及无副作用 import/AST 边界。

## 当前成熟度与后续门

本记录只是 `WI-S1-02-11` 的 G0 内部预检，不是该 Work Item 的完成证据：

- Registry 仍为 `PLANNED / STOP`，所有 G0-G4 全量 gate 仍是 `MISSING`；
- current handoff 的 `evidenceItems` 不增加该 Work Item；
- V4 当前证据覆盖仍为 `78 / 115`；
- 后续真实 worker、Postgres 持久化、delete propagation、provider 质量/成本/留存和
  敏感媒体 G4 决策仍须按 R4 分阶段完成。
