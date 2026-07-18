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

本 Work Item 不提前实现 iOS Candidate Inbox，也不改变公开 UI。后续
`WI-S1-03-04` 才负责隐藏 QA Inbox 的界面组合；它还依赖后续 `WI-S1-01-05`
MemoryVersion 等 Owner Truth 主链路。

`WI-S1-01-05` 是当前下一项：仅对 accept/correct 决策在独立事务合同下创建不可变
`MemoryVersion`；reject 必须保持“不创建 memory”。在该项完成前，不应把 Candidate
审核能力当作已公开可用功能。

## Gate 状态

`WI-S1-01-04` 达到内部 `G0/G2`：数据合同、幂等、跨 vault 防护、terminal CAS 和真实
Postgres 并发单写均有证据。`G1/G4` 仍开放，因为 iOS 审核界面和发布策略均未启用。
