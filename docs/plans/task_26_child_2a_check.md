# Receipt 转换与 Privacy 兼容验收

## Summary

纯转换与 privacy compatibility 问题已解决，结果满足 P005 成功标准，并为后续 Postgres 维护提供了单一、安全、可测试的转换入口。

## Evidence

- 四种 operation kind 的 legacy full result 均有转换测试。
- 输出断言不含 graph、mutation、正文和重复身份字段。
- Governance/archive 使用白名单 ID-only summary；非法摘要 fail closed。
- Compact V2 privacy canonicalization 与 payload hash 保留测试通过。
- 230 项相关组合测试通过。

## Criteria Map

- 纯函数转换与正文清除：满足。
- Compact 幂等与旧身份字段清理：满足。
- 异常输入明确失败：满足。
- Privacy maintenance 不要求 compact V2 mutation：满足。
- Legacy full 行为不回退：现有 privacy 测试继续通过。

## Execution Map

- R002 覆盖 helper、privacy 兼容与单测。
- 数据库事务和 CLI 明确留给 P006，不构成本问题缺口。

## Stress Test

- Governance mutation 无法提取安全 summary 时拒绝转换。
- Compact envelope 夹带 graph/mutation 时 privacy canonicalizer 拒绝。
- 旧 compact envelope 的额外身份/私有 summary 字段被 canonicalizer 清理。

## Residual Risk

- 历史数据的异常分布需由 P006 dry-run 报告，不在纯函数层猜测修复。

## Result IDs

- R002
