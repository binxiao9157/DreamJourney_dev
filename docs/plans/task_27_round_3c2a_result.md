# Round 3C2A iOS AccountSession、Generation 与本地 Store 迁移结果

## Summary

已形成不改变现有 UIKit/Stitch UI 的 iOS 账号与本地数据 rollout 合同。方案以 `AccountSessionActor`、不可变 `AccountLease`、refresh CAS、跨介质 activation journal 和 owner-scoped store envelope 为核心，阻断本地 user/session split-brain、旧 refresh 覆盖新账号、A callback 写 B store 和全局私有 cache 跨账号命中。

## Done

- Product Spec 新增第 29 节和 A01–A11 当前风险证据。
- 定义 AccountSessionSnapshot/Lease 字段、状态机、generation/epoch 和 refresh 复合 CAS。
- 定义冷启动、login、refresh、switch、logout、revoke、delete 和前后台顺序。
- 定义 request/send/retry/decode/use-case/store/UI/timer/runtime 8 个 lease checkpoint。
- 编制 S01–S17 本地 store/runtime/cache 迁移目录与 owner proof/quarantine/清理规则。
- 编制 I00–I08 从 XCTest/store inventory 到 legacy retirement 的 rollout waves。
- 增加 20 个冷启动、A/B 竞态、升级、crash、Widget、通知和账号删除场景。
- 新增 DR-041，登记本地草稿在 switch/logout/delete 时的保留策略决策。
- Evidence Matrix 新增 6.3，明确 `DESIGNED/CONTRACT_ONLY/DECISION_REQUIRED` 与当前未实现状态。
- 新增 `product-v4-ios-account-store-rollout-check.py`。
- 修复 data-backfill/data-cutover 门禁的章节范围，避免第 29 节 ID 被误计入旧目录。

## Verification

- iOS Account/Store rollout check：11 risks、17 stores、9 waves、20 scenarios，PASS。
- Data backfill check：18 backend tables、12 iOS stores、38 target groups、18 scenarios，PASS。
- Data cutover check：12 waves、8 mismatches、5 rollbacks、7 retirements、18 scenarios，PASS。
- Evidence matrix check：36 requirements，PASS。
- Product V4 docs check：36 requirements、21 conflicts、41 decisions、43 review responses、4 lifecycle banners，PASS。
- `git diff --check` 在结果记录前通过。

## Known Gaps

- 没有修改生产 Swift，没有实现 Actor/Lease/Registry/Envelope，也没有新增 XCTest target。
- 没有运行 A/B refresh、callback、crash recovery、upgrade matrix、Widget 或通知 runtime 测试。
- 活跃旧本地数据分布和 owner 可证明率未知；部分数据最终可能只能 quarantine/purge。
- DR-041 尚未由产品/隐私确认。
- Typed `/v2`、强身份、AuthZ enforce 和 capability rollout 由 3C2B 完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `docs/product/DreamJourney_V4_产品决策登记册_V1.0.md`
- `Scripts/QA/product-v4/product-v4-ios-account-store-rollout-check.py`
- `Scripts/QA/product-v4/product-v4-data-backfill-check.py`
- `Scripts/QA/product-v4/product-v4-data-cutover-check.py`
- `docs/plans/task_27_round_3c2a_solution.md`
- `docs/plans/task_27_round_3c2a_result.md`
