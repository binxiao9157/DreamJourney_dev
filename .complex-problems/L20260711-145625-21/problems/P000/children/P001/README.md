# 定义默认拒绝的 Widget 知识快照与隐私策略

## Problem

当前共享 JSON 直接包含全部事件正文和原始标识，缺少独立 Widget 授权、schema、owner digest 和可测试的字段边界。需要先建立不依赖 WidgetKit/文件系统的纯模型合同，作为主 App 写入端和 Widget 读取端共同遵循的隐私基线。

## Success Criteria

- `KBPrivacyMetadata` 兼容增加可选 `widgetVisibility`，legacy/default 为 deny。
- 纯策略只允许当前 owner、generationAllowed、summaryAllowed、personal、confirmed 事件。
- schema v2 快照只含 owner digest、generatedAt 和最小事件摘要，不含 raw ID、description 或 sourceRefs。
- 纯模型 smoke 覆盖允许组合、拒绝矩阵、摘要截断和 owner digest，测试先于生产行为修改建立。
- 该子问题不接触 WidgetKit、App Group IO 或 Xcode 工程配置。
