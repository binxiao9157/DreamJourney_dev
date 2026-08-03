# 收敛 Round 3C3C Evidence 与 Provider 静态门

## Problem Definition

Product Spec 第 33 节已形成 Provider Effect、Credential 与 Exit 的完整推荐设计，但 Evidence Matrix 尚未记录其设计/实现/外部验收边界，也没有专用静态门保护 F01-F10、V00-V11 和关键安全不变量。第 32 节检查脚本还可能把后续章节纳入统计，造成假阳性。

## Proposed Solution

1. 在当前实现证据矩阵新增 `7.8 Round 3C3C Provider 设计状态`，逐项标记 Provider state/receipt、F01-F10、credential boundary、V00-V11、delete/exit 和真实质量验收状态。
2. 核对 DR-026、DR-027、DR-028、DR-031、DR-037、DR-039 等既有决定是否足够承载本节；不新增无产品依据的 `CONFIRMED` 决策。
3. 新增 `product-v4-provider-migration-check.py`，限定扫描第 33 节并验证章节、矩阵编号、波次、场景数量和关键安全文本。
4. 将 `product-v4-object-media-migration-check.py` 的第 32 节扫描范围截止到第 33 节。
5. 运行 Provider、Object/Media、Job/Outbox、基础文档、证据矩阵检查以及 `git diff --check`，保存可复核输出。

## Acceptance Criteria

- Evidence Matrix 存在 7.8，且不会将设计目标误标为当前实现或外部验收完成。
- Provider checker 精确覆盖 `33.0` 至 `33.9`、`F01` 至 `F10`、`V00` 至 `V11` 和不少于 20 个故障场景。
- checker 验证 credential 状态、真实短期凭证边界、stable request、unknown/manual review/dead-letter、callback security、禁止真实用户高敏数据 dual-send、delete/exit 和相关 DR 引用。
- Object/Media checker 只扫描第 32 节，不因第 33 节内容通过错误计数。
- 所有相关检查和 `git diff --check` 通过；若检查揭示现有文档缺陷，必须修正后重新运行。

## Verification Plan

运行新增 Provider checker、Object/Media migration checker、Job/Outbox migration checker、jobs/provider contract checker、V4 docs checker、evidence matrix checker 与 `git diff --check`；同时用编号集合检查确保 F/V 编号无缺失、重复或越界。

## Risks

- 全文正则可能扫描到历史或后续章节形成假阳性，脚本必须先切出第 33 节。
- 仅检查关键词存在不能证明设计一致，需同时检查编号集合、场景数量和 Evidence Matrix 状态标签。
- Decision Register 引用可能被误当作已经确认，必须保留其真实状态。

## Assumptions

- 第 33 节主体内容保持不变，除非静态检查暴露真实缺失。
- 本票不运行真实 Provider、真机、生产 credential 或删除演练。
- 本票不修改 iOS/后端生产代码，也不改变公开 UI。
