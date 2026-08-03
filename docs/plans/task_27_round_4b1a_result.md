# Round 4B1A Account/Local Isolation 与 Release Scope 结果

## Summary

已基于独立 iOS 代码审计，将 `WP-S0-01` 和 `WP-S0-06` 细化为 16 个单结果 Work Item。路线既复用现有 KBLite/Knowledge/Family/Widget/Echo 局部 generation，也明确统一 AccountLease、legacy quarantine、global key retirement 和 server release policy 尚未实现。

## Done

- `WI-S0-01-01..08` 覆盖私有状态清单、AccountSessionActor、refresh CAS、AccountLease、Archive quarantine、global legacy store、Voice/Message owner scope和统一 lifecycle。
- `WI-S0-06-01..08` 覆盖 typed ReleasePolicy、TTL/offline deny、default-off、route/command gate、五轴 capability、QA override、Release regression和server canary/retirement。
- 每项包含 16 个固定字段、当前/新增路径、测试、部署、rollback/forward-fix、DoD与外部门。
- 路线保留强身份、真实部署和真机门；G0/G1 internal-ready不等于 production verified。
- 未复制任何credential值，也未要求UIKit/Stitch UI重写。

## Verification

- 独立 explorer 核实当前 iOS基线、相关源码行号、现有QA和明确缺口。
- Work Item检查：16个唯一ID、256个必填字段，通过。
- Architecture review：22 finding、12 risk、13 package，通过。
- Architecture invariant：13 sections、6 iOS layers、12 backend modules、36 FR、41 DR，通过。
- Roadmap相对链接和 `git diff --check` 通过。

## Boundary

- 当前只完成可执行路线，不实现Swift/backend代码。
- `WP-S0-01` 生产退出仍依赖 `WP-S0-02` session/identity和G2/G4证据。
- Future/Beta default-off是推荐止损基线；具体功能是否公开仍由Decision/G4批准。

## Artifact

- 路线图第7–8节。
