# WI-S1-01-04 Candidate Review / DecisionReceipt 证据

日期：2026-07-19

## 本次完成边界

后端已完成 Owner Truth 的内部审核闭环：

```text
pending Candidate -> accept | correct | reject -> immutable DecisionReceipt
```

实现是默认关闭的 QA-only 后端合同。它不创建 `MemoryVersion`、不更新 KBLite、
不发布内容，也没有公开 iOS 入口。

## 后端合同与安全边界

仅在服务端开启 `OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=true` 且请求同时带
`X-DreamJourney-QA-Owner-Truth: 1` 时，具备 user session 的 Owner 可访问：

```text
GET  /v2/vaults/{vaultId}/candidates
POST /v2/vaults/{vaultId}/candidates/{candidateId}/decisions
```

命令固定为 `commandId`、`expectedCandidateVersion`、`action`、可选
`correctedValue`、`reasonCode`。`correct` 必须带更正值；返回不回显原始更正文本。

后端会在同一 Unit of Work 内校验 vault/candidate owner、Source 是否仍有效、epoch 与
乐观锁版本，并将 terminal Candidate 变更和唯一不可变 `DecisionReceipt` 一起持久化。
重复 command replay 原 receipt；跨 vault、stale version、已终态 Candidate 均 fail-closed。

## 已验证

- 后端实现与部署 commit：`44b06b0`。
- 本地后端完整 `scripts/verify_backend.sh` 通过：`668` 个单测、FastAPI smoke 和既有
  contract/credential 检查均通过。
- 线上 Postgres Owner Truth smoke 已通过：

  ```text
  candidateReviewConcurrentSingleWriter=true
  candidateReviewIdempotent=true
  correctedDecisionRequiresValue=true
  candidateCorrectionSeparate=true
  schemaHead=0014
  status=passed
  ```

- 线上 route-authentication Postgres smoke 已通过，新路由只接受 user session，拒绝
  anonymous/machine credential，路由登记总数为 `80`。
- `/ready` 的 database/schema/auth/incident 均为 ready。

## iOS 影响与后续依赖

原始 `WI-S1-01-04` 后端提交不提前实现公开 iOS Candidate Inbox，也不改变公开 UI。
后续 `WI-S1-03-04` 的 hidden QA 组合层已经提供了 Archive 内的 typed Inbox/review
use case，仍需显式 QA launch argument 才可见。

`WI-S1-01-05` 随后已完成并部署。因此当前聚合行为为：`accept`/`correct` 在同一
事务中同时返回不可变 `DecisionReceipt` 和已激活的 `MemoryVersion`；`reject` 保持
“不创建 memory”。这不是把 Candidate 审核公开化，也不允许客户端绕过 Owner Truth
合同写入事实。

本页记录的是 `WI-S1-01-04` 的原始审核合同；当前 iOS action-level UIQA 的补充证据
见 `2026-07-19-wi-s1-01-04-candidate-inbox-action-uiqa.md`，MemoryVersion 激活的
事务边界见 `2026-07-19-wi-s1-01-05-memory-activation.md`。

## Gate 状态

`WI-S1-01-04` 达到内部 `G0/G2`：数据合同、幂等、跨 vault 防护、terminal CAS 和真实
Postgres 并发单写均有证据。隐藏 iOS action-level UIQA 已验证一条 `accept` 命令可消费
回执、激活 MemoryVersion 并从 pending Inbox 移除。`G1/G4` 仍开放，公开审核入口与
发布策略均未启用。
