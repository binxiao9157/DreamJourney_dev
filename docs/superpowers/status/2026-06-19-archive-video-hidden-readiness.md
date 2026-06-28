# 视频档案 Hidden Readiness

日期：2026-06-19

## 目标

本轮只强化隐藏视频档案的非真机准备度：mock 视频详情、缩略图占位、文件大小、上传状态、分析失败/重试和时间胶囊列表识别。

## 范围

- 列表：时间胶囊卡片能区分视频缩略图和无缩略图占位。
- 详情：展示缩略图/占位、文件大小、上传状态、分析状态、失败和重试入口。
- 验收：隐藏 UIQA smoke 覆盖列表和详情状态。

## 明确不做

- 不做真实视频选择和压缩。
- 不做真实对象存储文件 PUT。
- 不把视频入口放到公开 release。

## 验证

```bash
swift Scripts/QA/prd-stitch-ui/archive-video-hidden-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
```
