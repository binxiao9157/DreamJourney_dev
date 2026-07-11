# 实现后端知识变更保留水位和安全压缩

## Problem Definition

知识变更目前永久保存且分页读取非原子；清理历史后 API 无法说明保留边界，只会产生 500 或不连续页面。

## Proposed Solution

为 memory/Postgres 增加 change-feed state 和原子 page read；路由用结构化 410 表示历史已压缩。新增默认 dry-run 的维护脚本，显式 apply 时按用户知识锁计算 cutoff，只删除已有 operation receipt 的 change，并将删除与水位推进置于同一事务。

## Acceptance Criteria

- 水位持久化且只增不减。
- 正常 200 合同兼容，早于水位返回精确 410。
- 原子读取消除 snapshot/change 竞态。
- dry-run 零写入，apply 可重入并完整回滚。
- receipts 和无 receipt legacy change 不删除。
- 后端单测与 smoke 通过。

## Verification Plan

先增加 API/store/maintenance 失败测试，再实现；运行 knowledge 相关测试、全量后端单测和 `git diff --check`。

## Risks

- 伪 Postgres 测试连接需覆盖新增 SQL。
- 分页中途压缩必须在下一页返回 410。

## Assumptions

- 当前 snapshot 始终是完整权威 graph。
- receipts 是现代操作幂等权威记录。
