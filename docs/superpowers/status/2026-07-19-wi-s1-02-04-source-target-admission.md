# WI-S1-02-04 Source 目标授权复验 证据

日期：2026-07-19

## 本次子闭环

后端已为现有 `ownerTruth.source.created` effect 增加执行时的 typed target
admission guard。将来 Source 消费者在写 Candidate 或 completion receipt 前，必须在
同一 UoW 内复验：

1. operation/resource/purpose 是否仍是 Source 抽取目标；
2. vault 是否 active，且 owner 与 effect target 一致；
3. effect authority epoch 是否仍等于当前 vault epoch；
4. Source 是否仍 active，owner/epoch/version 是否仍与 effect target 一致。

任何一项变化都会 fail-closed；例如 vault epoch 上升后，旧 effect 会得到
`authorityEpochChanged`，不能继续写后续结果。

## 已验证

- 后端实现 commit：`67fe77e`。
- 本地 `scripts/verify_backend.sh` 通过，`649` 个单测及全部既有 smoke 通过。
- 后端已部署，migration head 为 `0013`。
- 线上 disposable Postgres smoke 验证“当前 Source 允许 -> epoch 变化后阻断”：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true
  sourceTargetAdmission=true workerLease=true schedulerLease=true
  consumerInbox=true rollback=true terminalGuard=true receiptsAppendOnly=true
  ```

- `/ready` 的 database/schema/auth/incident 均为 ready。

## 明确未完成

本次只读不写：没有启动 worker，没有写 Candidate、Consumer Inbox 或 completion
receipt，也没有改变 operation/outbox/job 的 terminal state。它只给下一步真实 typed
consumer completion 提供执行时授权边界。

TimeLetter、Echo、Family、mailbox、APNs、Provider 和任何公开功能仍没有接入该
adapter，继续默认关闭。
