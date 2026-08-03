# Round 2B2 生命周期、四维隐私与变更传播方案

## Problem Definition

现有 status/privacyScope/isPrivate/generationAllowed 等字段混合了业务状态、分析状态、用途同意、可见性和发布状态；纠正、删除、撤回与 provider 删除也缺少统一传播语义。需要把关键对象生命周期和安全维度拆开，使 API、数据库、UI 和异步任务可以独立实现与验证。

## Proposed Solution

1. 分别定义 Source、Candidate、Confirmed Memory Record/Version、Publication、Voice Profile 的状态机、终态、重试、幂等和并发规则。
2. 将业务状态与 upload/processing/analysis/provider delivery 等 operation state 分离，避免一个枚举表达多个轴。
3. 定义 sensitivity、usage consent、visibility、publication state 四维模型；未知或无 grant 时采用最高限制。
4. 建立变更传播表：先同步提升 authorization epoch/阻断新读取，再通过事务 outbox 执行 Projection、缓存、对象、provider 和索引清理。
5. 把删除结果分为 requested/revoked/purging/completed/incomplete，并按在线数据、对象、索引、日志、备份、供应商分别记录回执。
6. 明确 Source 删除、Candidate 拒绝、Memory 修正/删除、Publication 撤回、Voice 撤权/删除、账号删除和第三方异议的后果。

## Acceptance Criteria

- 五个关键对象均有允许转换、禁止转换、幂等键/版本要求和失败恢复。
- 业务生命周期不再复用分析、上传或 provider runtime 状态。
- 四维隐私模型有明确枚举、默认和降低限制的授权条件。
- 未确认、失败、草稿、未到期、未接受邀请和 runtime 状态不能变成确认/发布事实。
- 变更传播区分同步访问阻断和异步物理清理，并明确各类数据回执。
- 删除和撤回措辞不承诺无法证明的外部副本立即消失。

## Verification Plan

1. 对每个状态机执行合法路径、重复请求、过期回调和非法跳转表检查。
2. 组合四维隐私值验证无 grant、unknown sensitivity 和 withdrawn publication 均拒绝访问。
3. 对七类变更事件验证 authorization epoch、outbox、Projection/Public Index/provider/backup 回执。
4. 运行术语/状态静态检查和 `git diff --check`。

## Risks

- 枚举过多造成实现复杂度，却没有分清 authority 与 operation state。
- 用“删除完成”覆盖供应商或备份仍未处理的情况。
- 修正私人记忆后静默改写已经发布的历史快照。
- 声音私用授权被错误推导为 Visitor 公用授权。

## Assumptions

- 实际删除 SLA 和备份保留期限仍需决策登记册确认。
- Publication 撤回只保证平台控制范围内停止未来访问，无法收回已被外部保存的副本。
- 当前 JSONB 状态在迁移期间可映射为 legacy/unknown，不强行伪造为新状态。
