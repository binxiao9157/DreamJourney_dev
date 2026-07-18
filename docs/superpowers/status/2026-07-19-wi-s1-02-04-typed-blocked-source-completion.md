# WI-S1-02-04 Typed Blocked Source Completion 证据

日期：2026-07-19

## 本次子闭环

`WI-S1-02-04` 的 effect kernel 通用范围已完成：当 Source effect 在执行时发现
owner/epoch/version/state 已过期或撤权，可以在同一 UoW 内写入一个固定的 typed
`blocked` Consumer Inbox 和不可变 completion receipt。

该 command 不能被滥用：

1. 只允许 `ownerTruth.source.created` 的 `source/candidateExtraction` target；
2. consumer 名称和 business target 都从 effect 固定派生，调用方不能换一套坐标；
3. 必须带当前 target admission，且 admission 必须是 `blocked`；
4. reason code 必须与实时 admission 完全一致；
5. 当前仍有效的 Source 不能被伪装为 blocked completion。

## 已验证

- 后端实现 commit：`750e525`。
- 本地 `scripts/verify_backend.sh` 通过，`653` 个单测及全部既有 smoke 通过。
- 后端已部署，migration head 为 `0013`。
- 线上 disposable Postgres smoke 已验证 epoch 变化后的 target 会在同一 UoW 中产生
  一个 blocked Inbox/receipt：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true
  sourceTargetAdmission=true sourceBlockedCompletion=true workerLease=true
  schedulerLease=true consumerInbox=true rollback=true terminalGuard=true
  receiptsAppendOnly=true
  ```

- `/ready` 的 database/schema/auth/incident 均为 ready。

## 范围结论

`WI-S1-02-04` 已达到其 G0/G2 通用 effect foundation 的 `INTERNAL_READY`：
能够对失效 target 给出唯一、可追踪、不可变的终端阻断结果。

它不等于 Source 已抽取成功：没有 Candidate、没有 Provider、没有 worker success，也没有
任何公开功能变化。下一步转入 Owner Truth Candidate Work Item，定义真正的 Source ->
Candidate 领域结果与 success receipt；TimeLetter、Echo、mailbox、APNs 仍各自独立过门。
