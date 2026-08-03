# Round 2B1 角色、领域权威与数据流方案

## Problem Definition

工程已有多个局部模型和权限策略，但无法回答同一对象由谁创建、谁确认、谁能读取、谁负责删除，以及 Projection/runtime 是否可以反写产品事实。需要形成产品级唯一角色和领域权威表。

## Proposed Solution

1. 定义 Owner、Visitor、Operator、Admin、未来 Family Contributor，并把第三方 Data Subject 作为权利约束而非登录角色。
2. 为十一类核心对象记录产品含义、目标权威系统、当前工程映射和禁止用途。
3. 建立资源-操作权限矩阵，Admin 仅允许受审计 break-glass，不得替 Owner 确认、发布或授权声音。
4. 建立私人域、发布域、运行时域的单向流向，禁止 Projection、assistant/Visitor 消息和 provider 状态静默反写权威记忆。
5. 将当前 Archive、KBLite、Context Packet、Voice Registry 和 DigitalHumanRuntime 映射为保留、投影、迁移输入或 runtime，不要求立即重写。

## Acceptance Criteria

- 角色权限覆盖读、写、审核、发布、撤回、导出、删除和 provider 操作，默认拒绝。
- 所有核心对象有唯一含义、authority、派生关系和禁止用途。
- Owner 对第三方的记录权不自动产生公开权；第三方异议和删除请求进入政策边界。
- 允许数据流可从 Source 追踪到 Owner QA 或 Visitor，而不会从 Projection/runtime 反写事实。
- 当前 iOS/后端模型有明确的保留和迁移定位。

## Verification Plan

1. 运行 Owner、Visitor、Operator、Admin、Family Contributor 的允许/拒绝场景表。
2. 检查每个核心对象只出现一个权威系统。
3. 检查所有跨域流都经过显式审核、Publication 或 Usage Grant。
4. 对照证据矩阵的 iOS/后端模块结论，确认不存在把现有实现升级为未证明 authority 的表述。

## Risks

- 将 Admin 维护能力扩大成读取私人正文或代替用户决策。
- 将 Family 贡献误写成共享私人库。
- 把现有 KBLite 或 Archive JSONB 直接宣称为新权威模型。

## Assumptions

- 产品展示使用“已确认记忆记录”，技术迁移期可保留 Canonical 命名。
- Operator 默认只能读取任务和脱敏元数据。
- Visitor 首版采用受控身份/邀请，不以匿名为默认。
