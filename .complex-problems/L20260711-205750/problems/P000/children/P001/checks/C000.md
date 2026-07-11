# Compact Receipt 与安全重放验收

## Summary

当前结果覆盖了核心读写与重放路径，测试证据充分，但尚不能判定成功。Compact replay 的标记语义在 change 重建与 snapshot fallback 两条路径上不一致，且 envelope 仍重复保存 receipt 表已有的身份字段，不满足“结果载荷最小化且语义可稳定消费”的完整标准。

## Blocking Gaps

- `receiptCompacted` / `originalRevision` 仅在 change 已压缩后的 snapshot fallback 路径返回；读取 compact envelope 但 change 仍存在时没有一致标记，客户端无法仅凭响应稳定判断该次 duplicate 来自 compact receipt。
- compact envelope 仍保存 `userId`、`operationId`、`operationKind`、`operationSchemaVersion`，与 receipt 表身份列重复；重放逻辑又未校验这些重复字段，既增加载荷，也引入潜在的双重事实来源。
- 上述问题属于 P001 自身的 replay/envelope 合同，不应推迟到历史迁移或发布 gate。

## Result IDs

- R000
