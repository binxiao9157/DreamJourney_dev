# 生产 apply、归零与线上 sentinel 验收

## Problem

只有部署和 preflight 合格后，才能清洗历史数据并验证新写入合同。需要执行一次可回滚的生产 apply、post-dry-run 归零和不泄露内容的线上 sentinel smoke。

## Success Criteria

- 显式 apply 成功，输出只含聚合计数。
- post-apply dry-run 的 invalidRecordCount 为 0，所有 changed 计数为 0。
- 线上 V2 mutation 首次响应、change feed、receipt replay 不含 raw sentinel，canonical mutation 一致，raw/canonical 重试幂等。
- 更新状态文档和 Task 20 验收清单，记录脱敏报告/备份路径边界，不提交真实生产报告或 token。
- 最终账本关闭，iOS 文档提交推送，双仓工作区与远端一致。
