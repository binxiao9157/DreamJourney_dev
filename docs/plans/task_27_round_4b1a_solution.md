# 规划 iOS AccountLease、Store 隔离与 Release Policy 止损

## Problem Definition

当前 iOS 的账号/session、generation、store和flag分散在多个 singleton/coordinator。路线图需要把可复用机制与待新增统一层分开，并在不改 Stitch UI 的前提下给出从 inventory 到 retirement 的可执行顺序。

## Proposed Solution

1. 根据独立 iOS explorer 和 Product Spec 22/29/30，建立八个 `WI-S0-01-*`：store inventory、AccountSessionActor、refresh CAS、AccountLease、Archive quarantine、legacy global store、optional runtime state、统一 lifecycle。
2. 根据 Product Spec 19/25.8/30.5，建立八个 `WI-S0-06-*`：server ReleasePolicySnapshot、TTL/offline deny、default-off、route/command gate、五轴 capability、QA override、Release regression、server canary/retirement。
3. 每项填 16 字段，引用真实 Swift/QA 路径；尚未存在的 Actor/Registry/Policy cache 明确列为新增。
4. 明确 AccountLease 可以在 fake session 下完成 G0/G1，但生产 Exit 依赖 S0-02；release UI smoke 不证明 server policy/生产部署。
5. 按先 inventory/deny、再 wrapper/envelope、再 cohort、最后 retire 的顺序写入路线图，禁止一次性迁移所有 store 或删除 QA-only能力。

## Acceptance Criteria

- 16 个 Work Item ID 连续唯一，16 字段完整且主要结果单一。
- 覆盖 Archive/KBLite/Conversation/Echo/Voice/DH/Family/Widget/notification等私有状态类型，而不是只覆盖登录页。
- 账号切换、logout、delete、cold start、stale callback、legacy owner mismatch有明确测试和 quarantine/cleanup行为。
- Release Policy 有 server authority、版本/TTL、offline deny、unknown fail-closed、public release regression和alias retirement。
- 每项明确现有/新增路径、依赖、deployment、rollback/forward-fix与外部门。

## Verification Plan

1. 核对 explorer 提供的路径/行号与现有 QA脚本。
2. 检查 16 个 Work Item 的字段、ID、依赖和路径存在性。
3. 对照 IAR-01/02/05、SOR-03、CR-01/08与路线图 package边界。
4. 运行 architecture/review/link/diff检查。

## Risks

- Store inventory遗漏会在账号切换后泄漏；必须保留“未知 store 阻断 retire”的门。
- offline缓存若沿用旧true会重新fail-open；unknown/expired必须deny。
- Widget/extension清理不能只靠主App logout；需独立app-group证据。

## Assumptions

- 本票只写路线图，不创建 Swift 类型或迁移真实本地数据。
- S0-02将在独立子问题提供session/principal合同。
