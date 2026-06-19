# 档案音视频后端合同

日期：2026-06-19

## 本轮目标

推进两个不依赖真机的 PRD 缺口：

1. 录音档案的数据模型和后端合同。
2. 视频档案壳层和合同。

本轮不开放公开入口，不做真实视频选择，不做真实媒体上传，不声明真机录音或视频能力通过。

## 录音档案的数据模型和后端合同

iOS 侧 `MemoryArchiveItemFactory.makeAudioItem` 已形成音频 schema：

- `kind = audio`
- `ownerUserId`
- `uploadedByUserId`
- `uploaderUserId`
- `personaScope`
- `digitalHumanId`
- `uploadStatus`
- `analysisStatus`
- `transcriptionStatus`
- `transcriptText`
- `transcriptLanguage`
- `durationSeconds`
- `durationText`
- `fileType`

`MemoryArchiveItem.archiveBackendPayload` 负责生成统一后端 payload，包含 owner metadata、personaScope / digitalHumanId、分析状态、标签、人物线索和 backend-safe metadata。

公开 release 仍不默认同步 audio；当前只是让 hidden QA 和后端 mock payload 有稳定合同。

## 视频档案壳层和合同

iOS 侧新增视频 item factory 合同：

- `kind = video`
- `thumbnailPath`
- `thumbnailStatus`
- `fileSizeBytes`
- `fileSizeLimitMB = 200`
- `uploadStatus`
- `analysisStatus`
- `backendStorageContract = metadata_only_object_storage`

视频入口仍是 hidden candidate。`MemoryArchiveVideoEntryViewController` 支持隐藏 QA 生成 mock 视频档案，用于验证：

- 分析状态 UI。
- 文件大小限制配置。
- 缩略图字段。
- 本地 mock 文件恢复。
- 后端 metadata-only 存储合同。

它仍不会打开系统视频选择、不会做真实压缩、不会真实上传视频。

它不会打开相册、不会生成真实视频档案、不会上传文件。

## 后端合同

FastAPI `/archive/items` 通过 mock payload 验证：

- audio payload 可接收并回传 `transcriptText`、`transcriptionStatus`、`uploadStatus`、owner metadata、personaScope / digitalHumanId。
- video payload 可接收并回传 `thumbnailObjectKey`、`thumbnailStatus`、`fileSizeBytes`、`fileSizeLimitMB`。
- 后端会移除本地路径和 raw 媒体字段：
  - `localPath`
  - `rawAudioURL`
  - `rawVideoURL`
  - `rawTranscript`
  - `thumbnailPath`
  - `localThumbnailPath`

## 验证入口

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-media-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev

cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_core_services.ArchiveAPITests.test_archive_items_api_persists_audio_contract_fields \
  tests.test_core_services.ArchiveAPITests.test_archive_items_api_persists_video_contract_fields
```

## 发布边界

- 语音档案：仍需真机麦克风、拒绝恢复、重新授权、录音质量和详情播放验收后再考虑公开。
- 视频档案：仍需真机视频选择、压缩、缩略图生成、对象存储上传和隐私文案验收。
- 当前公开 MVP 不能默认暴露 audio/video 创建入口。
