# 家庭授权撤销后的 Echo Context 主动回退

## Problem

选中 family context 失效时 getter 虽返回 self，但没有持久化或发送 context change，Echo UI/runtime 可能保留旧角色。

## Success Criteria

- FamilyRepository authority generation 变化后触发 DigitalHumanContextStore reconcile。
- 失效 family context 被持久化为当前用户 self context，并发送 `djDigitalHumanContextDidChange`。
- Echo 复用现有 context observer 取消旧 gate/session request 并重建 self runtime。
- 正常 accepted family context 不产生多余通知或重置。
