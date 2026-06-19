# Archive Media Echo Context Polish

日期：2026-06-19

## 目标

本轮推进 P1 隐藏媒体非真机能力，不开放公开入口：

- 视频档案详情/列表 polish：时间胶囊卡片识别视频类型，详情页展示缩略图占位、文件大小、上传状态、分析状态，以及 mock 视频失败/重试 UI。
- 语音档案详情非真机增强：展示转写文本，区分未转写、转写中、已转写、失败，并保留 pending/analyzed/failed/retryable 分析状态。
- 档案媒体进入 Echo 上下文规则：音频只注入已转写文本或用户说明；视频未分析时不注入空人物/地点线索；时间信件草稿不进入 Echo，封存后可进入上下文。

## 验证

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-media-echo-context-polish-check.swift \
  /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

模拟器 Archive -> Echo media context smoke：

```bash
RUN_ID=20260619-archive-media-echo-context-smoke \
tmp/visual-qa/prd-stitch-ui/run-archive-media-echo-context-smoke.sh
```

该 smoke 在 UIQA 环境下种入 fake audio、pending video、draft timeLetter、sealed timeLetter，并验证：

- 音频优先注入转写文本，不注入本地路径。
- 视频 pending 时只注入用户说明，不注入人物、地点、场景、标签线索。
- 时间信件草稿不进入 Echo。
- 时间信件封存后可进入 Echo。

Release regression 可选开关：

```bash
RUN_ARCHIVE_MEDIA_ECHO_CONTEXT_SMOKE=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## 暂不覆盖

- 真实视频选择、压缩、缩略图生成。
- 真实音频录制质量和麦克风权限。
- 真实对象存储 PUT。
