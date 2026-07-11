# 收敛 Compact Receipt 标记与最小 envelope

## Problem

Compact receipt 已可安全重放，但响应标记不一致，且 envelope 重复保存表级身份字段。需要在不破坏 legacy/full 双读和现有 iOS V2 parser 的前提下，统一 duplicate 响应语义并移除重复身份载荷。

## Success Criteria

- 所有 compact-envelope 重放都返回 `receiptCompacted=true` 与稳定的 `originalRevision`。
- compact envelope 不再保存 receipt 表已持久化的 user/operation identity 字段，身份仅以表列和请求 fingerprint 为准。
- legacy full result 继续可读，同 payload duplicate 与异 payload conflict 行为不变。
- change 重建、snapshot fallback、governance/archive duplicate 均有回归测试。
- 后端相关测试和全量 `verify_backend.sh` 通过。
