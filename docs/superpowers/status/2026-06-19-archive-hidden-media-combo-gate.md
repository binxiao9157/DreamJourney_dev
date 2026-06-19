# Archive Hidden Media Combo Gate

日期：2026-06-19

## 目标

本轮新增隐藏媒体组合 gate，把模拟器 UIQA 和真实后端 hidden media sync smoke 串成一个 P1 回归入口，用于验证“mock 媒体详情状态 + /archive/items 持久化字段”前后端一致。

## 覆盖范围

- UIQA hidden media detail smoke：
  - 语音空态
  - 语音转写失败/重试
  - 视频缩略图占位
  - 视频上传失败/重试
  - 时间信件草稿、空内容、封存态
- 真实后端 hidden media sync smoke：
  - `/archive/media/upload-intent`
  - `/archive/items`
  - `GET /archive/items/{userId}`
  - audio/video/timeLetter metadata roundtrip
  - local/raw media path privacy filtering

## 运行方式

```bash
RUN_ID=20260619-hidden-media-combo-gate \
tmp/visual-qa/prd-stitch-ui/run-archive-hidden-media-combo-gate.sh
```

Release regression 可选开关：

```bash
RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

Release handoff 常态 gate：

```bash
RELEASE_HANDOFF_MODE=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

`RELEASE_HANDOFF_MODE=1` 会强制设置 `RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1`，用于持续守住视频/语音详情 UIQA 状态和 `/archive/items` 持久化字段的一致性。

## 依赖

- 模拟器可用。
- 部署后端可用。
- 后端访问配置由 `DreamJourneyBackend/private/deployed-backend-access.md`、`DreamJourneyBackend/deployed-backend-access.md` 或环境变量 `BACKEND_BASE_URL` / `BACKEND_API_TOKEN` 提供。
- 报告不会输出 token 明文。

## 暂不覆盖

- 真实麦克风录音质量。
- 真实视频选择、压缩、播放。
- 真实对象存储 PUT。
- 时间信件真实投递、通知、收件人规则。
