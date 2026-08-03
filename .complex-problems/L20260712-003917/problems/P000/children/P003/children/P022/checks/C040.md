# Round 3C Legacy 迁移、Rollout、Rollback 与退役检查

## Summary

结论为 `success`。R039 覆盖 Round 3C 的全部成功标准，从 legacy 盘点到组合 contract/retirement 均有确定性设计、明确不变量、外部门和自动检查。真实生产迁移没有被误标为本轮完成。

## Evidence

- Product Spec 第 27-34 节提供 current evidence、target contract、分域 wave、rollback、retirement、故障场景和 UNKNOWN。
- 36项 Evidence Matrix 的迁移状态更新至 7.9，决策登记册包含 DR-040/041 与跨域映射。
- 八个 Round 3C 专用 checker 精确验证编号和章节边界，并与基础 docs/evidence 检查共同通过。
- 独立只读审查参与 3C4A，发现的跨域编排缺口已修正。

## Criteria Map

- 基线、至少8个wave、前置/变更/验证/cutover/rollback/exit：满足。
- deterministic backfill/checkpoint/checksum/quarantine/retry/invariants：满足。
- 禁止裸双写、single Authority + projection/outbox：满足。
- `/v1`/`/v2`、旧/新iOS、shadow/canary/retirement：满足。
- Identity/AuthZ fail-closed、token/session/revoke：满足。
- Job/Object/Provider 无重复 effect、unknown reconcile/dead-letter：满足。
- 五类 rollback 与不可逆事实：满足。
- 七类 legacy retirement evidence：满足。
- 静态门与 Evidence maturity：满足。

## Execution Map

- R027：Legacy catalog/backfill + data cutover。
- R030：iOS account/store + API/AuthZ/capability rollout。
- R035：Job/Outbox + Object/Media + Provider effect migration。
- R038：Composite cutover/rollback/retirement Runbook。
- R039：映射回父级，并保留生产实施缺口。

## Stress Test

- 覆盖账号切换旧 callback、旧客户端 post-cutover 写入、event gap、shadow side-effect、双 timer、对象孤儿、Provider unknown、TimeLetter/APNs、Voice/DH、rights/delete partial、contract后旧binary等跨域失败。
- 每一类不可逆 effect 都有 compensation/reconcile，而不是通过数据库回滚伪装未发生。
- 所有未实测参数默认 no-go，自动检查不能代替产品/安全/隐私/运维批准。

## Residual Risk

- 真正实施需要 Round 4 路线拆成小闭环并取得生产/外部证据；这与 Round 3C“设计可执行迁移路径”的完成边界一致。

## Result IDs

- R039
