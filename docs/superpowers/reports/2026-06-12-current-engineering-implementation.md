# DreamJourney 当前工程实现说明

日期：2026-06-12

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 1. 当前定位

DreamJourney 当前是一套面向阶段1路演和真机验证的 iOS App 工程，核心产品闭环是：

```text
AI 语音陪伴
  -> 对话与素材进入本机记忆
  -> 时空信箱 / 记忆档案馆沉淀家庭故事
  -> KBLite 形成家庭知识图谱
  -> 家族足迹呈现代际迁移和世界变大
  -> 亲友圈与关怀看板做脱敏共享
  -> 路演模式提供可控 seed/offline/主持路线
```

当前工程更接近“可真机路演验证版本”，不是完整生产 SaaS 或云端家庭协作版本。核心链路已实现并通过脚本和 iPhoneOS build gate；仍需要真机逐屏 smoke、数字人口型/声音验证、分享包隐私抽查和真实服务联调。

总体完成度判断：

| 维度 | 当前完成度 | 说明 |
| --- | ---: | --- |
| 阶段1产品目标工程完成度 | 84% | 主功能闭环、隐私模型、路演数据、真机前诊断、自动诊断证据落盘和构建验证已具备。 |
| 路演 Demo 可展示度 | 85% | 有 seed/offline/演示向导/一键下一步/清单/点亮预览、数字人脱敏诊断入口、readiness 诊断证据自动同步和播放日志证据收口设计；仍需真实播放、逐屏录屏和计时演练。 |
| 真实用户长期使用成熟度 | 60%-65% | 云端协作、真实亲友身份、长期趋势、服务端 guard 和生产级数据治理仍未完备。 |

## 2. 工程结构

主要工程入口：

- Xcode workspace：`DreamJourney.xcworkspace`
- App target：`DreamJourney`
- 主源码目录：`DreamJourney/Sources`
- 资源目录：`DreamJourney/Resources`
- 验证脚本目录：`Scripts`
- 工程报告目录：`docs/superpowers/reports`

主要源码分层：

| 目录 | 职责 |
| --- | --- |
| `Sources/App` | App / Auth / Tab coordinator。 |
| `Sources/Modules/Home` | 首页语音陪伴、数字人、消息流、路演路线入口。 |
| `Sources/Modules/TimeMailbox` | 时空信箱 UI。 |
| `Sources/Modules/MemoryArchive` | 记忆档案馆 UI。 |
| `Sources/Modules/Map` | 足迹地图、代际点亮、分享海报。 |
| `Sources/Modules/Family` | 亲友圈、快速入口。 |
| `Sources/Modules/CareDashboard` | 关怀看板 UI。 |
| `Sources/Modules/Knowledge` | KBLite 图谱、导出、同步预览。 |
| `Sources/Memoir` | 回忆录生成、TTS、声音复刻、DeepSeek 接入。 |
| `Sources/Services` | 对话引擎、记忆、隐私、安全、KBLite、seed、配置等核心服务。 |
| `Sources/Common` / `Sources/Theme` | 通用 UI、颜色、Toast。 |

## 3. App 导航与主要入口

底部主导航由 `TabCoordinator` 和 `WarmTabBarController` 承载，当前阶段1主页面包括：

| Tab | 主要页面 | 当前职责 |
| --- | --- | --- |
| 回忆 | `AIRecordingViewController` | AI 语音陪伴、数字人、照片上传、会话隐私选择、演示向导/清单入口。 |
| 足迹 | `MapFootprintViewController` | 家族足迹、代际点亮地图、统计、海报分享。 |
| 亲友 | `FamilyCircleViewController` | 家庭成员、关怀看板入口、足迹入口、快速操作。 |
| 信箱 | `TimeMailboxViewController` | 写信、延迟投递、本地信箱。 |
| 档案 | `MemoryArchiveViewController` | 文本/照片素材归档、隐私选择、照片分析。 |

路演模式下，首页 `RoadshowModeBannerView` 以“演示向导”形式显示本机素材/隐私边界、6 步完成进度和下一步名称，并提供“下一步/清单”双入口；首屏不再直接暴露“路演模式”“兜底”等工程词。“下一步”会根据 `RoadshowDemoRoute.nextIncompleteStep()` 直达下一阶段；全部完成后进入 `RoadshowDemoRouteViewController` 复盘和复制验收。

## 4. 核心数据流

### 4.1 语音对话主链路

相关文件：

- `Services/DialogEngineProtocol.swift`
- `Services/DialogEngineFactory.swift`
- `Services/DialogEngineManager.swift`
- `Services/DialogEngineModels.swift`
- `Services/MockDialogEngine.swift`
- `Services/HomeDialogPrivacyMetadataFactory.swift`
- `Modules/Home/AIRecordingViewController.swift`

当前支持两种对话引擎：

| 引擎 | 触发方式 | 用途 |
| --- | --- | --- |
| 实时 Dialog SDK | 默认真实模式 | 真机接火山实时对话 SDK。 |
| `MockDialogEngine` | `--use-mock-dialog-engine`、`DREAMJOURNEY_DIALOG_ENGINE=mock`、或 roadshow offline | 路演和离线稳定演示。 |

主要事件流：

```text
用户点击语音球
  -> MicrophonePermissionManager 请求麦克风权限
  -> DialogEngine.startDialog()
  -> 并行 AVAudioRecorder 录音用于声音复刻/回忆录
  -> ASR final 写入用户消息和 Stage1 记忆
  -> Chat final / TTS started 汇合为 assistant final
  -> AI 消息写入 UI 和 Stage1 记忆
  -> 数字人 TTS / SDK TTS 播报
  -> 会话结束后 Stage1MemoryFacade.finishConversationSession()
```

安全事件会触发 `onSafetyTriggered`，丢弃当前会话 transcript，停止录音，展示危机干预页，并阻止该会话进入回忆录生成。

普通对话默认仅本机；用户可在开聊前选择可生成或亲友。选择亲友时会进入成员选择器，可授权全体亲友或具体成员；对话开始后本轮授权冻结为 `currentDialogPrivacyMetadata`，中途切换只影响下一轮。

### 4.2 数字人对话

相关文件：

- `Modules/Home/AIRecordingViewController.swift`
- `Services/DigitalHumanSpeechService.swift`
- `Memoir/VolcEngineCredentialProvider.swift`
- `Memoir/VolcEngineTTSRequestFactory.swift`
- `Resources/web/MiniLive2.js`
- `Resources/web/avatar_manifest.json`
- `Resources/web/avatar_poster.png`

当前实现：

- 首页内嵌 `WKWebView` 数字人容器。
- 加载本地 `DHLiveMini.js`、`DHLiveMini.wasm`、`MiniLive2.js`、`MiniMateLoader.js` 和默认形象资源。
- 对话状态映射到数字人：聆听、整理、讲述、错误。
- Chat final text 触发数字人播报，避免依赖单一 TTS started 事件。
- 配置 `VolcEngineAPIKey` 和 `VolcEngineVoiceType` 后，使用 VolcEngine HTTP TTS 生成 WAV。
- WAV 通过 `window.DreamJourneyAvatar.feedAudioBase64(...)` 传入 WebView，驱动 WASM 口型与 WebAudio 播放。
- 启用数字人 WAV TTS 时关闭实时 SDK 内置播放器，避免双播。
- 冷启动采用透明真人 poster 首屏稳定展示，隐藏 loading 文案和 spinner；`avatar_video_surface_ready` 后 live canvas 淡入并替换 poster，降低打开应用时的明显切换感。

稳态保护：

- HTTP TTS 失败时，继续驱动数字人口型动画，并用 `AVSpeechSynthesizer` 兜底播放文本。
- WebView 返回 `audio_error`、`audio_decode_error`、`audio_fallback` 或 JS evaluate 失败时，进入同一兜底。
- 每轮播报有 14 到 28 秒 watchdog，防止卡在“正在讲述”。
- 错误、后台、登出、安全事件、会话结束会统一清理数字人音频和系统兜底播报。
- WAV 合成失败、WebAudio 失败或超时时，首页展示数字人故障恢复卡，用非技术化文案说明已切到系统语音或已自动收尾，并提供“重试数字人”和“继续语音”动作。
- watchdog timeout 自动收尾后会保留本轮回答文本，用户点击“重试数字人”时重新发起当前回答的数字人 WAV 合成；点击“继续语音”或新会话 reset 时清理这份重试缓存。
- 语音服务异常不再直接 toast 底层错误原文，避免真机路演暴露 API/SDK 技术细节。
- 首页右上新增“数字人真机诊断”入口，打开 `DigitalHumanDiagnosticsViewController` 可查看当前对话引擎、数字人口型 TTS、实时语音凭证和 OpenAvatar 后端的脱敏状态。
- 诊断页支持复制排障文本和诊断 JSON，明确不包含任何 API Key、Token 或 Secret；仅显示“已就绪/可演示/需配置”、认证模式、资源 ID、修复建议等非敏感信息。
- 诊断页和诊断 JSON 已内置“音频链路验收”清单，覆盖 `web_audio`、`system_tts`、`timeout` 三种收口来源；App 首页启动和诊断页打开会自动写 `Documents/diagnostics/digital_human_readiness.txt/json`，播放收口事件会自动写入 `Documents/diagnostics/digital_human_playback.log`，preflight 可直接拷贝到 evidence 目录；现场也可保存控制台日志兜底，并按 `wav_synth_success -> playback_finished source=web_audio`、`fallback=systemTTS -> playback_finished source=system_tts`、`playback_timeout -> playback_finished source=timeout` 判断真机路径。

当前限制：

- 仍需真机确认 WAV 真实出声、口型同步、WebAudio 首次播放权限和断网降级。
- Manifest 只校验资源存在、sha256、gzip JSON 和 frame count，不校验视频编码和 WebGL 运行时性能。

### 4.3 Stage1 记忆与隐私模型

相关文件：

- `Services/Stage1MemoryFacade.swift`
- `Services/ConversationMemoryManager.swift`
- `Services/Privacy/MemoryPrivacyScope.swift`
- `Services/KBLitePrivacyScopePolicy.swift`
- `Services/MemoryArchive/MemoryArchiveModels.swift`
- `Services/TimeMailbox/TimeMailboxModels.swift`

当前隐私 scope：

| Scope | 含义 | 默认行为 |
| --- | --- | --- |
| `privateOnly` | 私密素材 | 不进入共享/生成链路。 |
| `localOnly` | 仅本机 | 默认对话 scope，不进入远端生成、家庭同步和看板。 |
| `generationAllowed` | 可生成 | 允许 DeepSeek/KBLite 远端抽取、回忆录生成。 |
| `familyCircle` | 亲友可见 | 允许家庭同步、亲友圈、关怀看板按成员可见性裁剪。 |

当前实现重点：

- `ConversationTurn`、`Stage1MailboxMemoryInput`、`DialogMessage`、TimeMailbox、MemoryArchive、KBLite entities 均携带 `privacyMetadata`。
- `FamilyMemberVisibility` 支持 all-family 和 selected-members。
- `FamilyVisibilityPickerViewController` 已接入采集端 UI，普通对话、档案文字、档案照片、时空信箱写信在选择“亲友”时可进一步选择“全体亲友”或具体家庭成员。
- `HomeDialogPrivacyMetadataFactory` 统一生成首页对话授权 metadata，确保本机/可生成 scope 不会遗留上一次的具体亲友名单。
- `.selectedMembers([])` 不再误等价于全体可见。
- 旧数据缺字段时保守迁移为 `localOnly` 或兼容旧 JSON。

### 4.4 KBLite 家庭知识图谱

相关文件：

- `Services/KBLiteManager.swift`
- `Services/KBLiteModels.swift`
- `Services/KBLitePrivacyScopePolicy.swift`
- `Services/KBLiteGapDetector.swift`
- `Services/KBLiteSemanticSearch.swift`
- `Modules/Knowledge/*`

当前实现：

- KBLite graph version 已升级到 v2。
- 人物、地点、事件、事实均携带隐私 metadata。
- 远端抽取只允许 `generationAllowed` transcript。
- Transcript 提取先执行本地确定性沉淀，再让 LLM 补充；即使远端抽取成功但返回空数组，明确姓名、地点、年份、居住/开店等事实仍会进入结构化知识库。
- Prompt context、开场白 hint、知识缺口上下文按 `.prompt` 可用性过滤。
- 同名实体/事实只允许同 scope 合并，避免 local/family/generation 数据互相污染。
- Export、Widget、Backend sync、PDF 输入图谱均通过 sanitized graph 输出。
- Family sync / CareDashboard 可按目标家庭成员二次裁剪。

当前限制：

- `.export`、`.widget`、`.backendSync` 在未显式授权前保持保守空输出。
- 需要后续明确是否新增更细的 export/widget/backend 授权 scope。

### 4.5 时空信箱

相关文件：

- `Modules/TimeMailbox/TimeMailboxViewController.swift`
- `Services/TimeMailbox/TimeMailboxModels.swift`
- `Services/TimeMailbox/TimeMailboxRepository.swift`

当前实现：

- 本地信件创建、保存和延迟投递。
- 信件支持 `privacyMetadata`。
- 写信时选择“亲友”会显示“亲友范围”，可授权给全体亲友或具体成员。
- 旧信件默认迁移为 localOnly。
- 路演 seed 会注入可展示的已投递信件。
- 信件正文默认不进入全局 Stage1 记忆，避免被误用于其它生成场景。

当前限制：

- 生产级 APNs、真实跨设备投递、亲友账号协作尚未完成。

### 4.6 记忆档案馆

相关文件：

- `Modules/MemoryArchive/MemoryArchiveViewController.swift`
- `Services/MemoryArchive/MemoryArchiveModels.swift`
- `Services/MemoryArchive/MemoryArchiveRepository.swift`

当前实现：

- 文本和照片素材本地归档。
- 保存时可选择隐私范围。
- 文字素材和照片选择“亲友”时，会先选择全体亲友或具体成员，再保存 `familyVisibility`。
- 私密/本机素材不进入远端生成链路。
- 照片只有 `generationAllowed` 才触发 DeepSeek Vision 和 KBLite 图片分析入库。
- 路演 seed 注入档案文本和照片 mock analysis。

当前限制：

- 照片素材管理、批量整理、长期检索体验仍可增强。

### 4.7 家族足迹

相关文件：

- `Modules/Map/MapFootprintViewController.swift`
- `Modules/Map/FamilyFootprintIllumination.swift`
- `Modules/Map/FamilyFootprintTimeline.swift`
- `Modules/Map/FamilyFootprintSharePoster.swift`
- `Modules/Map/MemoryAnnotation.swift`

当前目标是从“回忆点标注”升级为类似高德点亮地图的家族足迹表达。

当前实现：

- 城市、全国、世界三档视角。
- 全家、祖辈、父辈、我们、下一代等代际筛选。
- 不同代际驱动点亮区域和统计变化。
- 顶部故事卡使用 `FamilyFootprintJourneySummary` 展示当前代际的迁徙路线、跨年份、跨城市/国家和“更大的世界”摘要。
- 使用 `MAPolygon` / `MAPolygonRenderer` 绘制青色发光区域。
- 使用 `FamilyFootprintIllumination` 将足迹点映射到点亮区域。
- 优先读取 bundle 中 `family_footprint_boundaries.json`，缺失时回退内置 demo 边界。
- 支持足迹分享海报：当前筛选状态生成竖版海报，包含标题、统计、点亮区域摘要、迁徙路线连线、二维码 payload 和导出；迁徙点线与点亮区域共用同一 map bounds，保持全国/世界视角的投影比例一致。
- 支持地图不可用时的产品化点亮预览：AMap key 缺失、地图创建失败或地图加载失败时，页面展示“家族足迹点亮预览”卡片，复用本地 poster renderer 继续展示当前 scope/代际下的家族足迹，不再在 UI 暴露“兜底”工程词。
- 足迹海报已补充“点亮区域 / 到过的城市 / 迁徙路线”图例，降低青色光圈、城市点和连线的理解成本。

当前限制：

- 还没有接入 `AMapSearch` / DistrictSearch 实时行政边界查询。
- 当前点亮区域主要依赖本地边界缓存或 demo 多边形。
- 后续可用真实 GeoJSON 或 AMapDistrictBoundaryProvider 替换。

### 4.8 亲友圈与关怀看板

相关文件：

- `Modules/Family/FamilyCircleViewController.swift`
- `Modules/Family/FamilyCircleQuickAction.swift`
- `Modules/Family/FamilyVisibilityPickerViewController.swift`
- `Modules/CareDashboard/CareDashboardViewController.swift`
- `Services/CareDashboard/CareSignalAnalyzer.swift`
- `Services/CareDashboard/CareSignalModels.swift`
- `Services/FamilyAccessIdentityResolver.swift`
- `Services/FamilyAccessControlService.swift`
- `Services/FamilyRepository.swift`

当前实现：

- 亲友 mock 已统一为陈氏家族线，符合家族姓氏继承。
- 亲友列表成员行可进入成员视角关怀看板。
- 普通对话、档案馆和时空信箱采集端可选择全体亲友或指定成员可见。
- KBSync 导出可选择全体亲友或具体成员。
- 当前登录用户可通过手机号匹配或本机 override 解析为家庭成员身份；关怀看板未显式传入成员时默认按当前访问者身份过滤。
- 邀请接受和成员权限撤回已有本地服务层：手机号匹配才允许接受邀请，已撤回邀请拒绝；撤回某成员权限时，全体亲友授权会转换成剩余成员白名单，单成员授权会移除该成员。
- Family 页面已接入本机演示 UI：搜索框/加号可接受手机号邀请；成员行可长按或左滑撤回访问；已撤回成员会展示状态并阻止进入成员视角关怀看板；接受/撤回状态已本机持久化，路演 reset 会清理该演示权限状态。
- CareDashboard 输入按 `.careDashboard` surface 和目标成员可见性过滤。
- 看板展示观测窗口、数据覆盖摘要、观测天数、7 天脱敏趋势、脱敏观察报告和需关注信号。
- 右上角分享入口可生成一页脱敏关怀周报，内容来自 `CareSignalSnapshot` 聚合字段，包含风险等级、观测窗口、数据覆盖、指标摘要、观察摘要、需关注信号、关怀建议和边界声明。
- 分享周报同步包含“趋势观察”，趋势来自最近 7 天活跃日期的情绪/睡眠/身体/重复信号聚合，不包含原始句子。
- 不展示完整原始对话句子，也不在分享周报里导出 transcript/raw turns。

当前限制：

- 真实云端亲友账号体系、服务端持久化、云同步、长期趋势、推送提醒尚未完成。
- 当前看板更像本机脱敏周报雏形，不是医疗或诊断能力。

### 4.9 回忆录、DeepSeek 与 TTS

相关文件：

- `Memoir/MemoirFlowManager.swift`
- `Memoir/MemoirService.swift`
- `Memoir/MemoirTTSService.swift`
- `Memoir/VoiceCloneService.swift`
- `Memoir/DeepSeekService.swift`
- `Memoir/DeepSeekSafetyGuarding.swift`
- `Memoir/VolcEngineCredentialProvider.swift`
- `Memoir/VolcEngineTTSRequestFactory.swift`

当前实现：

- 回忆录生成入口会检查会话质量和隐私 scope。
- 只有允许 `.memoirGeneration` 的内容进入 DeepSeek 生成。
- DeepSeek chat、knowledge、image、Memoir、TTS 前已接 Safety Guard。
- VolcEngine TTS 支持 MP3 和 WAV request。
- 回忆录 TTS 默认 MP3，数字人 TTS 使用 WAV。
- VoiceClone 旧 key 仍作为兼容 fallback，新版 `VolcEngineAPIKey` 优先。

当前限制：

- 声音克隆、persona speaker 绑定、撤回和审计链路仍未完整生产化。

### 4.10 Safety Guard 与危机干预

相关文件：

- `Services/Safety/SafetyMonitor.swift`
- `Services/Safety/SafetyGuardClient.swift`
- `Services/Safety/SafetyGuardModels.swift`
- `Modules/Safety/CrisisInterventionViewController.swift`
- `Memoir/DeepSeekSafetyGuarding.swift`

当前实现：

- 本地 `SafetyMonitor` 可识别高风险表达。
- 危机会话不写入记忆、不生成回忆录。
- Safety Guard client 支持真实 HTTP POST `/v1/safety/evaluate`。
- 支持 Bearer token、fail-closed、非 2xx、网络错误和解码失败兜底。
- 支持 `--use-mock-safety-guard` / `DREAMJOURNEY_SAFETY_GUARD=mock_allow` 用于路演。
- Roadshow offline mode 下默认 mock allow，不调用真实 guard endpoint。

当前限制：

- 真实 Safety Guard 服务字段、鉴权、审计 HMAC、超时策略还需联调确认。
- App 不能宣称医疗诊断或替代紧急救助。

### 4.11 路演模式

相关文件：

- `Services/RoadshowDemoSeed.swift`
- `Services/RoadshowDemoRoute.swift`
- `Modules/Home/RoadshowDemoRouteViewController.swift`
- `Common/UI/RoadshowModeBannerView.swift`

启动参数 / 环境变量：

| 参数或环境变量 | 作用 |
| --- | --- |
| `--seed-roadshow-demo` / `DREAMJOURNEY_SEED=roadshow_demo` | 注入路演数据。 |
| `--reset-roadshow-demo` / `DREAMJOURNEY_RESET_DEMO=1` | 重置 demo 状态并重新 seed。 |
| `--roadshow-offline-mode` / `DREAMJOURNEY_ROADSHOW_OFFLINE=1` | 离线演示模式。 |
| `--use-mock-dialog-engine` / `DREAMJOURNEY_DIALOG_ENGINE=mock` | 强制 Mock 对话引擎。 |
| `--use-mock-safety-guard` / `DREAMJOURNEY_SAFETY_GUARD=mock_allow` | 强制 mock allow safety guard。 |

当前路演 seed 注入：

- 自动登录路演测试账号。
- 陈氏家族成员。
- 时空信箱 delivered 信件。
- 记忆档案馆文本和照片 mock analysis。
- KBLite graph。
- CareDashboard 可用多日 familyCircle transcript，可直接展示 7 天趋势和脱敏周报。

当前主持驾驶舱：

- 首页“演示向导”显示 `2/6` 这类紧凑进度、下一步标题和本机素材/隐私边界说明。
- “继续”按钮直达下一未完成阶段对应 Tab；分享包阶段直达导出收口。
- 六步全部勾选完成后，“继续”变为复盘入口，打开路线页复制验收清单。
- 路线页 Header 与首页使用同一套 `CompletionSummary`，减少现场口径漂移。

当前证据包能力：

- `roadshow_device_smoke_preflight.sh` 创建截图、录屏、分享包、路线验收和状态键证据目录；真机识别采用 `xctrace`、`xcodebuild -showdestinations`、`devicectl list devices` 三路兜底，避免 `xctrace` offline 误报阻断可用设备；`RoadshowDeviceSmokePreflightVerify` 用 fake `xcrun/xcodebuild/devicectl` 自动覆盖无设备 blocked、无设备 allowed、假真机 PASS 和 `xctrace` offline 兜底真机路径，防止 preflight 脚手架、build/install/launch/container 抽样和 route completion 导出漂移。
- `roadshow_evidence_report.py` 可对 evidence 目录生成 `evidence_status.json` 和 `evidence_status.md`。
- 证据状态分为 `needs_preflight`、`needs_privacy_review`、`needs_manual_evidence`、`complete`，可用于路演前检查缺失截图、录屏、分享包、自动上下文和证据包密钥泄露风险。
- 证据报告新增 Roadshow Readiness 摘要，直接输出 `canArchive`、完成百分比、阻塞类型和第一条最高优先级动作；只有状态为 `complete` 且无隐私命中时才允许归档/分享。
- 证据状态会输出按优先级排序的 `nextActions`，优先提示同步 App 自动落盘的数字人诊断、补逐屏截图、导出分享包、补播放日志等下一步动作；对数字人播放日志和分享包隐私抽查，会直接给出 `roadshow_digital_human_playback_audit.py` 与 `roadshow_share_package_privacy_check.py` 的可执行命令。
- 证据报告新增 `stageGroups` 和 Markdown `Stage Evidence` 表，会按“自动上下文与脚手架”、每个路演阶段、补充证据归组展示 present/missing，便于路演前按阶段复盘。
- 证据报告新增 `qualityFindings` 和 Markdown `Quality Review`：截图文件必须是真 PNG，录屏文件必须是真 MP4；`route_completion/route_completion_preferences.txt` 中 6 段 route completion key 必须全部为 `true`；`route_completion/route_acceptance_checklist.md` 必须是 App 内“复制验收”的真实结果，包含 `路演验收进度 6/6`、6 个已勾选阶段、6 个固定截图文件和边界声明；`diagnostics/digital_human_readiness.json` 必须是有效 JSON，且包含 `items`、`playbackEvidenceChecks` 和脱敏 `redaction` 说明；`diagnostics/digital_human_playback.log` 必须包含至少一条完整播放收口链；`share_packages/all_family.json` 和 `share_packages/selected_member.json` 必须是可导入分享包形态，外层包含 `sourceUserId/sourceNickname/exportDate/graphJSON`，内层 `graphJSON` 可解析且包含 `people/places/events/facts` 数组，并且不含 `PRIVATE_`、`LOCAL_`、`GENERATION_`、`RAW_TRANSCRIPT`、`FULL_LETTER`、`UNAUTHORIZED_` 等泄漏标记；`share_packages/privacy_check.log` 必须明确 PASS，并点名两个 JSON 与 no private/raw transcript/unauthorized 抽查结论；`Scripts/roadshow_share_package_privacy_check.py` 可对真机导出的两个 JSON 或 evidence 目录生成该 PASS 抽查日志；否则状态保持 `needs_manual_evidence`，`--fail-on-missing` 失败。
- 证据报告新增 `archivePlan` 和 Markdown `Archive Package`，完整且干净的 evidence 目录可通过 `--archive` 生成 `dreamjourney_roadshow_evidence.zip`；zip 内置 `archive_inventory.json`，为每个证据文件记录 `sizeBytes` 和 `sha256`；缺证据、隐私命中或质量问题都会拒绝打包。
- evidence report 会扫描清单内的文本类证据（日志、JSON、Markdown、命令文件、诊断文本），命中 token/key/secret 形态内容时只输出文件、行号和模式类别，不回显原始值；`--fail-on-missing` 在缺证据或隐私命中时都会失败，防止带密钥的真机日志进入路演材料。
- `RoadshowDemoRouteViewController` 内置“证据中心”执行卡，按现场采集、诊断复制、导出样本、隐私抽查、脚本生成分类展示证据；同时解释 `needs_preflight`、`needs_privacy_review`、`needs_manual_evidence`、`complete` 四种状态，并可复制带收口顺序和隐私闸门说明的完整证据清单。
- 数字人诊断与播放日志 `diagnostics/digital_human_readiness.txt/json`、`diagnostics/digital_human_playback.log` 已纳入 manifest、preflight checklist、App 内证据清单和 evidence report 必填项；运行时会自动把脱敏诊断和结构化播放事件写入 `Documents/diagnostics/`，preflight 会尝试拷贝这些文件，`console_capture_next_steps.txt` 仍给出从 `app_console_sample.log` 提取播放日志的 grep 兜底命令；`nextActions` 会优先提示补齐 WebAudio、系统 TTS 兜底和 watchdog 超时收尾日志。
- `Scripts/roadshow_digital_human_playback_audit.py` 可对 `diagnostics/digital_human_playback.log` 或 evidence 目录输出 JSON 严格演练审计，要求 `web_audio`、`system_tts`、`timeout` 三类收口样本都存在；命中 credential-shaped 日志内容时进入 `privacy_review`，且只输出行号和模式，不回显原始 key/token/secret。
- `DigitalHumanRuntimeLogVerify` 静态锁住运行时代码、诊断口径、严格播放审计脚本和 evidence report 使用同一组日志 token，避免真机证据采集时因日志改名导致质量 gate 误挡。

当前主持路线：

1. 语音陪伴
2. 时空信箱
3. 记忆档案馆
4. 家族足迹
5. 亲友关怀
6. 分享包 / 隐私边界

每段包含口播、验收点、兜底说明和边界文案。

路线页还支持：

- 按阶段勾选完成状态，状态使用稳定 completion key 持久化。
- 一键复制当前验收清单，包含 6 段完成情况、启动参数、验收标准、每段固定截图证据文件和边界声明。
- 一键复制证据清单，包含截图、录屏、分享包、诊断、控制台日志、隐私抽查、`evidence_status.json/md`、状态解释和收口命令。
- 一键清空验收状态，便于路演前重新走一遍。

## 5. 配置与密钥管理

相关文件：

- `Services/AppConfiguration.swift`
- `Resources/Info.plist`
- `.gitignore`
- `Scripts/SecretConfigVerify/main.py`
- `docs/superpowers/reports/2026-06-11-device-api-config.md`

当前规则：

1. `Info.plist` 只保留占位符，不提交真实 key。
2. 真机本地 key 放在 ignored 文件 `DreamJourney/Resources/LocalConfig.plist`，或通过 Xcode Scheme env 注入。
3. 构建时如果存在 `LocalConfig.plist`，会复制到 app bundle。
4. `AppConfiguration` 读取顺序：
   - Scheme env 原始 key，例如 `VolcEngineAPIKey`
   - Scheme env `DREAMJOURNEY_` 蛇形 key
   - bundled `LocalConfig.plist`
   - `Info.plist`
5. 占位符会被过滤：`YOUR_*`、`$(...)`、`PLACEHOLDER` 等不会被当作真实配置。

当前已接入配置读取的能力：

- AMap
- DeepSeek
- VolcEngine HTTP TTS
- VolcEngine Realtime Dialog
- Safety Guard
- OpenAvatar chat base URL

当前不要提交或回显真实密钥。

App 内数字人诊断会读取这些配置的脱敏状态：

- `VolcEngineAPIKey` + `VolcEngineVoiceType`：判断数字人口型 WAV TTS 是否可启用。
- `VolcEngineRealtimeAPIKey` 或旧式 `VolcEngineAppID/AppKey/AppToken`：判断实时语音对话是否可走真实 SDK。
- `OpenAvatarChatBaseURL`：判断真机是否可能访问数字人知识后端；`localhost` 会被标记为真机风险。
- 路演 mock/offline 参数：标记当前是否为本机演示引擎。
- 诊断输出包含文本和 JSON 两种证据形态，运行时会自动写入 `Documents/diagnostics/digital_human_readiness.txt/json`；播放日志自动写入 `Documents/diagnostics/digital_human_playback.log`，preflight 会同步到 evidence 目录。

## 6. 验证体系

主验证脚本：

```bash
bash Scripts/verify_phase1.sh
bash Scripts/verify_phase2.sh
```

阶段2验证覆盖：

| 验证脚本 | 覆盖内容 |
| --- | --- |
| `SafetyVerify` | 本地高风险识别。 |
| `SafetyGuardVerify` | HTTP guard、fail-closed、mock allow。 |
| `PrivacyScopeVerify` | 隐私 scope 和成员可见性。 |
| `MemoryPrivacyIntegrationVerify` | KBLite、导出、prompt、memoir、care surface 过滤。 |
| `TimeMailboxVerify` | 信箱持久化和隐私迁移。 |
| `MemoryArchiveVerify` | 档案馆 scope、照片分析权限。 |
| `CareDashboardVerify` | 成员级关怀输入过滤、7 天脱敏趋势、周报生成和脱敏输出。 |
| `CareDashboardShareReportUIVerify` | 关怀周报分享 UI、趋势 UI、聚合字段来源、系统分享出口和原始对话防泄露边界。 |
| `FamilyAccessIdentityVerify` | 本机访问者身份解析：手机号匹配、override 优先和无效回退。 |
| `FamilyAccessControlVerify` | 邀请手机号绑定、撤回邀请拒绝、成员权限撤回和非亲友 scope 保持不变。 |
| `FamilyAccessControlUIVerify` | Family 页面接受邀请/撤回访问入口和服务调用静态 gate。 |
| `MockDialogEngineVerify` | Mock 对话事件顺序、安全触发。 |
| `RoadshowDemoVerify` | demo seed、陈氏家族线、多日关怀趋势样本和边界文案。 |
| `RoadshowRouteVerify` | 6 段主持路线、每段固定截图证据文件、证据中心 artifact、下一步计算、完成百分比、验收摘要、验收清单文本和重置验收状态。 |
| `RoadshowHostRouteUIContractVerify` | 首页“演示向导”、下一步/清单入口、无工程词首屏文案、小屏文字缩放、完成状态 key、进度文案、证据中心、复制验收/证据清单、清空验收状态和每段直达按钮。 |
| `RoadshowEvidenceScaffoldVerify` | preflight evidence manifest、截图/状态键/分享包/路线验收模板脚手架与 route step id、route evidence file 一致性。 |
| `RoadshowDeviceSmokePreflightVerify` | preflight dry-run 回归：无真机退出码、`--allow-no-device`、fake 真机 build/install/launch/container 证据、`xctrace` offline 但 `xcodebuild/devicectl` 可用的兜底真机路径、route completion preferences 自动导出、App 自动落盘数字人诊断/播放日志拷贝、console 兜底提取命令和严格数字人播放审计命令。 |
| `RoadshowEvidencePackageVerify` | evidence report 的 JSON/Markdown 输出、缺失项统计、优先级 `nextActions`、数字人严格播放审计命令、分享包样本隐私检查命令、Roadshow Readiness、Stage Evidence、Quality Review、截图 PNG/录屏 MP4 格式质量 gate、路线完成状态质量 gate、路线复制验收清单质量 gate、数字人 readiness JSON 结构 gate、分享包外层 schema 与内层 graphJSON 质量 gate、分享包隐私抽查日志质量 gate、归档计划、`--archive` zip 生成、`archive_inventory.json` size/sha256 校验和 `--fail-on-missing` 行为。 |
| `SharePackagePrivacyVerify` | 分享包 JSON 隐私验收：familySync scope、成员裁剪、跨引用清理和 sentinel 防泄露。 |
| `RoadshowSharePackageVerify` | 路演 seed 分享包隐私验收：完整信件正文/完整对话原文防泄露和 selected-member 裁剪。 |
| `RoadshowSharePackageSampleVerify` | 真机导出分享包样本 CLI：校验 `all_family.json`、`selected_member.json` 外层 schema、内层 graphJSON、forbidden sentinel，并生成可写入 `privacy_check.log` 的 PASS/FAIL。 |
| `RoadshowShareExportUIVerify` | 路演分享包 UI 收口：路线直达、导出对象选择、可滚动隐私收据、sanitized API 和 JSON 分享确认。 |
| `SecretConfigVerify` | secret 不入库。 |
| `VolcEngineConfigVerify` | API Key、voice type、占位符过滤。 |
| `VolcEngineTTSRequestVerify` | MP3/WAV TTS request 和响应解析。 |
| `VolcEngineRealtimeConfigVerify` | 新版 API Key 和旧式三件套优先级。 |
| `FamilyFootprintVerify` | 足迹核心模型。 |
| `FamilyFootprintIlluminationPolicyVerify` | 点亮策略。 |
| `FamilyFootprintPosterVerify` | 海报生成、导出入口、迁徙点线/点亮区域统一坐标 bounds、region center/overlay coordinates 纳入 bounds 和长文案不尾部省略。 |
| `FamilyFootprintFallbackVerify` | 足迹页路演/无 AMap key/地图加载失败时的“家族足迹点亮预览”、无 key 跳过 `MAMapView` 创建和加载成功后清除失败态。 |
| `DigitalHumanAssetVerify` | 数字人资源 manifest 和 sha256，包含视频、gzip 数据、WASM、JS、公共贴图和冷启动 poster。 |
| `DigitalHumanStartupRevealVerify` | 数字人冷启动首屏稳定展示：WebView 直接展示透明真人 poster、loading 文案隐藏、poster 不放入初始隐藏容器、live canvas 只在 video-ready 后淡入。 |
| `DigitalHumanRuntimeLogVerify` | 数字人 WebAudio、系统 TTS 兜底、watchdog 收尾运行日志与 evidence report 质量 gate 口径一致，并验证严格播放审计脚本的三链路样本识别和隐私脱敏。 |
| `DigitalHumanPlaybackPolicyVerify` | 数字人播放状态 policy：WebAudio health、SDK TTS 忽略、watchdog、系统 TTS request id 防串音、friendly fallback 文案和路演音频链路验收日志口径。 |
| `DigitalHumanFallbackUIVerify` | 首页数字人故障恢复卡、重试/继续动作和 raw technical error 防暴露。 |
| `DigitalHumanReadinessVerify` | 数字人真机诊断模型，覆盖 modern/legacy/mock/missing 状态、修复建议、音频链路验收清单、JSON 证据和 API Key/Token 脱敏。 |
| `DigitalHumanDiagnosticsUIVerify` | 首页诊断入口、sheet 展示、音频链路验收卡、复制文本/JSON 脱敏诊断和不展示密钥文案。 |
| `BuildWarningCleanupVerify` | 锁住 `TGToast` 的 iOS 15+ keyWindow 写法、`Copy LocalConfig.plist` build phase output marker 和 preflight 诊断证据提示。 |

最近确认通过：

- `bash Scripts/verify_phase2.sh`
- `python3 Scripts/SecretConfigVerify/main.py`
- `plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj`
- `git diff --check`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/DreamJourneyDeviceBuild build`

已知 warning：

- `TGToast.swift` 的 `UIApplication.shared.windows` deprecated warning 已清理，改为从 `connectedScenes` / `UIWindowScene` 获取 key window。
- `Copy LocalConfig.plist` run script 已增加 `$(DERIVED_FILE_DIR)/LocalConfig.copy.done` output marker，避免 Xcode 提示该脚本每次构建都运行。
- 仍可能存在第三方 Pods 或旧 UI API 的非阻塞 warning，需要后续按出现位置逐项清理。

## 7. 当前完成度

| 模块 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | Mock 引擎和纯 Swift 验证完成；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响。 |
| Safety Guard 合约 | 82% | iOS client 和 fail-closed 策略完成；真实服务仍需联调。 |
| Privacy Scope 模型 | 95% | 模型、迁移、成员可见性、采集端授权 UI 和 surface 过滤较完整。 |
| KBLite/Export/Widget 过滤 | 78% | 图谱和导出过滤完成，授权策略仍需产品确认。 |
| CareDashboard/Family Sync | 87% | 本机脱敏看板、7 天脱敏趋势、可分享脱敏关怀周报、成员级导出、采集授权、本机访问者身份解析、邀请接受和权限撤回演示 UI/本机持久化可展示；真实云端账号同步和长期趋势未完成。 |
| Roadshow Demo Cut | 99% | seed/offline/演示向导/路线清单/边界文案、App 内证据中心、evidence preflight、manifest、截图/状态键/路线验收模板和 evidence status 缺失项报告完成；首页可展示 6 步进度、下一步和一键下一步，小屏演示向导/路线进度/证据命令已做换行和缩放保护，首屏已移除“路演模式/兜底”工程词；seed 已补多日关怀趋势样本；路线页可直达各演示段，并支持复制验收清单、复制证据清单、清空验收状态和每段固定截图证据文件；App 内证据中心已展示检查命令、最终 `--archive` 归档命令和 `archive_inventory.json` size/sha256 复核口径；preflight 可从真机 Preferences plist 自动抽取 `route_completion/route_completion_preferences.txt`，并已有 fake xcrun/xcodebuild dry-run gate 锁住无设备/假真机路径；evidence report 会校验 6 段路线全为 true，并要求 `route_completion/route_acceptance_checklist.md` 粘贴真实 6/6 验收结果而不是模板；分享包步骤可直接进入可滚动隐私收据和导出收口；数字人诊断文本/JSON 和 `diagnostics/digital_human_playback.log` 已纳入证据中心、preflight manifest 和 evidence report，且有严格播放审计脚本检查三类收口样本和日志脱敏；`roadshow_evidence_report.py` 会输出 Roadshow Readiness、按优先级排序的 `nextActions`、按阶段归组的 `Stage Evidence`、截图/录屏格式、路线完成/路线验收/播放日志/分享包 `Quality Review`、`Archive Package` 归档包入口和 zip 内 `archive_inventory.json` 校验清单；足迹页具备点亮预览和长文案自适应海报；需逐屏 smoke 和录屏。 |
| 数字人对话稳态 | 92% | 资源、WAV TTS、系统语音兜底、watchdog、故障恢复卡、timeout 后可重试当前回答、重试/继续动作、App 内脱敏诊断、修复建议、音频链路验收卡、诊断 JSON 证据、自动落盘 `Documents/diagnostics/digital_human_readiness.txt/json` 与 `digital_human_playback.log`、preflight 自动拷贝、资源完整性 gate、播放状态 policy gate、运行日志防漂移 gate、三链路严格播放审计、readiness gate、diagnostics UI gate 和 fallback UI gate 已完成；真机口型/声音待验。 |
| 家族足迹点亮 | 89% | 三档视角、代际筛选、点亮面层、迁徙故事线、海报路线连线、点线/区域统一坐标 bounds、region center/overlay coordinates 纳入海报 bounds、海报长文案不截断、无 AMap key 跳过地图创建、地图失败时点亮预览、海报图例已完成；真实边界数据待替换。 |
| 分享包隐私验收 | 96% | 已有自动 sentinel gate、路演 seed 分享包 gate、路演导出 UI gate、真机导出样本 CLI、evidence report 分享包外层 schema/内层 graphJSON 内容质量 gate 和 privacy_check.log 明确 PASS 抽查 gate；导出前展示可滚动隐私收据，仍需真机导出样本留档。 |
| 配置与密钥治理 | 89% | LocalConfig/env/placeholder、secret gate 和 App 内脱敏诊断完成；真实密钥仍只应放 ignored LocalConfig 或 Scheme env。 |

最新真机证据口径：

- `/tmp/dreamjourney_roadshow_smoke_20260612_220440`：iPhone 17 / iOS 26.6 真机 preflight 通过，iPhoneOS build、签名 build、安装、roadshow reset/seed/offline 启动、容器抽样通过。
- 该 evidence report 当前为 `needs_manual_evidence`，证据完整度 `55%`，已存在 `17/31` 项，缺截图 8 张、录屏、分享包样本、隐私抽查日志、控制台样本和数字人播放日志；隐私扫描命中 `0`。
- `diagnostics/digital_human_readiness.txt` 和 `diagnostics/digital_human_readiness.json` 已从真机 `Documents/diagnostics/` 自动同步，诊断状态为“可演示”；`diagnostics/digital_human_playback.log` 需要完成一次数字人真实播放后才会生成。

## 8. 真机验证建议路线

建议按路演主持清单顺序验证：

1. 使用 `--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode` 启动。
2. 首页确认“演示向导”显示 `0/6` 或当前进度、下一步名称和本机素材/隐私边界；可点击“下一步”直达下一阶段，也可点击“清单”进入主持清单。
   - 路线页开始前可点击“清空验收”重置状态。
   - 每完成一段后勾选该阶段；结束时点击“复制验收”保存文本清单到 `route_completion/route_acceptance_checklist.md`。
3. 语音陪伴：验证 mock 对话、真实对话、数字人状态、WAV/系统 TTS 降级。
4. 数字人诊断：启动首页后 App 会自动写 `Documents/diagnostics/digital_human_readiness.txt/json`；点击首页右上诊断入口可刷新并人工确认对话引擎、TTS、实时语音和后端状态符合当前配置，复制文本和 JSON 中不出现任何真实 key/token。重跑 preflight 后文件应同步到 `diagnostics/digital_human_readiness.txt/json`。
5. 数字人诊断和播放日志：App 会自动写 `Documents/diagnostics/digital_human_readiness.txt/json` 与 `Documents/diagnostics/digital_human_playback.log`，完成数字人演练后重跑 preflight 或手动 `devicectl copy from` 同步到 evidence 目录；如果自动日志缺失，再按 `console_capture_next_steps.txt` 保存完整 `app_console_sample.log` 并提取 `[DigitalHumanSpeech]`、`wav_synth_success`、`fallback=systemTTS`、`playback_timeout` 和 `playback_finished` 相关行到 `diagnostics/digital_human_playback.log`；至少包含一种收口路径，完整验收建议覆盖 `web_audio`、`system_tts`、`timeout` 三类。
6. 时空信箱：打开已投递信件，确认边界文案和隐私行为。
7. 记忆档案馆：打开文本/照片素材，确认照片分析和隐私 scope。
8. 家族足迹：切换城市/全国/世界和代际，确认点亮区域、统计、海报分享；断网或移除 AMap key 时确认“家族足迹点亮预览”可用，海报图例能解释点亮区域、城市点和迁徙路线。
9. 亲友关怀：进入成员视角看板，确认 7 天趋势、脱敏报告、不展示原文，并用右上角分享生成一页脱敏关怀周报。
10. 分享包：从路演路线最后一步直达导出对象选择，确认隐私收据展示导出对象、实体统计、过滤范围和边界文案；再导出全体/单个成员分享包，抽查不含 localOnly、完整信件正文和完整对话原文。
11. 证据收口：对 evidence 目录运行 `python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --fail-on-missing`，按 `evidence_status.md` 的 `Next Actions` 优先补齐诊断、播放日志、截图、录屏、分享包、隐私抽查和日志，直到状态变为 `complete`。
12. 归档交付：运行 `python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --archive --fail-on-missing`，生成 `dreamjourney_roadshow_evidence.zip`；zip 内的 `archive_inventory.json` 可用于复核每个证据文件的 size/sha256。

数字人真机重点日志：

```text
[DigitalHumanSpeech] assistant_final
[DigitalHumanSpeech] wav_synth_success
[DigitalHuman] { type: audio_buffered, ... }
[DigitalHuman] { type: audio_ended, ... }
[DigitalHumanSpeech] wav_synth_failed ... fallback=systemTTS
[DigitalHumanSpeech] playback_finished source=web_audio|system_tts|timeout
```

真机 UI 重点观察：

- WAV/音色/API 异常时是否显示“已切换到系统语音”，且没有暴露底层错误。
- 点击“重试数字人”是否重新尝试当前回答的数字人播报。
- 点击“继续语音”是否隐藏提示并保持主线可继续。
- 点击“数字人真机诊断”是否能打开状态页；每项是否有修复建议；复制文本/JSON 是否只含状态摘要和建议，不含任何真实 API Key、Token 或 Secret。

## 9. 下一步开发优先级

P0：

- 真机验证数字人 WAV 出声、口型同步、断网/错 voice type 兜底。
- 按 `roadshow_device_smoke_preflight.sh` 输出的 6 阶段 checklist 完成逐屏 smoke、截图和录屏。
- 真机从路演路线最后一步导出全体亲友/单个成员分享包，保存隐私收据截图和 JSON 样本，运行 `python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> --write-log <evidence-dir>/share_packages/privacy_check.log` 生成抽查日志，再交给 evidence report 归档 gate。
- 真机 smoke 普通对话/档案/信箱选择“亲友 -> 具体成员”后导出对应成员分享包，确认 UI 选择和 JSON 裁剪一致。

P1：

- 接入真实 Safety Guard 服务联调，确认字段、鉴权、超时和审计策略。
- 用真实行政区 GeoJSON 或高德 DistrictSearch provider 替换足迹 demo 边界。
- 补路演路线和普通对话授权切换的 UI 自动化 smoke。
- 接真实云端亲友账号和 UI：邀请发送/接受、成员撤回操作、服务端同步、访问者身份同步和离线缓存冲突处理。

P2：

- 云同步、APNs、长期关怀趋势。
- 声音克隆 speaker 绑定、撤回和审计链路。
- 处理完整 Simulator app build 的 `SpeechEngineToB` slice 限制。

## 10. 重要边界说明

当前产品表达必须保持以下边界：

- 不复活逝者。
- 不伪造亲人真实意志。
- 不做医疗诊断。
- 不展示私密原文给亲友。
- 不把 localOnly / privateOnly 内容用于远端生成或家庭同步。
- 路演 offline/mock 能力必须明确标注为演示模式。

这些边界已经进入首页演示向导、主持路线、Safety Guard 和隐私过滤实现，但仍需要真机逐屏确认文案和行为一致。
