# Round 3C3C Provider Effect、Credential 与 Exit 迁移方案

## Problem Definition

当前10类外部能力的configured/ready/accepted/usable/deleted语义不统一，部分静态credential可能进入iOS/runtime响应；timeout后可能已执行，callback/查询/删除能力不一；adapter又不能迁移声音模型、数字人素材和授权。需要定义逐Provider的credential、request/receipt、unknown reconcile、callback、delete、canary与exit迁移。

## Proposed Solution

在Product Spec新增Provider migration章：

1. 为Object、Scan、OCR/Parser、ASR、LLM、Vision、TTS、VoiceClone、DigitalHuman、APNs编制current→target→cutover→delete/exit矩阵。
2. 定义Provider状态维度：configured、credentialValid、sandboxVerified、accepted、terminal、businessUsable、externalVerified、deletionState；禁止单一ready覆盖。
3. 长期credential全部服务端secret manager/env化并版本化轮换；iOS仅接Provider真正短期scope credential，否则后端代理或capability blocked。
4. 每个effect使用stable providerRequestId/requestHash/providerCredentialVersion/receipt；timeout先query，unknown不可盲重试。
5. callback验证signature/timestamp/nonce/body hash/request binding和单调状态；重复/乱序只作用同receipt。
6. Synthetic/sandbox先验，真实canary每个request只发一个已批准Provider；高敏/不可逆操作禁止双发真实用户数据。
7. 删除状态区分pending/completed/unsupported/failed/unknown；本地disable不冒充Provider删除。
8. Exit保留用户拥有且合法保留的原始Source，Provider资产需重新训练/授权/生成；记录成本、用户影响和退役门。

## Acceptance Criteria

- 10类Provider均有current evidence、credential、effect、query/callback、business use、delete、cutover和exit。
- Provider状态维度与业务完成明确分离。
- credential rotation包含new-key canary、in-flight旧版本、revoke和artifact/log检查。
- unknown outcome/manual review、stable request和callback replay合同完整。
- 禁止真实高敏数据dual-send；fallback需相同purpose/data contract且UI可解释。
- Voice/DH/APNs/Object等不可逆/外部状态不被本地ready/lease/accepted代替。
- 至少10个migration waves、20个timeout/callback/quota/delete/exit场景。
- Evidence Matrix、Decision refs和静态门禁明确外部未验收。

## Verification Plan

- 静态门禁检查10 Provider rows、状态、credential/rotation、waves、exit和场景。
- 对照当前runtime config、Volc/Tencent/DeepSeek/APNs/mock storage代码与文档。
- 独立reviewer攻击credential泄漏、双发、timeout unknown、callback replay、voice slot、DH quota、APNs accepted和delete unsupported。
- 运行全部V4门禁与`git diff --check`。
- 本轮不调用真实Provider或轮换真实key；sandbox/provider receipt/deletion是真实实施外部门。

## Risks

- Provider文档/套餐/接口会变化，实现前必须用官方合同重新核实。
- 某些资产无法导出/迁移，exit会导致重新采集和用户体验损失。
- 轮换旧credential时在途request可能仍需query，不能立即删除所有旧版本。
- Provider accepted不代表设备播放、口型、通知送达或用户质量认可。

## Assumptions

- 3C3A提供Job/receipt/reconcile，3C3B提供Object。
- DR-026/027/028/031/037/039是Provider地域、成本、退出、数据、声音和测量门。
- 用户提供过的真实credential不得写入成果物、日志或测试fixture。
