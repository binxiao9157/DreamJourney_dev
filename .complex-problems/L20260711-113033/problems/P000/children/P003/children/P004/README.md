# Canonical 来源跨仓 gate 与文档交付

## Problem

iOS 与后端来源身份实现缺少统一可重复的验证入口，release QA 尚不能防止 legacy 来源重新生成，知识库架构文档对历史 `archiveImageAnalysis` 的解释也需要纠正。

## Success Criteria

- 新增跨仓 source identity gate，覆盖 iOS 模型/client 与后端 canonical proposal、audit、ownership 测试。
- gate 接入 release regression 和 release QA package guard。
- 更新知识库架构与 Task 19 状态文档，明确 conversation photo、Archive item 和 legacy 来源边界。
- 后端完整测试、iOS generic Simulator/iPhoneOS 构建、release regression 与 diff check 通过。
