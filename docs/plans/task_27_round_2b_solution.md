# Round 2B 领域模型、数据权威与权限状态机方案

## Problem Definition

当前 iOS 的 Archive/KBLite/Echo/Persona/Family 模型与后端 JSONB 合同分别承担了部分产品含义，但没有一套统一的产品权威模型。`isPrivate`、privacyScope、personaScope、status 和 provider 状态被用于表达不同层次的敏感性、授权、可见性、发布和运行状态，存在把模型推断、草稿或 runtime 状态当作用户事实的风险。

## Proposed Solution

1. 先定义角色和产品域：Owner、Visitor、Operator、Admin、未来 Family Contributor；私人记忆域、发布域和运行时域相互隔离。
2. 为 Source、Memory Candidate、Confirmed Memory Record/Version（技术实现可继续使用 Canonical Memory 命名）、Knowledge Projection、Persona、Conversation、Publication、Visitor Session、Voice Profile、Digital Human Runtime 指定唯一含义和权威系统。
3. 建立允许的数据流：Source 到 Candidate、Owner 审核到 Confirmed Record、权威记录到 Projection、确认记录到 Publication 快照；禁止从 Projection、runtime 或 Visitor 会话反向静默写入权威记忆。
4. 定义角色权限矩阵，并补充 Data Subject/第三方信息权利作为政策约束，不把 Owner 对他人的记录权等同于公开权。
5. 定义 Source、Candidate、Confirmed Record、Publication、Voice Profile 的生命周期、禁止转换、并发版本和失败恢复。
6. 将 sensitivity、usage consent、visibility、publication state 拆成四个正交维度；默认保持最高限制，降级必须有确定性授权。
7. 定义纠正、删除、撤回、过期和授权变化向 Projection、缓存、Publication、Visitor、provider 与审计记录的传播规则。
8. 将结果写入 Product Spec，并为 Round 3 的数据库和 API 目标架构提供不依赖具体供应商的约束。

## Acceptance Criteria

- 每个核心概念只有一个产品含义、一个权威系统和明确的派生关系。
- “Confirmed Memory Record”只表示 Owner 当前认可的记录版本，不被描述为客观真相。
- Owner/Visitor/Operator/Admin/Future Family Contributor 权限矩阵覆盖读、写、审核、发布、撤回、导出、删除和 provider 操作。
- 私人域、发布域、runtime 域的数据流和禁止反向写入规则清晰。
- 五个关键对象有状态机、禁止转换、幂等或版本要求和异常恢复边界。
- 四维隐私模型不存在用一个布尔字段同时表达多种含义的情况。
- 未确认 Candidate、失败分析、未到期 TimeLetter、未接受 Family 邀请、runtime 状态和 Visitor 输入不能成为已确认或可发布事实。
- 删除/纠正/撤回传播规则覆盖客户端缓存、Knowledge Projection、Publication、公共索引、会话引用、对象存储、provider 和审计。

## Verification Plan

1. 用角色-资源-操作表检查 deny-by-default 和跨租户场景。
2. 用状态转换表检查非法跳转、重复请求、过期回调和并发版本冲突。
3. 用五个失败场景验证传播：Source 删除、Confirmed Record 修正、Publication 撤回、Voice 授权撤回、第三方异议。
4. 对照 iOS/后端现有模型，标记可映射、需迁移和禁止继续作为权威的字段。
5. 运行术语和状态枚举静态检查、证据矩阵检查与 `git diff --check`。

## Risks

- 领域词典过度抽象，无法映射当前代码或产生大规模重写要求。
- 把 Owner 的主观确认错误包装为客观真相。
- 将第三方/未成年人权利遗漏在 Owner 权限之外。
- 删除传播承诺超出备份和供应商实际能力。
- 把技术状态、模型置信度或可见性混入同一个生命周期字段。

## Assumptions

- 产品展示使用“已确认记忆/记录”，技术模型可在迁移期保留 `CanonicalMemory` 名称并明确语义。
- Knowledge Projection 保留为可重建缓存，不升级为业务真相。
- Publication 必须是独立快照，而不是私人记录的过滤视图。
- 重大地域、第三方处理商和删除 SLA 由决策登记册确认，领域模型只定义可执行边界。
