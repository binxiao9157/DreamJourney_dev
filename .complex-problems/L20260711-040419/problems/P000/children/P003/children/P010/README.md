# iOS Governance Outbox 与同步协调

## Problem

显式治理动作缺少按用户持久化、revision retry 和 user/persona generation 边界，直接网络调用会在离线或切换角色时丢动作或应用旧回调。

## Success Criteria

- 独立 per-user outbox 原子持久化并可重启恢复。
- KnowledgeSyncCoordinator 串行治理与普通 graph sync。
- 409 刷新后以同 operation ID 重试，成功删除 outbox，失败保留。
- 用户/角色切换后的旧回调不直接应用当前图谱，改走 change-feed refresh。
- 模型/静态 smoke 覆盖队列、隔离、retry 和 metadata 保真。
