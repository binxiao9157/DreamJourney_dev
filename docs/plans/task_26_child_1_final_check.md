# Compact Receipt 与安全重放最终验收

## Summary

P001 的 compact receipt 与安全重放合同已完成。初次实现的标记与最小化缺口由 P004 修复；四类 operation 的幂等、冲突、重建和 iOS 兼容响应均有测试证据。现有 privacy maintenance 尚不识别 compact V2 envelope，但该问题已明确归入 P002，且本任务在 P002 完成前不会部署。

## Evidence

- 新 receipt result 不保存 graph、原始 mutation upserts、实体正文或重复身份字段。
- Fingerprint 在任何 change/snapshot 查询前验证，异 payload 仍冲突。
- Change 存在时精确重建；change 已压缩时返回当前权威 snapshot 与合法空 V2 mutation。
- Governance/archive 使用 ID-only summary，duplicate 不重复副作用。
- Server-generated legacy sync compatibility no-op 不再产生无意义 receipt。
- 218 项相关测试与 289 项后端全量回归通过；独立审查未发现 P001 其余缺陷。

## Criteria Map

- 无正文 compact envelope：满足。
- Fingerprint-first：满足。
- Mutation/governance/archive duplicate 不增加 revision、不重复副作用：满足。
- Governance summary 与 V2 空 mutation 可解析：满足。
- In-memory/Postgres 同 payload、异 payload、无 snapshot 边界：满足。

## Execution Map

- R000：完成 compact/full 双读、四类 operation 重放与测试。
- R001：移除 envelope 重复身份并统一 compact replay 标记。
- P004：跟进问题已通过 C001 验收。

## Stress Test

- 同 operation ID 改 payload，在 change/snapshot 查询前即抛 conflict。
- 删除 operation change 和 snapshot 后仍返回结构合法的空 V2 fallback。
- Governance/archive change 被压缩后仍返回 ID-only summary，不泄露正文。

## Residual Risk

- `knowledge_privacy_maintenance` 必须在部署前识别 compact V2 envelope并保留表列 payload hash；该工作属于已规划的 P002 阻断项。
- 真实 Postgres 历史迁移与线上验证属于 P002/P003。

## Result IDs

- R000
- R001
