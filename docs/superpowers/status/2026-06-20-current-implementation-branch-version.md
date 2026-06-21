# DreamJourney 最新工程实现内容与分支版本快照

Date: 2026-06-20

Scope: iOS 工程 `DreamJourney_dev`、后端工程 `DreamJourneyBackend`、当前 PRD/UI 适配、声音复刻、数字人实时面板、TTS 口型时间线与本地缓存合同。

## 依据

- Product: 最新 PRD `《寻梦环游 产品PRD V1.0》(1).md` 以及后续明确的产品决策。
- Visual: 当前 Stitch 画布与 `htmlCode`；MCP screenshot 只作为辅助复核，不能单独作为最终视觉依据。
- iOS repo: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Backend repo: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`
- 当前文档只记录仓库版本与代码实现状态；服务器实际运行版本需要通过线上 smoke 或服务器提交号另行确认。

## Repository Snapshot

| Repo | Branch | Latest Commit | Remote Relation | Notes |
| --- | --- | --- | --- | --- |
| `DreamJourney_dev` | `feature/prd-stitch-ui-adaptation` | `2cc3dd5 feat: cache memoir tts lipsync metadata` | 与 `origin/feature/prd-stitch-ui-adaptation` 对齐 | 当前 UI/PRD 适配主分支，最近 5 个提交已推送。 |
| `DreamJourneyBackend` | `main` | `15efa23 feat: add voice synthesis viseme timeline contract` | 与 `origin/main` 对齐 | 后端主线包含声音复刻训练、TTS 合成、viseme timeline 合同。 |

当前 iOS 工作区仍有大量 `tmp/visual-qa/prd-stitch-ui/` 下未跟踪 QA 临时产物，它们没有纳入本次提交，也不属于版本快照内容。

## 最新 iOS 提交

| Commit | Message | 实现含义 |
| --- | --- | --- |
| `2cc3dd5` | `feat: cache memoir tts lipsync metadata` | 回忆录 TTS 合成成功后保存本地音频与 metadata，缓存 `audioFileURL`、`voiceProfileId`、`textHash`、`audioFormat`、`visemeTimeline`、`createdAt`、`providerMode`；新增 cache contract guard 并接入 release regression。 |
| `3769a4c` | `test: add digital human tts viseme gate` | 增加数字人 TTS/viseme 组合 gate：mock 后端 `/voice/synthesis` 返回 timeline，iOS UIQA 喂给数字人面板，同时验证缺失 timeline 时回退播放器音量 metering。 |
| `a827ff8` | `feat: parse voice synthesis viseme timeline` | iOS `DreamJourneyBackendClient` 解析后端 TTS 响应里的 `visemeTimeline`，并生成 `DigitalHumanPlaybackEvent.visemeTimeline`。 |
| `5fd9fd1` | `feat: add digital human lipsync timeline contract` | 定义 `DigitalHumanLipSyncFrame`、`DigitalHumanLipSyncTimeline`、`DigitalHumanPlaybackEvent`，Web bridge 支持 provider timeline 驱动口型。 |
| `adac89a` | `feat: drive digital human panel with tts metering` | 数字人面板接真实播放器音量 metering，支持“说话中”嘴型/动态素材随音频强弱变化。 |
| `a4c461a` | `fix: render real digital human asset in echo panel` | Echo 隐藏数字人面板改为渲染真实数字人素材，不再使用纯模拟数字人。 |
| `fcde7be` | `feat: add hidden digital human live echo panel` | 在 Echo 中加入隐藏数字人实时面板，默认公开版本不暴露。 |
| `c914aa9` | `chore: solidify local device signing override` | 固化本机真机构建签名覆盖策略，减少手动重复指定 Team/Bundle ID。 |
| `563c72d` | `fix: reset failed voice clone speaker id` | 声音复刻失败后清理失败 speaker id，避免后续一直使用坏状态。 |
| `18c1049` | `style: refine voice clone profile UI` | 优化声音复刻 UI，去掉不必要展示，只保留必要信息。 |
| `2eacb4b` | `feat: expose voice clone foundation` | 声音复刻基础入口公开，不再默认隐藏。 |

## 最新后端提交

| Commit | Message | 实现含义 |
| --- | --- | --- |
| `15efa23` | `feat: add voice synthesis viseme timeline contract` | 后端 `/voice/synthesis` 支持可选 `visemeTimeline`，runtime 暴露 lip-sync timeline 能力，测试固定 mock provider 返回 timeline。 |
| `b56b10b` | `fix: support volcengine console speaker clone mode` | 支持火山控制台 `S_` 音色模式，修正声音复刻配置与 runtime 暴露。 |
| `ad9c5b4` | `fix: pass custom voice id to volcengine clone training` | 训练接口按火山要求传递自定义音色 id，区分后付费自定义音色模式。 |
| `1938493` | `fix: persist volcengine voice clone log ids` | 后端保存火山 provider log id，便于失败后给平台客服查日志。 |
| `304a2c0` | `fix: separate voice clone training and tts keys` | 分离声音复刻训练 key 与复刻音色 TTS 合成 key，避免混用。 |
| `aa0f658` | `fix: align voice clone provider with volcengine guide` | 按火山文档继续对齐声音复刻 provider 参数。 |
| `02189a2` | `feat: proxy voice clone tts synthesis` | TTS 合成迁到后端，iOS 不直连火山 TTS API。 |
| `0752b07` | `feat: proxy voice clone provider through backend` | 声音复刻训练/查询经后端代理，iOS 不持有火山密钥。 |

## 当前公开 MVP 能力

公开默认可见主链路：

```text
登录 -> 记忆档案 -> 文字/照片封存 -> 回响 -> 我的
```

当前已实现/已收敛的公开能力：

- 登录入口与当前认证回调。
- 记忆档案首页、时间胶囊列表、照片/文字档案详情。
- 照片导入、本地文件保存、详情页图片展示与本地路径恢复。
- 档案后端同步失败恢复、AI 分析失败与重试入口。
- 后端 `/archive/image-analysis` provider 不可用时返回可持久化的失败/重试合同。
- Echo 基础语音交互状态机：聆听中、思考中、等待回信、已回信、失败/重试。
- Echo 等待回信本地持久化、本地通知调度合同、后端 delayed reply 合同。
- 个人资料基础字段、保存状态、心境追踪/关怀信号空态、失败态、过期态与重试逻辑。
- 声音复刻基础入口已开放，包括训练状态、失败状态、provider log id 支持和后端代理链路。

## 当前隐藏 / QA-only 能力

以下能力已有壳层、合同、数据结构或 smoke，但默认不作为公开 MVP 完成态宣称：

- 数字人实时面板：Echo 内隐藏入口；真实素材可渲染；播放器 metering 与 provider `visemeTimeline` 两条口型驱动链路已具备；默认不公开。
- 语音档案：非真机数据模型、上传 intent、转写状态、分析状态、详情空态/失败态/重试态。
- 视频档案：mock 视频列表/详情、缩略图占位、文件大小、上传状态、分析失败/重试；不做真实视频选择/压缩验收。
- 时间信件：草稿、删除、封存、本地生命周期、后端 metadata 合同；投递策略仍是 `not_delivering` / `waiting_product_decision`。
- 家庭/数字人合同：`digitalHumanMode`、`familyPersonaContractVersion`、family hidden UIQA consumer；不公开家人管理入口。
- 密码修改、账号注销、医生联系/干预、数字继承生命周期：仅保留合同或安全壳层，默认不公开。

## 声音复刻与 TTS 当前实现

### iOS 侧

- iOS 不直连火山声音复刻训练或 TTS API。
- `VoiceCloneService` / `DreamJourneyBackendClient` 经后端访问声音复刻相关能力。
- 声音复刻基础 UI 已公开，但训练成功依赖后端 provider 配置、火山资源模式和真实样本质量。
- `MemoirTTSService` 当前通过后端 `/voice/synthesis` 合成回忆录朗读。
- TTS 成功后本地保存音频，并额外缓存 timeline metadata：

```text
ApplicationSupport/memoir_audio/{memoirId}.{audioFormat}
ApplicationSupport/memoir_tts_cache/{memoirId}.json
```

缓存 metadata 字段：

```text
audioFileURL
voiceProfileId
textHash
audioFormat
visemeTimeline
createdAt
providerMode
```

### 后端侧

- 训练/查询 key 与复刻音色 TTS key 已分离。
- provider log id 已回传/持久化，便于查火山侧失败原因。
- `/voice/synthesis` 支持返回音频与可选 `visemeTimeline`。
- `/config/runtime` 暴露 voice/lip-sync 能力，供 iOS 判断 provider timeline 是否可用。

## 数字人实时语音与口型同步当前进展

当前做到：

- Echo 中已有隐藏数字人实时面板。
- 使用真实数字人素材渲染。
- 口型同步抽象层已定义：
  - `DigitalHumanLipSyncFrame`
  - `DigitalHumanLipSyncTimeline`
  - `DigitalHumanPlaybackEvent`
- 支持两种已实现输入源：
  - `avAudioPlayerMetering`
  - `providerVisemeTimeline`
- Web bridge 支持：
  - `setMouthLevel(...)`
  - `setVisemeTimeline(...)`
- QA gate 覆盖：
  - provider timeline 有 frames 时口型按时间戳变化。
  - provider timeline 缺失时回退播放器音量 metering。

尚未宣称完成：

- provider 级真实 phoneme/viseme 时间戳质量验收。
- 真机真实 TTS 播放时的数字人口型同步体验验收。
- 数字人公开入口与产品交互策略。

## 当前验证入口

基础静态与合同检查：

```bash
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/memoir-tts-cache-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-tts-viseme-gate-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

公开主链路回归：

```bash
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

数字人 TTS/viseme 可选 gate：

```bash
RUN_DIGITAL_HUMAN_TTS_VISEME_GATE=1 \
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

后端 voice synthesis viseme smoke：

```bash
tmp/visual-qa/prd-stitch-ui/run-backend-voice-synthesis-viseme-smoke.sh
```

## 最近一次本地验证记录

本地 iOS 侧最新缓存合同开发后已验证：

- `swift tmp/visual-qa/prd-stitch-ui/memoir-tts-cache-contract-check.swift` passed
- `swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift` passed
- `git diff --check` passed
- iOS Debug simulator build passed

构建日志：

```text
tmp/visual-qa/prd-stitch-ui/memoir-tts-cache-build/build.log
```

## 当前剩余关键缺口

### 需要真机/外部环境验收

- 真机麦克风、相册、语音识别权限、前后台切换、播放路由、截图和日志。
- 声音复刻真实训练成功率、样本质量、失败恢复和火山资源计费模式。
- 复刻音色 TTS 真实音质、延迟、稳定性。
- 数字人真实 TTS 播放下的口型同步体验。
- APNs provider delivery 与真机通知到达证据。

### 需要产品/合规决策

- 数字人是否公开、入口位置、默认模式和素材授权。
- 时间信件真实投递策略、收件人规则、取消/修改规则。
- 家庭成员权限、邀请、隐私文案和管理模型。
- 声音复刻授权文案、删除/禁用策略和用户计费边界。
- 医生联系/关怀干预责任边界。
- 账号注销、数据导出、冷静期和不可逆删除策略。

## 当前建议的下一步

短线继续做非真机闭环：

1. 把 `MemoirTTSService.getCachedSynthesis(for:)` 接到数字人播放链路，优先使用缓存里的 `visemeTimeline` 驱动口型。
2. provider timeline 缺失时继续回退到播放器音量 metering。
3. 增加一个“不请求真实 provider”的 UIQA：构造本地缓存音频 + timeline，打开数字人面板并验证 mouth shape 变化。

中线进入真机验收：

1. 声音复刻训练真实样本采集。
2. 后端训练状态与 provider log id 收集。
3. 复刻音色 TTS 合成与播放。
4. 数字人面板在真实 TTS 播放中的口型同步截图/日志。

## 当前结论

截至 `2026-06-20`，当前工程已经从“公开 MVP + hidden 合同壳层”推进到“声音复刻公开基础能力 + 数字人隐藏实时面板 + TTS 口型时间线合同 + 本地 TTS 缓存合同”的状态。

公开 MVP 仍应保持克制，不默认暴露未验收的 hidden 功能；但声音复刻、TTS 后端代理、数字人 lip-sync 的底层合同已经具备继续做真机验收和产品化 polish 的基础。
