# WI-S1-02-04 Synthetic Consumer Inbox 证据

日期：2026-07-19

## 本次子闭环

`WI-S1-02-04` 的第一子闭环已完成：后端增加了只接受
`asyncEffect.synthetic.*` 的 Consumer Inbox 与 Business Completion Receipt
基础能力。

它保证同一个 consumer/event：

1. 首次消费在同一 UoW 内写入一个 Inbox 和一个不可变 completion receipt；
2. 重复或乱序消费返回原 receipt；
3. 改变 business target、结果或状态会冲突失败；
4. 事务中断不会留下单独 Inbox 或 receipt；
5. 非 synthetic operation 在写库前被拒绝。

所有持久化引用均为不透明标识或哈希，不携带正文、语音、照片、收件人可读内容或
Provider 凭据。

## 已验证

- 后端实现 commit：`98eba85`。
- 并发主键冲突修复 commit：`272d09a`。
- 本地 `scripts/verify_backend.sh` 通过，`644` 个单测及全部现有 smoke 通过。
- 后端已部署，migration head 为 `0013`。
- 线上 disposable Postgres smoke 通过：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true workerLease=true
  schedulerLease=true consumerInbox=true rollback=true terminalGuard=true
  receiptsAppendOnly=true
  ```

- `/ready` 的 database/schema/auth/incident 均为 ready。

## 修复记录

第一次线上 smoke 发现并发请求可能先碰到确定性 `inbox_id` 主键冲突，而原先只处理
`consumer_name + event_id` 唯一索引冲突。该问题只出现在临时 smoke 数据库；已改为
对等价不可变唯一冲突统一进入 replay，再重新部署验证通过。

## 明确未完成

这不是 TimeLetter、Echo 或通知投递完成。当前没有真实 handler、没有 job/outbox
完成写入、没有领域 aggregate result，也没有实际执行时的 target AuthZ / authority epoch
复验。下一子闭环必须先补 typed consumer admission 与执行时授权边界；TimeLetter、Echo、
mailbox、APNs、Provider 和公开开关继续默认关闭。
