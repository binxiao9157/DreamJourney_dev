# 以源码和 QA 证据重建 iOS 能力矩阵

## Problem Definition

iOS 工程有 112 个 Swift 源文件，并长期通过 feature flag、QA launch arg 和 backend-ready client 演进。历史“完成”标签无法回答功能是否公开、是否真实持久化、是否经过真机/provider 验收。

## Proposed Solution

按 Account、Archive/Source、Knowledge/Memory、Echo/Conversation、Voice、Digital Human、Family/Persona/Care、TimeLetter/Message、Publication/Visitor、Privacy/Safety 十个能力域审计。每域记录入口、模型、服务、持久化、后端调用、flag 和 QA；按统一成熟度枚举归类并映射 FR。

## Acceptance Criteria

- 十个能力域均有文件和符号级证据。
- 公开入口、hidden QA、mock、backend-ready 和 external acceptance 明确区分。
- 识别可直接保留的稳定模块和不应无脑重构的边界。
- 识别会阻断 Product Spec V4 的 P0 事实缺口。

## Verification Plan

独立 explorer 全仓扫描；主 agent 抽查关键入口、feature flag、client 和 QA gate；所有引用路径存在，成熟度使用固定枚举。

## Risks

- 大型 ViewController 可能同时包含生产和 QA 路径，必须按调用入口而不是类型存在判定成熟度。

## Assumptions

- 本地分支 `feature/prd-stitch-ui-adaptation` 是当前 iOS 审计基线。
