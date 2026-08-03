# 建立 Round 3 架构、评审与链接静态验收

## Problem Definition

Round 3 架构和22项评审响应需要独立可重复验证，防止ID遗漏、开放高风险、关键模块/Authority/迁移不变量丢失或文档链接失效。

## Proposed Solution

1. 新增review coverage checker，验证三报告和响应的ID全集、8字段、disposition集合、CR/WP映射、无开放状态、Evidence/Decision/Stage0同步。
2. 新增architecture invariant checker，验证iOS六层、后端模块化单体、核心authority对象、principal/AuthZ、Job/Object/Provider、C00-C11、36 FR/41 DR及关键禁止模式。
3. 新增V4 docs link/reference checker，扫描V4 Markdown相对链接和反引号绝对证据路径，剥离行号后验证存在；不读取文件内容或secret。
4. 运行全部Product V4 checks和diff gate。

## Acceptance Criteria

- review checker精确报告IAR7/BAR7/SOR8/response22且无OPEN。
- architecture checker验证必需章节/术语/编号和禁止模式，不依赖全文模糊计数。
- link checker无broken relative link或absolute evidence path。
- 全部现有Product V4 checks通过。
- `git diff --check`通过；不将静态通过解释为生产完成。

## Verification Plan

分别运行新增3个checker，再运行Scripts/QA/product-v4全部python检查；修正任何真实失败后完整重跑。

## Risks

- 反引号中可能包含非路径文本；只处理`/Users/`前缀。
- 行号后缀可能使存在路径被误报；link checker需安全剥离。
- 关键词检查可能从错误章节假通过；architecture checker对关键迁移使用精确编号集合。

## Assumptions

- 当前V4三报告和响应是固定输入。
- 不扫描或输出任何secret内容。
