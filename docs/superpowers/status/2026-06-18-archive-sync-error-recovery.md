# Archive Sync Error Recovery

Date: 2026-06-18

Scope: 公开 MVP 仅文字和照片。

## Status

档案文字 / 照片同步失败恢复已接入本地持久化合同。

## Behavior

- 新建或更新公开文字 / 照片档案时，先保存本地，再标记为 `pending`。
- 后端写入成功后，本地 metadata 标记为 `synced`。
- 后端写入失败后，本地档案不丢失，metadata 标记为 `failed`，并保存经过截断的错误说明。
- 开启 `DJFeature.archiveRemoteFetch` 的后端验收路径中，下次远端刷新前自动重试未同步的公开文字 / 照片。
- 列表和详情页显示云端状态：`待同步云端`、`云端已同步`、`同步失败，可稍后重试`。
- 远端不可用时，页面说明为 `远端暂不可用，已保留本地档案，可稍后自动重试`。

## Release Boundary

- 隐藏媒体不默认同步：语音档案、时间信件、视频档案仍按隐藏候选/QA-only 分支管理。
- 这个闭环不改变 Stitch 主视觉，不开放隐藏入口。
- 真机照片权限、媒体上传策略和家庭可见性策略仍按 PRD 后续决策处理。

## Verification

- Static guard: `tmp/visual-qa/prd-stitch-ui/archive-sync-error-recovery-check.swift`
- Release regression: `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- Package guard: `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`

