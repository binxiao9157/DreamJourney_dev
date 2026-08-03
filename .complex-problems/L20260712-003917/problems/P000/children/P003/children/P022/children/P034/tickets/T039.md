# 构建组合 Cutover、Rollback 与 Legacy 退役 Runbook

## Problem Definition

第 27-33 节分别定义了数据、客户端/API、异步任务、对象和 Provider 的迁移合同，但缺少统一组合顺序。若各域独立切换，可能出现数据 Authority 已前进而客户端回滚、旧客户端继续写、worker effect 未知、schema 已 contract、Provider effect 不可撤销等跨域失配。

## Proposed Solution

1. 在 Product Spec 新增组合迁移 Runbook 章节，先定义五个 rollback plane 和不可逆事实分类。
2. 建立至少 10 个组合 wave，从 inventory/backup、identity/account、data shadow、object/provider、worker/outbox、client/API cohort、authority cutover、contract 到 legacy retirement，映射 W/I/P/Q/O/V 既有波次而不重建第二套迁移模型。
3. 每个 wave 固定 prerequisites、change、owner、observability、threshold、cutover、rollback/compensation、max recovery time 和 exit evidence。
4. 定义统一 go/no-go record、自动 pause/no-go 条件、数据权利优先级、不可逆 effect compensation/reconcile 和 retirement manifest。
5. 覆盖旧 schema、route、timer、credential、feature flag、local store、compatibility code 的逐项零流量/零引用/receipt/backup/恢复门。
6. 增加 Evidence Matrix 状态与 Decision Register 映射，新增组合 migration 静态检查并回归前述分域检查。

## Acceptance Criteria

- 组合 Runbook 至少 8 个有序 wave，且每个 wave 的九类执行字段完整。
- 五类 rollback plane 明确，已确认 MemoryVersion、已投递 Inbox、外部训练/删除等只允许补偿/对账，不允许历史回写抹除。
- backup/restore、canary、mismatch/dead-letter/quarantine、rights jobs、Provider receipts、旧客户端比例均进入 promotion/retirement gate。
- retirement manifest 覆盖旧 schema、route、timer、credential、feature flag、legacy store 和 transition code。
- 至少 15 个跨域故障演练和一个可审计 go/no-go record schema。
- Evidence Matrix 和 Decision Register 不把 runbook 设计误标为生产演练完成。
- 新增组合 migration/rollback checker，并确保现有 data/client/API/job/object/provider 检查继续通过。

## Verification Plan

新增专用 checker 验证章节、rollback plane、wave 编号、每 wave 字段、retirement 类型、故障场景数量、go/no-go 字段和 DR 映射；随后运行全部 Round 3C migration checks、V4 docs/evidence checks 和 `git diff --check`。

## Risks

- 组合 wave 若复制而不是引用既有 W/I/P/Q/O/V，会产生双重迁移 Authority；Runbook 只能编排既有波次。
- “rollback”容易被误写为数据库回滚全部事实；必须按 plane 与 irreversible effect 明确补偿边界。
- 未实测的时间、错误率、旧客户端比例不能写死为已批准阈值，应保留参数、owner 和 no-go 默认。
- schema contract 或 credential revoke 后不能把恢复旧代码作为安全回滚。

## Assumptions

- DR-040 仍是组合 cutover 参数和批准门的主要未决决策。
- 本票不执行生产 cutover、restore drill、Provider delete 或真实客户端 cohort。
- 本票不修改 iOS/后端生产代码和公开 UI。
