# Postgres Receipt 维护与 CLI 验收

## Summary

P006 的 Postgres 维护与 CLI 合同已完成。实现满足默认 dry-run、分用户锁与事务、失败隔离、幂等和无正文报告要求；真实 Postgres 执行证据明确留给部署阶段，不影响本地实现验收。

## Evidence

- Dry-run 测试确认无 UPDATE、数据库结果不变，并使用与 apply 相同的 advisory lock 边界。
- Apply 测试确认只更新 result，receipt identity/kind/schema/payload hash/created_at 保持不变。
- 锁超时和模拟更新失败均只回滚对应用户，后续用户继续成功。
- 第二次 apply candidate/updated 为 0，全部计入 skipped/alreadyCompact。
- 报告对私有 fixture 文本无泄露，按 kind 与 estimated bytes 统计完整。
- 完整后端 302 项回归、CLI help、py_compile、diff check 通过。

## Criteria Map

- 参数与 keep-days=0：满足。
- 用户级事务/advisory lock/timeout：满足。
- Dry-run 无写：满足。
- Apply 只更新 result 且批量执行：满足。
- 单用户失败隔离：满足。
- 无正文结构化报告：满足。
- 幂等与 CLI 默认 dry-run：满足。

## Execution Map

- R003 包含 PostgresStore 方法、CLI 与 fake-Postgres 专项测试。
- P005 提供已验收的纯转换 helper。

## Stress Test

- Batch size=1 跨页处理，验证 operationId keyset pagination 无漏重。
- Dry-run/apply 均进入用户 advisory xact lock；锁超时报告 partial 后继续。
- 一个用户首批更新抛错，整个用户事务回滚，其他用户提交不受影响。

## Residual Risk

- 尚未在真实 Postgres 验证 JSONB/WAL/锁等待和实际字节下降；P003 部署阶段必须先 dry-run，再审阅报告后 apply。
- Receipt 表 created_at 运维索引属于后续规模化优化，本轮不在 startup transaction 中贸然新增。

## Result IDs

- R003
