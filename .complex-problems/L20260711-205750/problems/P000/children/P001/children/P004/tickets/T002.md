# 最小化 Compact Receipt 并统一重放标记

## Problem Definition

当前 compact receipt 可以重放，但 change 重建路径和 snapshot fallback 路径的 `receiptCompacted` 标记不一致；envelope 还重复保存 receipt 表已有的 user/operation 身份字段，形成不必要载荷和潜在双重事实来源。

## Proposed Solution

将 compact envelope 收敛为仅包含重放所需的版本、原始 revision、mutation schema、可选时间/兼容标记和 ID-only governance summary。身份与 fingerprint 只读取 receipt 表列。所有 compact-envelope 重放在返回兼容响应时统一增加 `receiptCompacted=true` 和 `originalRevision`，无论关联 change 是否仍存在。Legacy full result 保持原样双读。

## Acceptance Criteria

- Compact envelope 不含 `userId`、`operationId`、`operationKind`、`operationSchemaVersion`。
- Change 重建和 snapshot fallback 均返回 `receiptCompacted=true` 与正确 `originalRevision`。
- Governance/archive delete 的 ID-only summary 与 duplicate 行为不变。
- Legacy full receipt 继续兼容，同 payload duplicate 和异 payload conflict 行为不变。
- 新增或更新回归测试覆盖 envelope 最小化与两条 compact replay 路径。

## Verification Plan

运行知识库相关单测、Postgres fake-store 测试、governance 测试和完整 `STORE_BACKEND=memory scripts/verify_backend.sh`，并执行 `git diff --check`。

## Risks

- 历史 compact envelope 可能已包含重复身份字段；reader 必须容忍额外字段，不能要求严格键集合。
- `originalRevision` 表示 receipt 对应的原始 operation revision，不应被当前 snapshot revision 覆盖。

## Assumptions

- Receipt 表的 operation identity 与 fingerprint 列是唯一权威来源。
- iOS 仅依赖兼容 graph/mutation 响应，不依赖 compact envelope 的内部字段。
