# 档案媒体上传 Intent Mock 合同

日期：2026-06-19

## 本轮目标

补对象存储/上传 intent 的 mock 合同，给后续真实媒体上传留稳定接口。

本轮只做合同，不做真实对象存储：

- 不上传真实文件。
- 不下发云厂商密钥。
- 不默认公开语音/视频入口。
- 不声明真机录音或视频选择已通过。

## 后端合同

新增 endpoint：

```http
POST /archive/media/upload-intent
```

请求字段：

- `userId`
- `archiveItemId`
- `kind`: `audio` 或 `video`
- `fileName`
- `contentType`
- `fileSizeBytes`
- `personaScope`
- `digitalHumanId`
- `privacyMetadata.scope`

mock 返回字段：

- `uploadIntentId`
- `archiveItemId`
- `kind`
- `storageProvider = mockObjectStorage`
- `objectKey`
- `uploadURL = mock://archive-media/...`
- `expiresAt`
- `expiresInSeconds = 900`
- `maxFileSizeBytes`
- `requiredHeaders`
- `personaScope`
- `digitalHumanId`

限制：

- audio 上限：50MB。
- video 上限：200MB。
- `localOnly` 隐私范围拒绝。
- 非 audio/video 类型拒绝。
- `contentType` 必须匹配媒体类型前缀，例如 `audio/*` 或 `video/*`。
- `objectKey` 只使用归一化后的安全路径片段，不直接拼接原始本地路径。

## iOS 合同

`DreamJourneyBackendClient` 新增：

- `ArchiveMediaUploadIntent`
- `requestArchiveMediaUploadIntent(payload:)`

`MemoryArchiveItem` 新增：

- `archiveMediaUploadIntentPayload(...)`

这些只固定客户端和后端之间的字段，不触发真实上传。

## 验证

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-media-upload-intent-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev

cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_core_services.ArchiveAPITests.test_archive_media_upload_intent_returns_mock_contract \
  tests.test_core_services.ArchiveAPITests.test_archive_media_upload_intent_rejects_unsupported_kind_or_size
```

## 后续接真实对象存储时

只替换后端 `storageProvider`、`uploadURL`、`requiredHeaders` 的生成逻辑；iOS 侧继续消费同一个 `ArchiveMediaUploadIntent` 结构，再补真实文件 PUT/POST、上传进度、失败重试和上传完成回调。
