# Release-State Overview QA

Date: 2026-06-17

Scope: default logged-in release surface with UIQA seed data.

## Launch Mode

The app was clean-installed and launched with only:

```text
DJSeedPendingArchiveAnalysis
```

No hidden-branch launch arguments were used:

- No `DJEnableArchiveHiddenBranches`
- No `DJEnableProfileHiddenBranches`

## Expected Public Matrix

Visible by default:

- Tabs: `记忆档案`, `回响`, `我的`
- Archive: photo/text archive flow, existing archive item, time capsule list label
- Echo: voice-first `开始语音`
- Profile: care dashboard, `个人资料设置`, `法律法规`, `退出登录`
- Profile settings: avatar display, nickname editing, masked phone display, save action
- Legal center: AI assistance, mental-health boundary, privacy/data, digital-human ethics, emergency guidance

Hidden by default:

- Archive audio upload
- Time letters
- Persona settings / knowledge base route
- Video archive input
- Echo text input
- Echo image input
- Family management
- Account deletion
- Doctor contact / `立即通话`
- Password change

## Screenshots

```text
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/01-echo-default.jpg
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/02-archive-default.jpg
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/03-archive-create-sheet-default.jpg
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/04-profile-default.jpg
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/05-profile-settings-default.jpg
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/06-profile-legal-default.jpg
```

## Runtime Snapshot Results

Echo:

- Visible: `开始语音`, `记忆档案`, `回响`, `我的`.
- Hidden: text/image echo input.

Archive:

- Visible: `相册影像`, `封存新记忆`, `文字、图片`, `时间胶囊`, `按时间排序`.
- Hidden: `语音档案`, `人格设定`, time-letter creation.

Archive creation sheet:

- Visible: `添加文字描述`, `选择照片`.
- Hidden: audio creation, time-letter creation, video input.

Profile:

- Visible: `心境追踪`, `李医生`, `个人资料设置`, `法律法规`, `退出登录`.
- Hidden: `立即通话`, `家人管理`, `注销账户`.

Profile settings:

- Visible: `头像`, `昵称`, `手机号`, `保存`.
- Hidden: password change.

Legal center:

- Visible: `AI 辅助说明`, `心理支持边界`, `隐私与数据`, `数字人与伦理`, `紧急情况`.
- Includes: `不是医疗诊断`, `不展示聊天原文`, emergency guidance copy.

## Finding

The release-state entry matrix is coherent for the current MVP scope. The remaining non-public flows are hidden by default and still available for internal QA through explicit feature flags or hidden-branch launch arguments when needed.
