# 将危机响应与 AI 披露固定为 Stage 0 独立止损任务

## Problem Definition

`FR-SAFE-001/002` 目前没有独立 Work Item 承担，危机/自伤表达可能被普通 Echo、数字人、时间信件或关怀异步链路延迟处理，AI 身份披露也缺少 route/response 级验收责任。

## Proposed Solution

在 `WP-S0-06` 末尾新增 `WI-S0-06-09`，以结构化 SafetyPolicy/DisclosureDecision 为唯一结果，要求所有入口在生成/延迟/人格化前执行即时分类和 fail-closed 分流。把地区资源目录、文案和法律适用性保留为 G4 外部门；更新 Stage 0 计数、S0-C 批次、停止线和路线交付表。

## Acceptance Criteria

- `WI-S0-06-09` 具备完整 16 字段且精确引用 `FR-SAFE-001/002`。
- 明确禁止危机响应进入延迟回信、角色模仿、诊断或自动干预。
- 未批准地区资源、文案或运营流程时最高 `INTERNAL_READY/EXTERNAL_BLOCKED`。
- Stage 0 变为 50 项/800 字段，相关路线文本一致。

## Verification Plan

检查 Work Item 字段、ID、FR 引用和 stop-line；运行 Product V4 文档/路线检查和 `git diff --check`。

## Risks

- 安全文案可能被误读为已具备医疗能力；必须将产品披露、危机资源和医疗诊断边界分开。
- 只做客户端提示会被深链或后端 command 绕过；iOS/backend scope必须同时存在。

## Assumptions

- V4 只定义危机止损和资源引导，不提供诊断、医生或自动干预。
- 地区资源列表和运营升级流程仍需 Product/Privacy/Legal/Operations 决定。
