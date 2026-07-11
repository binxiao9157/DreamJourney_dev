# Extraction 与 Governance 不可变授权快照

## Problem

知识提取和治理后台回调仍可能重新解析当前 FamilyRepository/context，在账号或角色切换期间产生竞态。

## Success Criteria

- 异步提取开始前捕获 persona identity、用户 generation 与 family authorization generation。
- 完成回调只比较不可变 token，不在后台线程读取 FamilyRepository。
- governance 启动和成功处理使用 queue-owned authorization snapshot 验证 expected identity。
- stale callback 被丢弃且不修改图谱/base/outbox。
