# Archive Hidden Media Backend Upload Lifecycle

日期：2026-06-19

## 目标

本轮围绕 PRD 里的隐藏媒体与时间信件能力做非真机闭环，不开放公开入口：

- 隐藏媒体后端同步 smoke：用 mock 音频、mock 视频、timeLetter payload 走 `/archive/items`，验证 POST 持久化、GET 拉取、字段回传和隐私字段过滤。
- 音视频 mock upload 状态闭环：iOS 从 `/archive/media/upload-intent` 获取 mock 上传合同，并在本地详情里覆盖 `localOnly/pending/uploaded/failed` 的展示与重试入口。
- 时间信件本地生命周期：覆盖草稿编辑、草稿删除、草稿封存、已封存详情状态；真实投递、通知和收件人规则仍等待产品决策。

## 隐藏媒体后端同步 smoke

脚本：

```bash
RUN_ID=20260619-hidden-media-sync Scripts/QA/prd-stitch-ui/run-backend-hidden-media-sync-smoke.sh
```

范围：

- `/archive/media/upload-intent`：为 mock audio/video 生成 `uploadIntentId`、`objectKey`、`uploadURL`、`expiresAt`。
- `/archive/items`：写入 audio、video、timeLetter 三类隐藏候选档案。
- `GET /archive/items/{userId}`：回读并验证 `uploadStatus`、`objectKey`、`transcriptText`、`thumbnailObjectKey`、`deliveryState`、`deliveryPolicy`。
- 隐私过滤：确认 `localPath`、`rawAudioURL`、`rawVideoURL`、`rawTranscript`、`thumbnailPath`、`localThumbnailPath` 不作为后端可见合同回传。

该 smoke 需要部署后端 URL 和 API token，可从 `DreamJourneyBackend/private/deployed-backend-access.md` 读取；token 不写入报告。

## 音视频 mock upload 状态闭环

iOS 侧保持隐藏入口，不进入默认发布态。隐藏 QA 模式下：

- 档案详情对 audio/video 显示媒体同步按钮。
- `localOnly` 可触发 upload intent。
- 请求中显示 `上传中...`。
- 成功后本地状态落为 `uploaded`，详情显示 `已上传`。
- 失败后本地状态落为 `failed`，详情显示 `上传失败`、`上传错误`，按钮显示 `重新上传`。
- 当前不执行真实对象存储 PUT，只固定合同和 UI 状态机。

## 时间信件本地生命周期

隐藏 QA 模式下：

- 草稿可编辑，更新 `note` 和 `timeLetterStatus=draft`。
- 草稿可删除，本地 repository 移除对应 item。
- 草稿可封存，更新为 `deliveryState=sealed`、`timeLetterStatus=sealed`、`deliveryPolicy=pending_product_decision`。
- 已封存详情展示封存状态，不做真实投递、通知、收件人规则。

## Release Gate

已接入：

- 静态 guard：`archive-hidden-media-backend-upload-lifecycle-check.swift`
- 隐藏 shell UIQA：`run-archive-hidden-shell-smoke.sh`
- 部署后端 smoke：`run-backend-hidden-media-sync-smoke.sh`
- Release regression 开关：`RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE=1`

建议后续在涉及 archive schema、media upload、timeLetter metadata 或隐藏入口时运行：

```bash
RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE=1 \
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 暂不覆盖

- 真实麦克风录音质量、权限拒绝/恢复。
- 真实相册/视频选择、视频压缩和缩略图生成质量。
- 真实对象存储 PUT、签名 URL 过期重试。
- 时间信件投递、通知、收件人规则。
- 隐藏功能公开发布决策。
