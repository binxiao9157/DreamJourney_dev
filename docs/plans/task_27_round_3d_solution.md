# 执行 Round 3D 目标架构独立复审与静态验收

## Problem Definition

Product Spec 第 22-34 节由同一主控逐步形成，存在自洽但不可落地、忽略当前代码、权限/数据权利缺口、迁移不可操作或过度设计的风险。需要互相独立的 iOS、后端、安全/运维评审，并由主控对每项异议给出证据化响应和静态门。

## Proposed Solution

1. 启动三个互不共享结论的只读评审：iOS/客户端可落地性；后端/数据/异步可落地性；安全/隐私/运维/过度设计。
2. 每个评审使用统一严重度 `BLOCKER/HIGH/MEDIUM/LOW`，必须引用 Product Spec 与真实源码/测试/部署证据，并区分“文档缺陷、实现缺口、产品决定、外部验收”。
3. 主控建立 Round 3 架构评审响应表，逐项接受、部分接受或反驳；所有 BLOCKER/HIGH 必须修正文档或进入明确 DR/External gate，不能只写“后续注意”。
4. 对修正后的架构执行交叉一致性检查，重点防止双 Authority、客户端 owner/principal 信任、私人库过滤即 Publication、长期 Provider credential 下发、rollback 抹除不可逆事实和大爆炸重写。
5. 新增架构静态验收脚本，验证模块、数据对象、API/AuthZ、迁移、Decision/FR 映射、禁止模式和评审响应覆盖。

## Acceptance Criteria

- 三类独立评审各自形成可追踪报告，且评审 agent 不修改 Product Spec。
- 所有 BLOCKER/HIGH 有明确 disposition、修改证据、DR 或 External gate；无悬空高风险项。
- 修正保持与当前 iOS/backend baseline 可增量迁移，不创建平行 Domain/第二 Authority。
- 架构 checker 覆盖 iOS层、后端模块、核心对象、principal/AuthZ、job/object/provider、C00-C11、DR/FR和禁止模式。
- Product V4 全部检查、架构检查、Markdown链接/引用检查和 `git diff --check` 通过。
- 输出 Round 3 独立评审响应文档，并明确尚未证明的生产/真机/provider边界。

## Verification Plan

分别验收三份报告的引用和分类；主控对每项建立唯一 Review ID 和 disposition；运行 review coverage checker 确保 BLOCKER/HIGH 无遗漏，再运行全部 V4 checks、链接扫描和 diff gate。

## Risks

- 多 agent 可能重复同一问题；按 iOS、backend、security/ops 写清责任边界，并在综合时去重而不抹掉独立证据。
- 评审可能把“尚未实现”误判为“架构错误”；必须以本轮目标是可执行增量设计为准。
- 主控可能只接受容易修的意见；BLOCKER/HIGH 必须逐项映射，不得选择性回应。
- 静态检查不能替代真实代码/生产验收，最终状态必须保留成熟度标签。

## Assumptions

- 三个 agent 只读当前工作区，不提交、不回退任何变更。
- 主控拥有 Product Spec、Evidence Matrix、Decision Register 和 checker 的唯一写权限。
- 本轮不修改 iOS/后端生产代码、不部署、不跑真机。
