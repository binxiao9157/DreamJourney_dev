# AI 分析线索与声音克隆壳层

日期：2026-06-19

## 本轮目标

继续推进两个不依赖真机的 PRD 功能缺口：

1. AI 分析结果展示：人物线索、地点线索、场景线索、标签，以及分析失败/重试。
2. 声音克隆产品壳层：授权说明、声音样本状态、`voiceProfileId`、删除/禁用合同和默认隐藏策略。

## AI 分析展示

本轮不接真实视觉 AI，只固定 mock/seed 和 UI 合同：

- `MemoryArchiveItem` 新增地点/场景线索 metadata 合同。
- 本地分析会从标题和说明中提取人物、地点、场景和标签线索。
- 详情页 `分析线索` 卡片展示：
  - 标签
  - 人物线索
  - 地点线索
  - 场景线索
- 分析失败时展示 `分析失败，可稍后重试。`，并提供 `重新分析` 按钮。
- 新增 UIQA seed：`DJSeedArchiveAnalysisInsights`，用于固定 mock 已分析和失败状态。

## 声音克隆壳层

声音克隆默认不公开：

- 新增 `DJFeature.voiceCloneShell`，不在默认 feature flags 中。
- `DJEnableProfileHiddenBranches` 或 feature flag 打开后，`我的` 设置列表出现 `声音克隆`。
- 新增 `ProfileVoiceCloneShellViewController`，只展示：
  - 授权说明
  - 声音样本状态
  - `voiceProfileId`
  - 删除/禁用合同
  - 禁用/删除按钮的未开放态
- `VoiceCloneService` 新增壳层 snapshot，不调用真实训练或上传。
- `disableVoiceProfile(profileId:)` / `deleteVoiceProfile(profileId:)` 当前只作为本地合同，不声明真实后端已完成。

## 验证入口

```bash
swift Scripts/QA/prd-stitch-ui/archive-analysis-insights-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

## 发布边界

- 真实 AI 分析、真实声音克隆训练、真实样本上传、真实删除/禁用后端接口都不在本轮范围。
- 公开 MVP 默认不暴露 `声音克隆`。
- 声音克隆公开前仍需授权文案、样本采集/质量验收、后端生命周期合同和合规审查。
