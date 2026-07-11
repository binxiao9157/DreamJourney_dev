# Task 26 Knowledge Operation Receipt 保留与最小化验收

## Summary

Task 26 成功标准全部满足。Compact receipt 不再持久化 graph、实体正文或原始 mutation upserts；安全重放、冲突、治理、删除和 change-feed 屏障保持兼容，线上历史数据已完成幂等压缩。

## Evidence

- P001、P002、P003 全部子问题的结果与成功检查。
- 后端全量测试、跨仓 gate、release regression、两类非真机构建报告。
- 线上 Postgres dry-run/apply、聚合身份和关联 smoke 证据。

## Criteria Map

- Compact 正文最小化：满足。
- 同 operation/same payload duplicate verified 且 revision 不增加：满足。
- 不同 payload 冲突：满足。
- Governance/archive delete 重放：满足。
- Change-feed compactor receipt 屏障：满足。
- Dry-run 只读、apply 锁/回滚/幂等：满足。
- 后端、跨仓、release 和构建验证：满足。

## Execution Map

- Reader/writer 合同、维护工具、跨仓 QA、部署、线上迁移依次完成。
- 每层由独立 result/check 关闭，没有跳过 dry-run 硬门。

## Stress Test

- 覆盖 legacy full、compact、脏 compact、空 operation ID、多页用户、payload conflict、治理、删除、privacy 和 change-feed。
- 线上迁移后通过部署 smoke 创建新 receipt，再确认所有记录直接为 compact。

## Residual Risk

- 数据规模显著增长时需复查扫描索引；当前线上规模与超时报告无性能阻断。

## Result IDs

- P001 汇总结果。
- P002 汇总结果。
- P003 汇总结果。
