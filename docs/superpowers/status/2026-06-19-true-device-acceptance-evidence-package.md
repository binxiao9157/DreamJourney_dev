# 真机验收证据包强化

日期：2026-06-19

## 本轮目标

把公开 MVP 真机验收从松散 checklist 收敛成固定证据包。当前仍不声明真机验收已完成；本轮只固定证据格式、脚本产物和 release QA 静态门禁。

覆盖范围：

- 麦克风权限允许、拒绝和恢复。
- 相册权限、照片导入、档案沉淀和回响上下文。
- 语音识别权限与降级反馈。
- 前后台切换后的回响状态、档案状态和本地媒体文件恢复。
- 播放路由，包括回响 TTS 和语音档案详情播放。
- 截图命名与放置目录。
- 日志文件与人工 QA notes。

## 回响语音证据包

入口：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-voice-true-device-preflight \
tmp/visual-qa/prd-stitch-ui/run-true-device-voice-preflight.sh
```

脚本会在 `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/<run-id>/` 生成：

- `report.md`
- `device-build.log`
- `xcodebuild-destinations.txt`
- `devicectl-devices.txt`
- `xctrace-devices.txt`
- `evidence-manifest.md`
- `manual-qa-notes.md`
- `console-output.log`

必须补齐的截图：

- `01-photo-permission-allow.png`
- `02-photo-created-archive.png`
- `03-photo-echo-context.png`
- `04-microphone-permission-allow.png`
- `05-speech-permission-allow.png`
- `06-echo-listening.png`
- `07-echo-tts-playback.png`
- `08-background-before.png`
- `09-foreground-restored.png`

## 语音档案证据包

入口：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-archive-audio-true-device-preflight \
tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh
```

脚本会在同类 run 目录生成：

- `report.md`
- `device-build.log`
- `xcodebuild-destinations.txt`
- `devicectl-devices.txt`
- `xctrace-devices.txt`
- `evidence-manifest.md`
- `audio-quality-notes.md`
- `playback-route-notes.md`
- `background-foreground-notes.md`

必须补齐的截图：

- `01-audio-permission-allow.png`
- `02-audio-permission-deny.png`
- `03-audio-permission-recover.png`
- `04-audio-created.png`
- `05-audio-detail-playback.png`
- `06-audio-after-background-foreground.png`

## 验收边界

这个证据包只证明真机验收的证据格式已经固定，不证明真机验收完成。只有当真实设备上补齐截图、日志和人工 notes，并确认麦克风、相册、语音识别、前后台、播放路由都通过后，才能把对应真机验收项标为通过。

生产语音 SDK 质量、APNs provider delivery 和真机通知到达仍是独立验收项。

## 门禁

新增静态检查：

```bash
swift tmp/visual-qa/prd-stitch-ui/true-device-acceptance-evidence-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

该检查已接入 release regression 和 release QA package，防止后续脚本改动把固定证据包格式删掉。
