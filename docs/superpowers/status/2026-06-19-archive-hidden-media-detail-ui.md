# Archive Hidden Media Detail UI

日期：2026-06-19

## 目标

本轮继续推进隐藏媒体详情 UI 的非真机完善，把语音、视频、时间信件从“合同可验”推进到“体验可验”，同时保持公开 release 不误暴露隐藏入口。

## 隐藏媒体详情 UI

覆盖范围：

- 语音空态：缺少本地音频文件时显示“媒体文件待补充”，不展示可播放状态。
- 视频壳层：详情页显示视频封面/占位卡，缺少本地视频时显示“视频待补充”。
- 本地态：音视频文件仅在本地保存时显示“媒体文件仅保存在本地”。
- 已上传态：mock upload intent 成功后显示“媒体元数据已同步”。
- 失败态：mock upload 失败后显示“上传失败，可重新同步”和失败原因。
- 重试态：失败态保留“重新上传”入口，并说明当前不会执行真实对象存储 PUT。

## 时间信件详情 UI

覆盖范围：

- 草稿态：显示“草稿未封存”，保留编辑、封存、删除操作。
- 空内容态：草稿内容为空时显示可继续编辑的占位说明。
- 封存态：显示“投递策略待产品决策”，说明真实投递、通知、收件人规则暂不开放。

## 公开 release 不误暴露

默认 release 仍不展示：

- 录入语音
- 录入视频片段
- 录入时间信件
- 生成测试视频档案

隐藏入口仍需通过 feature flag 或 `DJEnableArchiveHiddenBranches` 进入。

## 验证

静态 guard：

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-hidden-media-detail-ui-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

模拟器 smoke：

```bash
RUN_ID=20260619-hidden-media-detail-ui tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh
```

Release regression 可用：

```bash
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## 暂不覆盖

- 真实麦克风录音质量。
- 真实视频选择、压缩和播放。
- 真实对象存储 PUT。
- 时间信件真实投递、通知、收件人规则。
