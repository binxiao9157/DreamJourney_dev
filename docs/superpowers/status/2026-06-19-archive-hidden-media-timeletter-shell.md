# P1 隐藏媒体与时间信件壳层

日期：2026-06-19

## 范围

本轮只推进非真机部分，保持公开 MVP 默认不暴露隐藏入口：

- 语音档案非真机部分：继续沿用本地假音频文件、转写字段、上传状态、分析状态和后端合同字段。
- 视频档案非真机部分：隐藏 QA 入口可以生成 mock 视频文件和本地缩略图，占位验证 schema、文件大小、上传状态、分析状态和对象存储合同。
- 时间信件壳层：支持本地创建草稿与封存状态，明确投递、提醒、收件人和真实通知仍等待产品决策。

## 发布边界

- 默认 release 仍只暴露文字与照片入口。
- 语音、视频、时间信件仍需 `DJFeature.archiveAudioUpload`、`DJFeature.archiveVideoUpload`、`DJFeature.timeLetters` 或 `DJEnableArchiveHiddenBranches` 才能出现。
- 视频壳层不会打开系统视频选择，不会做真实视频压缩，不会真实上传。
- 时间信件不会触发真实通知或投递。

## 验证

新增：

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-hidden-media-timeletter-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

单独 smoke：

```bash
tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh
```

smoke 会生成假音频、假视频、时间信件草稿、时间信件封存记录，并验证本地恢复、转写字段、缩略图字段、上传状态和隐藏入口开关。

## 后续缺口

- 真机麦克风授权、拒绝恢复、录音质量和详情播放。
- 真实视频选择、压缩、缩略图生成质量和大小限制。
- 真实对象存储上传。
- 时间信件投递时间、收件人、提醒策略、取消/编辑规则。
