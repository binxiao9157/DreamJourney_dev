# DreamJourney V4 Release Feature Matrix

日期：2026-07-16
分支：`feature/prd-stitch-ui-adaptation`
适用范围：V4 Closed Pilot
Authority：服务器 `ReleasePolicySnapshot`；iOS 本地 flag 仅承担 UI 组合和 Debug/UIQA 临时验证，不是发布授权。

## V4 Closed Pilot Baseline

当前公开基线只保留 Owner 核心：三 Tab 壳层、文字/照片档案、普通回响、个人资料、法律中心、账号注销与退出登录。家庭、关怀、时间信件、人格、音色复刻、数字人、音视频媒体和远端效果均保留实现，但在新的产品/Privacy/Provider Gate 关闭前默认隐藏。

旧 PRD 曾经批准公开的功能不自动继承到 V4。代码存在、Provider 已配置、真机曾跑通或 QA 截图通过，都不能单独把功能变成公开能力。

| Feature | Public status | Internal status | Decision gate | External gate | Route policy |
| --- | --- | --- | --- | --- | --- |
| `echoTextInput` | public-core | implemented | Closed Pilot Owner core | G0/G1 | server allow；scoped cache；captured route/request Gate；线上 command observe allow |
| `echoImageInput` | hidden | shell/contract | product scope | G1/G2 | Release deny；未提供公开入口 |
| `timeLetters` | hidden | lifecycle + backend delivery contract | product/privacy approval | G2/G4 | Release deny；`DJEnableArchiveHiddenBranches` only；captured command 保持 deny |
| `profileSettings` | public-core | implemented | Closed Pilot Owner core | G0/G1 | server allow；scoped cache；captured route/request Gate；线上 command observe allow |
| `personaSettings` | hidden | local knowledge/persona shell | product/privacy approval | G1/G4 | Release deny；archive QA branch only |
| `archiveAudioUpload` | hidden | recorder/detail/upload contracts | media release decision | G2/G3/G4 | Release deny；mock/QA entry only |
| `archiveVideoUpload` | hidden | detail/upload-intent shell | media release decision | G2/G3/G4 | Release deny；mock/QA entry only |
| `archiveRemoteFetch` | hidden | backend-ready client | data authority rollout | G1/G2 | Release deny；`DJEnableArchiveRemoteFetch` in Debug/UIQA only |
| `archiveLocalAnalysis` | hidden | local/failed-retry shell | analysis disclosure decision | G1/G4 | Release deny；QA only |
| `familyManagement` | hidden | phone invite + relationship contracts | family/privacy approval | G1/G2/G4 | Release deny；`DJEnableProfileHiddenBranches` only；线上 command observeDeny 已验证 |
| `familySpace` | hidden | persona switch + family context contracts | family authorization approval | G1/G2/G4 | Release deny；`DJEnableProfileHiddenBranches` only |
| `legalCenter` | public-core | implemented | Closed Pilot Owner core | G0/G1 | server allow；read-only route |
| `accountDeletion` | public-core | soft-delete/restore contract | Closed Pilot safety requirement | G1/G2 | server allow；destructive confirmation remains mandatory |
| `accountPasswordChange` | hidden | UI/backend-ready shell | auth security approval | G1/G2 | Release deny；profile QA branch only |
| `careDashboard` | hidden | snapshot states + retry + message provider | care product/privacy approval | G1/G2/G4 | Release deny；profile QA branch only |
| `careDoctorContact` | hidden | non-executing draft shell | clinical/legal approval | G1/G2/G4 | Release deny；no call/message/backend effect |
| `voiceCloneShell` | hidden | training/query/synthesis contracts | consent/provider approval | G2/G3/G4 | Release deny；`DJEnableProfileHiddenBranches` only；no mobile Provider key |
| `digitalHumanLivePanel` | hidden | Tencent session/audio-drive implementation | product/provider approval | G2/G3/G4 | Release deny；explicit Debug/UIQA launch arg only |

> Runtime readiness 不再由上述实现状态或单一 Provider bool 推断。`WI-S0-06-05` 起，扩展能力统一按 `implemented / enabled / providerReady / releaseVisible / externalVerified` 五轴解释；只有完整新合同且五轴同时满足时，普通发布态入口才可视为可用。旧 alias、mock、text-only、缺失或过期外部证据均按 unknown/deny。

## QA-only Overrides

以下入口只用于合成账号、mock 数据或明确的内部 Provider 验证。Release 真机不能通过参数或旧 `UserDefaults` 值开启：

```text
DJEnableArchiveHiddenBranches
DJEnableProfileHiddenBranches
DJEnableArchiveRemoteFetch
DJShowDigitalHumanLivePanel
DJRunDigitalHumanLivePanelSmoke
DJRunTencentDigitalHumanTextDriveSmoke
DJRunTencentDigitalHumanPCMDriveSmoke
DJRunTencentDigitalHumanBackendPCMDriveSmoke
DJRunTencentBackendPCMDriveMockSmoke
```

约束：

1. override 只在 `DEBUG` 或 `UI_QA_SIMULATOR` 编译条件下生效。
2. Future/Beta flags 不写入持久化发布 Authority，进程退出即失效。
3. 旧 schema 的持久化 flag 在升级后重置；不能迁移为 server allow。
4. QA 入口不能绕过后端 AuthZ、ReleasePolicy、Provider credential 或 command deny。
5. 当前 QA 只使用合成数据；真实用户正文、媒体和凭据不得进入证据包。

## Gate Interpretation

- `G0`：代码、合同、静态检查、构建和回归证据。
- `G1`：安全、Privacy、数据边界和人工评审。
- `G2`：真实部署、数据库、缓存或服务端 effect 证据。
- `G3`：Provider、凭据、配额、质量或真机外部证据。
- `G4`：产品、法务、合规或运营批准。

Feature 只有服务器 `releaseVisible=true`、客户端 fresh scoped policy 允许、route/command gate 允许、AuthZ 允许且 Provider ready 时才可产生真实效果。任一轴缺失都应隐藏、只读或明确失败。

## Release Regression

本矩阵变更后至少运行：

```bash
swift Scripts/QA/prd-stitch-ui/future-beta-default-deny-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## Promotion Rule

隐藏功能升级为公开功能时，必须同时更新服务器 policy、iOS scoped cache/route gate、backend command gate、本矩阵和对应 release regression。只改本地 `defaultEnabled`、readiness 文案或截图均视为无效发布变更。
