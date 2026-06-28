# DreamJourney 当前实现、版本与分支快照

Date: 2026-06-19

Scope: iOS 工程 `DreamJourney_dev`、后端工程 `DreamJourneyBackend`、当前 PRD/UI 适配与后端合同状态。

Source of truth:

- Product: 最新 PRD `《寻梦环游 产品PRD V1.0》(1).md` 及后续明确的产品决策。
- Visual: 当前 Stitch 画布与 `htmlCode`。MCP screenshot 只作为辅助复核，不能单独作为最终视觉依据。
- iOS: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Backend: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`
- Status docs:
  - `docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
  - `docs/superpowers/status/2026-06-17-release-feature-matrix.md`

## Repository Snapshot

This snapshot captures the implementation baseline before adding this documentation-only status file.

| Repo | Branch | Implementation baseline | Remote relation at capture | Notes |
| --- | --- | --- | --- | --- |
| `DreamJourney_dev` | `feature/prd-stitch-ui-adaptation` | `2bfd99da9aef080363d1339cf44c01e1e429cd82` | ahead of `origin/feature/prd-stitch-ui-adaptation` by 26 commits | 当前 UI/PRD 适配主分支；本地已提交，未推送的提交较多。 |
| `DreamJourneyBackend` | `main` | `03fa5fe93550a40d0a505465afaee0e6ce8f0a94` | matches `origin/main` | 后端本地 `main` 与远端一致。 |

## Latest iOS Commits

| Commit | Message | Interpretation |
| --- | --- | --- |
| `2bfd99d` | `docs: sync prd coverage and release matrices` | 同步 PRD 覆盖矩阵和发布功能矩阵，重新标注公开 MVP、hidden、外部验收和产品决策。 |
| `ba12d48` | `test: define production voice sdk readiness boundary` | 固定生产语音 SDK readiness 边界，避免把 mock ASR/TTS、后端 token fallback 或 SDK 初始化误判为生产闭环完成。 |
| `f798801` | `test: strengthen true-device acceptance evidence package` | 强化真机验收证据包格式，包括日志、截图、前后台、播放路由和人工 QA 记录要求。 |
| `67844c8` | `feat: strengthen hidden video archive readiness` | 完善隐藏视频档案壳层：列表/详情、缩略图占位、文件大小、上传状态、分析失败/重试状态。 |
| `a6f820b` | `feat: guard time letter delivery policy shell` | 固定时间信件草稿、封存、暂不投递、等待产品决策的边界。 |
| `9269113` | `feat: add hidden family voice UIQA consumer smoke` | 隐藏 UIQA 消费 family/voice 后端字段，但默认 release 不暴露入口。 |
| `2285221` | `feat: consume family voice backend contracts on iOS` | iOS backend-ready client 解析 `digitalHumanMode`、`familyPersonaContractVersion`、`voiceProfileId`、`sampleStatus`。 |
| `bcdce3e` | `test: add family voice deployed contract smoke` | 增加线上 family/voice 合同 smoke。 |
| `da1d46b` | `test: guard family digital human hidden contract` | 固定 family digital-human hidden 合同。 |
| `6521c1c` | `test: guard voice clone backend contract` | 固定声音克隆壳层后端合同。 |
| `59d7a7f` | `feat: guard archive media provider switch contract` | 固定媒体上传 provider 切换合同。 |
| `0eccc8f` | `feat: surface hidden media runtime capability` | iOS 消费 runtime hidden media capability，避免 UI 只靠 mock 状态判断。 |

## Latest Backend Commits

| Commit | Message | Interpretation |
| --- | --- | --- |
| `03fa5fe` | `feat: add family digital human contract` | 增加 family digital-human 三态合同，支持 `sunlight`、`star`、`silent`。 |
| `da3093f` | `feat: add voice clone profile contract` | 增加 voice profile 生命周期合同。 |
| `0af7f6a` | `feat: expose archive media provider switch contract` | `/config/runtime` 暴露媒体上传 provider 切换能力。 |
| `8b2113b` | `feat: add archive time letter lifecycle contract` | 后端支持 time letter metadata 生命周期合同。 |
| `de85da7` | `test: pin time letter archive shell contract` | 固定时间信件壳层合同测试。 |
| `5ff93ce` | `feat: add archive image analysis provider contract` | 增加图像分析 provider 合同。 |
| `e7bfe13` | `feat: return retryable archive image analysis failures` | provider 不可用时返回可持久化、可重试的分析失败合同。 |
| `782a92b` | `feat: add archive analysis insight contract` | 增加档案分析结构化线索合同。 |

## Current Public MVP Implementation

公开 MVP 默认可见范围：

- `记忆档案`
- `回响`
- `我的`
- 登录入口与当前认证回调
- 文字档案创建
- 照片档案创建
- 档案文字/照片本地保存与后端同步失败恢复
- voice-first Echo
- Echo 十轮/自适应等待回信状态机
- 本地等待回信状态持久化
- 本地通知调度合同
- 线上后端 delayed reply 持久化与 dispatch-due ready-for-provider 合同
- 个人资料字段编辑：昵称、性别、地区、手机号展示
- 个人资料保存状态：保存中、成功、失败、网络异常、非法输入
- 法律法规页
- 退出登录
- 心境追踪/长辈关怀聚合展示，包括 loading、empty、stale、failed、retry
- 关怀升级公开占位：只展示准备中，不执行联系、上传或医疗干预

默认 public feature flags 必须保持：

```text
careDashboard
personaSettings
profileSettings
legalCenter
```

## Current Hidden / QA-only Implementation

以下能力已有壳层、合同或 QA smoke，但默认不公开：

- 语音档案：本地生命周期、后端 media 合同、上传 intent、转写状态、分析状态、Echo 上下文规则、真机验收证据包。
- 视频档案：mock 列表/详情、缩略图占位、文件大小、上传状态、分析失败/重试、runtime media capability、hidden media combo gate。
- 时间信件：本地草稿、删除、封存、已封存详情、后端 metadata 生命周期、明确 `not_delivering` / `waiting_product_decision`。
- 家人管理：family digital-human 后端合同、iOS typed consumer、hidden UIQA consumer。
- 声音克隆：`voiceProfileId`、样本状态、授权确认、禁用/删除合同，默认隐藏。
- 密码修改：iOS client 和后端 `/auth/password` 合同已具备，但 UI 默认隐藏，等待安全审查和公开发布决策。
- 账号注销：hidden safety shell only，不执行真实删除。
- 医生联系/关怀干预：hidden safety shell only，不执行真实联系、提交或医疗干预。
- 阳光/星辰/静默模式管理：hidden QA context only，不公开生命周期切换。
- 数字继承生命周期：hidden boundary only，等待产品/法律策略。

Hidden QA launch arguments:

```text
DJEnableArchiveHiddenBranches
DJEnableProfileHiddenBranches
DJShowVoiceSDKReadinessPreview
```

## Backend Deployment / Runtime Status

当前后端本地 `main` 与 `origin/main` 对齐，不存在本地后端未提交或未推送变更。

线上健康检查：

```text
https://dreamjourney-api.liftora.cn/health -> status=ok, environment=production, store=postgres
```

最新线上 family/voice 合同 smoke：

- Run ID: `20260619-deployed-family-voice-contract-check`
- Report: `tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke/20260619-deployed-family-voice-contract-check/report.md`
- Result JSON: `tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke/20260619-deployed-family-voice-contract-check/backend-family-voice-contract-smoke-result.json`
- Result: passed

已验证的线上行为：

- `/config/runtime` 返回 `archive.storageProvider=mockObjectStorage`
- `/config/runtime` 返回 `archive.providerMode=mock`
- `/config/runtime` 返回 `archive.providerSwitchContractVersion=1`
- family `sunlight/阳光`、`star/星辰`、`silent/静默` 可创建、持久化、拉取
- 非法 `digitalHumanMode=storm` 被拒绝
- voice profile 生命周期可走通：`pending -> disabled -> deleted`
- hidden family/voice 默认 `defaultReleaseVisible=false`

结论：截至本快照，后端不需要因为当前 iOS 文档同步任务重新部署。

## Validation Gates Currently Available

核心静态/合同检查：

```bash
swift Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

公开主链路回归：

```bash
Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

后端 family/voice 线上合同 smoke：

```bash
RUN_ID=20260619-deployed-family-voice-contract-check Scripts/QA/prd-stitch-ui/run-backend-family-voice-contract-smoke.sh
```

发布态矩阵要求：

- hidden PRD 功能默认不可见。
- 公开 MVP 不应暴露录音上传、视频上传、时间信件、家人管理、声音克隆、修改密码、注销账户、医生联系执行、数字继承生命周期。
- 每次 Stitch UI 或档案/回响/关怀逻辑更新后，应优先跑 release regression 与 Archive -> Echo smoke。

## External Acceptance Still Open

这些不是当前代码失败，而是外部验收门：

- 真机完整验收：麦克风、相册、语音识别权限、前后台切换、播放路由、截图和日志。
- 生产语音 SDK 质量验收：真实 ASR/TTS 对话质量、错误恢复、播放路由。
- APNs provider delivery：当前只到 ready-for-provider 合同，真机通知到达证据未完成。
- Paid Apple Developer Team / Push capability：如果要验 APNs，需要对应开发者能力。
- App Store / TestFlight 分发签名链路。
- 真实对象存储 provider：如果音频/视频公开，需要真实上传 provider、压缩、大小限制和隐私策略。

## Product / Compliance Decisions Still Open

- 时间信件投递时间、取消/修改、收件人和通知语义。
- 家庭邀请、权限、成员角色、隐私文案。
- 声音克隆授权、样本质量、禁用/删除和生产 provider 策略。
- 医生联系或关怀干预的责任边界、紧急提示、后端提交合同。
- 账号注销的数据导出、冷静期、最终确认和不可逆删除策略。
- 数字继承触发条件、证明材料、家属同意、审计和恢复机制。

## Current Interpretation

当前 iOS 工程是一个已大量实现、模拟器与合同层持续验证的 PRD/UI 适配分支。

公开 MVP 主链路可概括为：

```text
登录 -> 记忆档案 -> 文字/照片封存 -> 回响 -> 心境追踪 / 长辈关怀 -> 我的
```

hidden 功能已进入“合同可验、壳层可验、默认不公开”的状态，但不应被描述为生产完成。

当前离“可真机完整验收”的主要差距在外部验收和生产能力，而不是公开 MVP 主链路的基础结构：

- 需要补真机证据包。
- 需要生产语音 SDK 质量验收。
- 需要 APNs provider delivery 和真机通知到达证据。
- 需要产品/合规决策后，才能把 hidden 功能转公开。
