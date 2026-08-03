# 细化账号/发布与身份/凭据四个 Stage 0 工作包

## Problem Definition

`WP-S0-01/06` 主要由 iOS AccountLifecycle、store 和 release policy 承担，`WP-S0-02/03` 主要由后端 Identity/AuthZ、typed client 和 credential boundary 承担。四包相互依赖但写入责任不同，需分别审计再在路线图中合并。

## Proposed Solution

1. 账号与发布闭环：基于 UserManager/AuthSession、AccountLease候选、Archive/KBLite/Family/Widget/Voice/DH本地状态、FeatureFlags/runtime config，形成 `WI-S0-01-*` 与 `WI-S0-06-*`。
2. 身份与凭据闭环：基于 auth routes/session service、principal middleware、ownership registry/cross-account policy、backend client 和 provider runtime contracts，形成 `WI-S0-02-*` 与 `WI-S0-03-*`。
3. 每项填写 16 字段，路径必须当前存在或显式标新增；不复制凭据值。
4. 两闭环共同定义接口边界：AccountLease 只消费已认证 session；server principal 不信任 payload owner；release policy 在身份/Provider不可用时 fail closed；credential inventory/rotation 不由 iOS持有。
5. 合并后建立四包依赖、R0/R1部署顺序和 external gate，避免同一 session/flag/secret 逻辑重复实现。

## Acceptance Criteria

- 四个 package 均有连续唯一 Work Item，且每项 16 字段完整。
- 所有当前文件/脚本引用经核实，新增模块明确标识。
- Account/Release 与 Identity/Credential 的 authority 边界无重复 writer。
- G0/G1 internal-ready 与 G2/G3/G4 exit gate 区分明确。
- 无 secret 值、无虚构 Provider/生产/真机完成声明。
- 路线图能给出这四包中的确定性首个小闭环及后续依赖。

## Verification Plan

1. 使用独立 iOS 和 backend explorer 证据核对路径与现状。
2. 校验 Work Item ID、16字段、依赖与 primary owner。
3. 对照 IAR-01/02/03/05、BAR-01、SOR-01/02/03 和 CR-01/02/03/08。
4. 运行 architecture/review/link checks 与 diff gate；P055最终全量校验。

## Risks

- AccountLease 若先于强身份落地可能被误当 production-ready；仅允许 fake/G0/G1。
- Credential scan 文档化可能暴露值；只引用类型、位置类别和轮换证据。
- 本地 flag 删除过早会破坏 QA；先 server deny，再删 alias/旧读路径。

## Assumptions

- 本票只修改路线图与过程文档。
- explorer 只读，不直接写路线图；主控负责证据收敛。
