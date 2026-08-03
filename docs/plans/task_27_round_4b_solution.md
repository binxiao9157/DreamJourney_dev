# 将 Stage 0 七个风险包拆成可实施的安全止损任务

## Problem Definition

路线图已固定 `WP-S0-01` 至 `WP-S0-07` 的依赖和退出门，但 package 级描述不足以指导开发。必须结合当前 iOS/backend 文件、58 条 route、18 张表、认证/owner shadow、单连接 Postgres、release flag 和现有 QA，把安全止损拆成单结果 Work Item。

## Proposed Solution

1. 分三个闭环细化 Stage 0：
   - 账号/身份/凭据/发布：`WP-S0-01/02/03/06`。
   - DB/恢复与数据权利：`WP-S0-04/05`。
   - 运维证据与 Stage 0 集成门：`WP-S0-07` 及七包收口。
2. 每个 package 建立 3–6 个稳定 `WI-S0-xx-yy`，每项只产生一个主要结果，并填满路线图 1.3 的 16 个字段。
3. 代码范围必须引用当前真实 iOS/backend 路径；目标 module/schema 尚不存在时明确写“新增位置”，不伪造文件已存在。
4. 为每项区分 G0/G1/G2/G3/G4，注明内部可完成上限；强身份 Provider、资产 Owner 凭据轮换、真实 restore、Privacy/Legal 不由自动化关闭。
5. Stage 0 工作项按 R0 Safety Baseline 与 R1 Secure Account Boundary 排序，给出可并行项、hard dependency、部署顺序、兼容窗口和 rollback/forward-fix。
6. 建立 Stage 0 coverage 表，确保 CR-01/02/03/04/08/10/11 和对应 IAR/BAR/SOR 无遗漏，不让 P0 混入 Publication、Voice质量或增长功能。

## Acceptance Criteria

- 七个 Stage 0 package 均有唯一、连续的 Work Item，且每项 16 字段完整。
- 账号/本地隔离覆盖 AccountLease、generation、store envelope、legacy quarantine、A/B/logout/delete/cold start。
- Identity/AuthZ 覆盖 strong challenge、session rotation/revoke、server-derived principal、route/resource deny-by-default、iOS typed migration。
- Credential 覆盖 inventory、artifact/header/log/backup scan、rotation、broker/response redaction、revoke；不保存 secret 值。
- DB/Recovery 覆盖 pool/UoW、versioned migrator、readiness、backup/isolated restore/receipt replay。
- Rights/Delete 覆盖 access-first、状态机、module/object/provider/backup receipt、restore/retention 与不可逆披露。
- Release Scope 覆盖 server policy、TTL/offline deny、public release hidden regression。
- Operations Evidence 覆盖 operation/rights/incident/provider cost 事件、分母、redaction、retention 和 stop-the-line signal。
- 每项有真实路径、验证命令类型、部署/回滚和外部门；Stage 0 集成门能确定下一项而非并发踩同一 Authority。

## Verification Plan

1. 对照 Product Spec 3.1、22/25/27–30/34 与 Round 3 response 的 IAR/BAR/SOR 映射。
2. 抽样核实每个现有路径、route、store、script 在当前 iOS/backend 基线存在；新增位置显式标记。
3. 检查 Work Item ID 唯一、依赖有向无环、P0 无 Optional 能力。
4. 对照 16 字段逐项审查，运行现有 architecture/review/link checks 和 diff gate；最终由 P055 roadmap checker全量验证。

## Risks

- 七包同时细化容易重复 AccountSession/AuthZ/credential 责任；每项指定 primary package，其他只作依赖。
- 数据权利完整删除依赖 Stage 1 async；Stage 0 只允许标 access-first/internal-ready，不能伪造 provider/backup完成。
- 强身份 Provider 未决会阻塞 R1 production exit，但不应阻塞 typed contract、fake、shadow corpus。
- 凭据文档可能泄漏值；只记录类型、owner、fingerprint/version、轮换 receipt，不复制 secret。

## Assumptions

- 本轮只完善路线图，不修改生产代码、部署或真机状态。
- 当前代码路径以 iOS `8a1922b` 与 backend `4c0538b` 为基线。
- P055 将统一验证 Work Item 字段与全量 FR/DR/finding 追踪。
