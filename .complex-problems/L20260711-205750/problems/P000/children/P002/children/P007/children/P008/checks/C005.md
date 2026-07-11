# 脏 Compact 与扫描完整性验收

## Summary

P008 的隐私与扫描阻断已解决。实现不再相信单一版本标记，空 operation ID 和多页用户均有明确测试，满足组合 smoke 的前置条件。

## Evidence

- Dirty compact fixture 在 apply 后无 graph/mutation/重复身份/私有正文，第二次运行 candidate=0。
- 空 operation ID fixture 被扫描并计入 failed user，而非静默漏过。
- Batch size=1 时用户发现执行三页查询，scannedUsers/processedUsers 均为 2，无重复处理。
- 后端 304 项全量回归及 34 项组合 smoke 通过。

## Criteria Map

- Canonical compare：满足。
- Dirty compact 清理与幂等：满足。
- 空 operation ID 可见：满足。
- 用户 keyset 分页：满足。
- 报告计数/bytes：现有及新增断言通过。
- 专项和全量回归：满足。

## Execution Map

- R004 完成维护查询、canonical 判定与测试修正。

## Stress Test

- 伪 compact 同时夹带 envelope 版本、graph、mutation 和重复身份，验证不会走快速跳过。
- 历史空 ID 无法安全转换时按用户回滚并继续。
- 用户数量恰为分页大小整数倍时额外终止页正常结束，无无限循环。

## Residual Risk

- 真实 Postgres 行为与 created_at 索引规模风险需在 P003 在线 dry-run 观察。

## Result IDs

- R004
