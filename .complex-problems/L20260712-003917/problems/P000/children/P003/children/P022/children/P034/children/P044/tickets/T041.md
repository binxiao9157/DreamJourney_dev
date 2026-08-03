# 收敛组合 Runbook Evidence、Decision 与静态门

## Problem Definition

Product Spec 第 34 节已经形成组合 Runbook，但需要独立证据层证明其结构完整，并明确区分设计成熟度、产品决定和真实生产演练。否则后续编辑可能丢失 rollback plane、wave 字段、不可逆边界或退役证据。

## Proposed Solution

1. Evidence Matrix 新增 7.9，记录 composite authority/waves、rollback planes、irreversible compensation、go/no-go、retirement 和 production drill 的成熟度。
2. Decision Register 增加 Round 3C4 映射，说明 DR-040 是主要参数/批准门，并引用 DR-023/026/028/031/035/039/041；不新增无依据的产品确认。
3. 新增 `product-v4-composite-migration-runbook-check.py`，精确切分第 34 节并验证 34.0-34.10、五个 plane、C00-C11、每行单元格、MRT、go/no-go字段、七类 retirement 和至少 18 个场景。
4. 将 Provider checker 的章节切分作为追加第 34 节后的回归点，并运行全部 Round 3C migration checks。

## Acceptance Criteria

- Evidence Matrix 7.9 明确 `DESIGNED/CONTRACT_ONLY/DECISION_REQUIRED/EXTERNAL_ACCEPTANCE`，不出现生产已演练的错误表述。
- Decision mapping 保留 DR 的真实状态，并声明技术文档通过不等于 `CONFIRMED`。
- checker 精确验证 C00-C11、五个 plane、11 个业务单元格、MRT-C00-C11、go/no-go schema、七类 retirement、24 个或至少 18 个场景和关键不可逆文本。
- data backfill/cutover、iOS account/store、API/AuthZ、Job/Outbox、Object/Media、Provider 及基础 docs/evidence 检查全部通过。
- `git diff --check` 通过；Closure 同步造成的 EOF 空行仅做格式清理。

## Verification Plan

依次运行新增 composite checker、七个 Round 3C 分域 checker、jobs/provider 与 data/api 基础 checker、docs/evidence checks 和 `git diff --check`；任何失败先定位章节污染或真实缺失，再修复并完整重跑。

## Risks

- Markdown 宽表可能漏字段但视觉不易发现，需要按单元格数量和 MRT 编号双重检查。
- 全文关键词搜索会被第 28 节或历史章节假满足，必须精确切第 34 节。
- 生产参数 UNKNOWN 不能因脚本通过被误记为已验收。

## Assumptions

- 第 34 节的组合模型已由 3C4A 独立检查通过。
- 本票不运行真实迁移、生产 restore、Provider 或真机测试。
- 本票不修改生产代码或公开 UI。
