# 收敛知识治理设计状态与双仓提交

## Problem Definition

Task 16 的后端、iOS 和 QA 已通过本地验证，但 canonical 架构与任务 checklist 仍显示计划态，缺少面向后续开发者的中文状态文档。两仓库也尚未形成独立可审阅提交，Closure/Lodestar 生成物中包含不应提交的 dashboard 和临时尾部空白风险。

## Proposed Solution

更新 canonical 知识库设计的 implementation status 和 Task 16 checklist；新增 Task 16 状态文档，说明业务语义、接口、iOS outbox/coordinator、Archive 删除级联、QA 命令、公开 UI 边界、legacy sourceRef 迁移缺口及部署边界。审阅两仓库 diff、删除本任务生成的未跟踪 dashboard、检查敏感信息和临时产物。先提交后端功能/测试/gate，再提交 iOS 功能/QA/docs/Ledger，不推送不部署。

## Acceptance Criteria

- canonical 设计、Task 16 和状态文档内容与实际代码一致，明确已完成/未完成/不在范围。
- 文档记录 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1`、后端 runner、Simulator/generic iPhoneOS 证据路径。
- 明确公开 UI 仍未开放，legacy `archiveImageAnalysis/session-*` 不会被新 `memoryArchiveItem/archive-id` 级联自动匹配。
- `.complex-problems/dashboard.html` 与临时测试产物不进入提交；无 key/token/真实敏感配置进入 diff。
- 两仓库最终 diff check 和关键 gate 通过。
- 后端、iOS 分别提交，提交信息清楚；不 push、不 deploy。

## Verification Plan

审阅 `git diff --stat` 和敏感词扫描；运行 governance package/gate 的最终轻量检查、两仓库 `git diff --check`；提交后检查 `git status --short`、`git log -1` 和提交文件清单。

## Risks

- Closure sync 会在 `progress.md` 末尾增加空白，必须在最终提交前修正并避免提交后继续改写。
- 两仓库改动量较大，提交时必须使用显式 path staging，避免混入 tmp、LocalConfig、密钥或无关用户改动。

## Assumptions

- 当前两个工作区的未提交业务改动均属于 Task 16；提交前仍需逐项确认。
- 用户未要求推送，因此只创建本地提交。
