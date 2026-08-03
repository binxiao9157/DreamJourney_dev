# Round 3C Legacy 迁移、Rollout、Rollback 与退役结果

## Summary

Round 3C 已形成从当前 iOS/后端/数据库/Provider 形态迁移到 V4 目标架构的完整可逆路径。Product Spec 第 27-34 节依次覆盖 legacy catalog/backfill、数据 cutover、iOS account/store、typed API/AuthZ、Job/Outbox、Object/Media、Provider effect/credential/exit 和组合 Runbook，并通过分域及总门禁验证。

## Done

- Legacy catalog：18 张后端表、12 类 iOS 本地状态、38 个目标组、deterministic ID/checkpoint/hash/quarantine/backfill 和 18 个场景。
- Data cutover：W00-W11、M01-M08、R01-R05、D01-D07、authorityEpoch/single Authority 和 18 个场景。
- iOS rollout：AccountSessionActor/Lease、17 类 owner-scoped store、I00-I08、generation fencing 和 20 个场景。
- API/AuthZ rollout：10 个当前风险、5 个 auth mode、5 个 route mode、9 个 route group、P00-P10 和 20 个场景。
- Async/provider migration：15 类 Job、Q00-Q10、13 类媒体、O00-O11、Z01-Z08、10 类 Provider、V00-V11 及相应故障场景。
- Composite Runbook：五类 rollback plane、C00-C11、不可逆补偿、go/no-go、restore、七类 retirement manifest 和 24 个跨域演练。
- Evidence Matrix 7.3-7.9 与 Decision Register DR-040/041 及既有决策映射同步完成。
- 每个分域及组合迁移均有专用静态 checker，且完整回归通过。

## Verification

- Data backfill：18 backend tables、12 iOS stores、38 target groups、18 scenarios，通过。
- Data cutover：12 waves、8 mismatches、5 rollbacks、7 retirements、18 scenarios，通过。
- iOS account/store：11 risks、17 stores、9 waves、20 scenarios，通过。
- API/AuthZ rollout：10 risks、5 auth modes、5 route modes、9 groups、11 waves、20 scenarios，通过。
- Job/Outbox：15 jobs、11 waves、18 scenarios，通过。
- Object/Media：13 media、12 waves、8 delete surfaces、20 scenarios，通过。
- Provider：10 providers、12 waves、22 scenarios，通过。
- Composite：5 planes、12 waves、7 retirement surfaces、24 scenarios，通过。
- Data/API/jobs-provider/V4 docs/36项 evidence matrix 与 `git diff --check`：通过。

## Known Gaps

- 所有内容均为迁移目标、合同和 Runbook，尚未实现 production migrator、typed `/v2`、统一 worker/outbox、真实 object storage/provider adapter 或组合 controller。
- 当前线上数据量、旧客户端/route/timer/store/credential/provider inventory、backlog、object bytes 和 mismatch/quarantine 基线未知。
- 强身份、地域/processor、Provider 数据条款/退出、迁移阈值、MRT/RPO/RTO、iOS 草稿策略等仍受 Decision/External gate 约束。
- 未执行真实 Postgres backup/restore、cohort cutover、rollback、schema contract、Provider delete/exit、真机或生产流量演练。

## Artifacts

- Product Spec 第 27-34 节。
- Evidence Matrix 第 7.3-7.9 节。
- R027：Round 3C1 数据 backfill/cutover。
- R030：Round 3C2 iOS/API/Auth rollout。
- R035：Round 3C3 Async/Object/Provider migration。
- R038：Round 3C4 Composite Runbook。
- `Scripts/QA/product-v4/` 下八个 Round 3C 专用检查。
