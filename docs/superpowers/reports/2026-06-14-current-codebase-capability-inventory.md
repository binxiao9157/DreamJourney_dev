# DreamJourney 当前代码工程能力说明 - 2026-06-14

工程分支：`feature/phase2-mock-dialog-engine`
工程路径：`/Users/yxj/.config/superpowers/worktrees/DreamJourney_dev/phase2-mock-dialog-engine`
基准目标：`/Users/yxj/Documents/Codex/Video/docs/阶段一.docx` 的阶段一真机验收目标
参考状态文档：`docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md`

本文档只描述“当前代码工程已经具备的能力”和“仍需真实验证/仍未完成的能力”。自动脚本通过代表代码合约存在，不等于真实业务闭环已经通过真机验收。

## 1. 判定口径

| 状态 | 含义 |
| --- | --- |
| 已实现 | 源码中已有明确实现，并有对应验证脚本或调用链。 |
| 已接入但待验收 | 代码链路存在，但依赖真实设备、真实账号、真实素材、服务器配置或第三方服务，需要真机/线上验证。 |
| 局部实现 | 有模型、页面、脚手架或最小链路，但还不是阶段一可验收完整能力。 |
| 历史/演示能力 | 路演、mock、seed 或 fallback 相关能力仍在代码中，但只应在显式参数或测试脚本下使用，不能作为真实验收依据。 |

当前核心结论：

- App 端已经形成“对话采集 -> 记忆沉淀 -> KBLite 结构化知识库 -> 数字人 RAG 引用 -> 档案/信箱/关怀分发”的主要代码链路。
- 后端已经形成“鉴权 -> Postgres 持久化 -> KBLite/档案/信箱/亲友/关怀/地图/TTS/图片分析代理”的最小业务服务。
- 隐私分层已经进入主要数据面，`privateOnly`、`localOnly`、`generationAllowed`、`familyCircle` 会影响远端抽取、提示词、后端同步、亲友同步和关怀看板。
- 路演 seed、mock 引擎、offline demo 仍然保留在工程中，但真实模式已有 no-demo gate 和清理脚本，后续验收不应再依赖这些能力。

## 2. 工程组成

| 部分 | 代码位置 | 当前职责 |
| --- | --- | --- |
| iOS App 主工程 | `DreamJourney/` | 真实用户登录、首页语音/数字人、记忆档案馆、结构化知识库、时空信箱、亲友、关怀看板、足迹。 |
| iOS 业务服务层 | `DreamJourney/Sources/Services/` | 对话引擎、记忆沉淀、KBLite、隐私策略、后端客户端、数字人语音、信箱、档案、关怀、安全、用户身份。 |
| iOS 功能模块 | `DreamJourney/Sources/Modules/` | 各 Tab 和二级页面的 UI/交互。 |
| 后端服务 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend` | 独立 FastAPI 后端仓库，支持 Postgres/InMemory store、鉴权、第三方代理和 metadata 同步。 |
| 自动验证脚本 | `Scripts/` | 阶段一自动合约验证、后端 smoke、真机证据脚手架、隐私/演示状态回归。 |
| 证据目录 | `docs/superpowers/evidence/` | 真机验收截图、录屏、日志和后端脱敏响应的归档结构。 |
| 状态文档 | `docs/superpowers/reports/` | 阶段实现状态、开发计划、执行记录、部署说明。 |

## 3. 用户与真实模式能力

### 3.1 登录与用户身份

已实现能力：

- App 具备手机号和昵称登录入口，登录数据通过 `UserManager` 管理。
- 后端提供 `POST /auth/login`，按手机号和昵称 upsert 用户。
- 用户身份具备稳定化处理，相关验证脚本为 `Scripts/UserIdentityStabilityVerify/main.py`。
- App 配置从环境变量、`LocalConfig.plist`、`Info.plist` 合并读取，入口是 `AppConfiguration`。
- 后端业务地址使用 `DreamJourneyBackendBaseURL`，业务 API token 使用 `DreamJourneyBackendAPIToken`。

仍需注意：

- 目前不是完整账号体系，没有短信验证码、账号注销、设备迁移、用户数据合并等生产功能。
- 手机号登录页不是阶段一核心功能，但已成为真实测试账号和亲友权限链路的基础入口。

### 3.2 真实模式与演示模式隔离

已实现能力：

- `RealDeviceAcceptanceGate`、`RoadshowDemoSeed`、`MockDialogEngine`、`DigitalHumanReadinessReport` 等代码可以识别真实模式、路演 seed、offline demo、mock dialog。
- `Scripts/RealDeviceRuntimeGateVerify/main.py`、`Scripts/RealDeviceNoDemoStateVerify/main.py`、`Scripts/RealDeviceNoDemoStateTokensVerify/main.py` 用于验证真实模式不显示路演向导、不自动带 seed。
- `KBLiteManager` 和 `MemoryRepository` 含旧 seed/低质量实体清理逻辑，避免“妈妈”“路演家庭”等历史数据长期污染真实知识库。

仍需注意：

- 演示代码仍在工程里，显式启动参数或环境变量仍可能启用 seed/offline/mock。
- 后续真机测试应避免使用 `--seed-roadshow-demo`、`--roadshow-offline-mode`、`DREAMJOURNEY_SEED=roadshow_demo` 等参数。

## 4. 记忆沉淀与 KBLite 结构化知识库

### 4.1 对话记忆采集

已实现能力：

- `ConversationMemoryManager` 会记录用户/AI 回合、时间戳、语音时长、停顿次数、情绪 hint、隐私元数据。
- 每轮对话可以进入当前会话 transcript，结束会话时形成持久化记忆并触发关怀看板快照发布。
- 对话摘要围绕时间、地点、人物、事件四维结构。
- `Stage1MemoryFacade.recordUserTurn`、`recordAssistantTurn`、`finishConversationSession` 是阶段一统一入口。
- 对话结束意图和边界命令由 `DialogEndIntentPolicy`、相关验证脚本覆盖，避免“聊完了”等结束语被当作可沉淀事实。

当前限制：

- 对话记忆的抽取质量依赖用户说出的实体明确度和远端抽取可用性。
- 真机上“话没说完就打岔”的问题需要继续用真实语音验证 VAD/ASR/SDK 回调节奏，自动脚本只能覆盖代码合约。

### 4.2 KBLite 图谱

已实现能力：

- `KBLiteManager` 管理轻量知识图谱，包含人物、地点、事件、事实、sessionCount、sourceRef、隐私 metadata。
- 支持从对话 transcript 抽取结构化信息，也支持档案文本、照片分析、语音样本、时空信箱 metadata 入库。
- `KBLiteSemanticSearch` 支持语义检索，`KBLiteGapDetector` 支持知识缺口提示。
- `KBLitePrivacyScopePolicy` 根据使用场景裁剪图谱，区分本地浏览、prompt、后端同步、亲友同步、导出等 surface。
- `Stage1MemoryFacade.archiveSnapshot()` 返回本地浏览图谱，`promptArchiveSnapshot()` 返回数字人 prompt 可用的授权图谱。
- 支持 JSON 导入/导出和 PDF 导出相关能力，入口包括 `KBLitePDFExporter`、`KnowledgeBaseViewController`、`KBExportPreviewViewController`。

已有验证覆盖：

- `Scripts/KBLiteQuickExtractVerify/main.swift`
- `Scripts/KBLiteSourceRefPropagationVerify/main.swift`
- `Scripts/KBLiteArchiveMaterialMetadataVerify/main.swift`
- `Scripts/KBLiteArchiveVoiceVerify/main.swift`
- `Scripts/KBLiteTimeMailboxVerify/main.swift`
- `Scripts/KBLitePromptGraphSanitizationVerify/main.py`
- `Scripts/KBLiteBackendSnapshotVerify/main.py`
- `Scripts/KBLiteUserLifecycleVerify/main.py`
- `Scripts/KBLiteImportSanitizerVerify/main.swift`

当前限制：

- 已经有结构化知识库代码和验证，但真实素材连续沉淀后的质量仍需真机验收。
- 如果历史用户本地已有旧 UserDefaults 数据，仍可能看到旧条目，需要通过清理流程或真实账号重建验证。

## 5. 记忆档案馆能力

### 5.1 档案素材类型

已实现能力：

- 档案馆支持以下素材类型：
  - `photo`：旧照片。
  - `screenshot`：聊天截图/语音截图。
  - `voiceSample`：声音样本。
  - `textNote`：文字素材。
  - `personalityNote`：性格描述。
  - `catchphrase`：口头禅。
- `MemoryArchiveRepository` 负责本地持久化，支持新增、汇总、更新分析结果。
- 每条素材包含标题、备注、本地路径、标签、隐私范围、目标人物、声纹档案 ID、图片分析状态等字段。
- 档案建库完成度由 `MemoryArchiveBuildReadiness` 计算，当前最小条件包括：
  - 1 张可生成且已分析的旧照片。
  - 3 份可生成语音/截图证据。
  - 1 条口头禅或性格描述。
  - 至少 1 条档案来源结构化知识。

### 5.2 文本素材入库

已实现能力：

- `MemoryArchiveViewController.saveTextDraft` 保存文字素材。
- `Stage1MemoryFacade.ingestArchiveTextMaterialDetailed` 会同时写入档案 metadata 和 KBLite 结构化知识。
- 对 `privateOnly` 隐私素材不做生成型入库。
- 保存后可返回知识沉淀数量和状态文案。

仍需真机验证：

- 使用真实账号保存明确实体文本后，结构化知识库是否出现对应人物、地点、事件、事实。
- 旧 seed 数据是否已被真实数据替代。

### 5.3 照片/截图分析

已实现能力：

- 旧照片和截图会先保存到本机文件，再生成 `MemoryArchiveItem`。
- 支持通过 `DreamJourneyBackendClient.analyzeArchiveImage` 走后端 `/archive/image-analysis` 代理。
- 后端代理会调用 DeepSeek 图片分析服务，并通过 `sanitize_image_analysis_payload` 检查隐私边界。
- 本地直连 DeepSeek 的旧路径仍存在，可作为兼容 fallback。
- 图片分析结果可入 KBLite，包含摘要、人物、场景、事件/场合、情绪、年代等字段。
- 截图 OCR 有单独脚本覆盖。

已有验证覆盖：

- `Scripts/MemoryArchiveImageAnalysisProxyVerify/main.py`
- `Scripts/MemoryArchiveImageAnalysisStrictBackendVerify/main.py`
- `Scripts/MemoryArchiveImageAnalysisRetryVerify/main.py`
- `Scripts/MemoryArchiveScreenshotOCRVerify/main.py`
- `Scripts/MemoryArchiveScreenshotMaterialVerify/main.py`

当前限制：

- 真实图片分析依赖后端 DeepSeek key、网络、图片大小和接口稳定性。
- 真实验收时不允许 mock 成功；失败应展示可理解的重试/失败状态。

### 5.4 语音样本和声纹材料

已实现能力：

- `MemoryArchiveVoiceTranscriber`、`MemoryArchiveVoiceProfileStore` 支持语音转写、样本注册、声纹档案状态管理。
- 语音样本可绑定具体目标人物，样本 metadata 会进入 KBLite。
- 声纹训练要求多段样本，`MemoryArchiveVoiceTrainingSamplesVerify` 覆盖“不能只拿最新单条样本训练”。
- 数字人 TTS 可优先使用已 ready 的声纹 speakerId，入口在 `DigitalHumanSpeechService`。

已有验证覆盖：

- `Scripts/MemoryArchiveVoiceKnowledgeVerify/main.py`
- `Scripts/MemoryArchiveVoiceTranscriptBackfillVerify/main.py`
- `Scripts/MemoryArchiveVoiceAutoTranscriptionVerify/main.py`
- `Scripts/MemoryArchiveVoiceProfileVerify/main.swift`
- `Scripts/MemoryArchiveVoiceProfileSpeakerResolveVerify/main.swift`
- `Scripts/MemoryArchiveVoiceTrainingSamplesVerify/main.py`
- `Scripts/DigitalHumanVoiceProfileTTSVerify/main.py`

当前限制：

- 声纹训练/克隆依赖第三方服务和真实样本质量，当前更接近“声纹材料管理 + speakerId 绑定”能力。
- 若没有可用 speakerId，数字人口型音频会回落到配置的 `VolcEngineVoiceType` 或系统 TTS。

### 5.5 后端 metadata-only 同步

已实现能力：

- `DreamJourneyBackendClient.syncArchiveItem` 只同步 metadata。
- 上传前会删除 `localPath`、`voiceProfileId`，并标记 `metadataOnly = true`。
- 后端 `/archive/items` 会调用 `sanitize_archive_item_payload` 后保存。

当前限制：

- 后端目前不负责保存原始照片、音频本体；长期素材存储、对象存储、加密备份还未实现。

## 6. 数字人对话能力

### 6.1 实时语音对话

已实现能力：

- `DialogEngineManager` 直接封装火山 SpeechEngineToB SDK。
- 支持新版 API Key 和旧式 AppID/AppKey/AppToken 凭证。
- 支持 `VolcEngineRealtimeCredentialProvider` 从后端或本地配置读取实时对话配置。
- System prompt 已按“家族历史学家/传记作家/长辈陪伴”方向设定，包含短句、慢速、开放问题、伤痛边界、方言追问等原则。
- 支持 ASR 热词、静音超时、结束关键词、AI 打断、AI 播报状态。
- 最近系统问候有 echo filter，避免本机播报被识别成用户输入。

已有验证覆盖：

- `Scripts/VolcEngineRealtimeConfigVerify/main.swift`
- `Scripts/DialogRealtimeRAGFinalASRVerify/main.py`
- `Scripts/DialogEndIntentVerify/main.swift`
- `Scripts/DialogEndCommandMemoryBoundaryVerify/main.py`

当前限制：

- “不打断用户”最终依赖 SDK 语音活动检测、设备麦克风环境和播放暂停策略，需要真机连续对话验证。

### 6.2 记忆约束与 RAG

已实现能力：

- 数字人对话会通过 `Stage1MemoryFacade.promptContext` 注入授权知识图谱和知识缺口。
- 使用 `.prompt` surface 裁剪 KBLite 图谱，`localOnly`、`familyCircle` 不会直接进入生成型 prompt。
- 相关验证已覆盖最终 ASR 触发 RAG、payload 包含授权上下文、prompt 图谱不带未授权内容。

已有验证覆盖：

- `Scripts/DialogMemoryGroundingVerify/main.swift`
- `Scripts/DialogMemoryRAGPayloadVerify/main.swift`
- `Scripts/KBLitePromptGraphSanitizationVerify/main.py`

当前限制：

- 模型是否严格“不知道就说不知道”仍需真机真实问答验证。
- 已有 prompt 和 RAG 约束，但还不是强校验事实引擎；若后端模型自由发挥，仍可能出现幻觉，需要后续加答案引用/置信度/拒答策略。

### 6.3 数字人渲染与语音播放

已实现能力：

- App 内有数字人 WebView/资源加载、启动 ready 门禁、fallback UI、诊断 UI、运行日志和播放证据日志。
- `DigitalHumanSpeechService` 调用火山 TTS 合成 16kHz mono PCM16 WAV，用于 DHLiveMini 的口型音频输入。
- `DigitalHumanSpeechPlaybackPolicy` 对 TTS 输入做安全策略。
- 播放期间会暂停实时对话 SDK，播放结束后自动恢复聆听，避免一轮回答后断会话。
- TTS 失败时存在系统 TTS fallback 和日志。
- `DigitalHumanPlaybackEvidenceStore` 会对日志做敏感信息脱敏。

已有验证覆盖：

- `Scripts/DigitalHumanStartupRevealVerify/main.py`
- `Scripts/DigitalHumanPlaybackPolicyVerify/main.swift`
- `Scripts/DigitalHumanPlaybackInterruptVerify/main.py`
- `Scripts/DigitalHumanRealtimeResumeVerify/main.py`
- `Scripts/DigitalHumanRuntimeLogVerify/main.py`
- `Scripts/DigitalHumanReadinessVerify/main.swift`

当前限制：

- “真人数字人透明悬浮、口型与文字/音频同步”仍需要真机观察，代码层只能保证资源、播放、暂停恢复和日志合约。
- 当前数字人仍保留开源/历史资源兼容层，真实人物资产质量和最终视觉效果不是后端能力能解决的问题。

## 7. 时空信箱能力

已实现能力：

- `TimeMailboxLetter` 支持收件人、标题、正文、创建时间、投递时间、投递状态、回声文本、边界确认、隐私 metadata。
- `TimeMailboxRepository` 负责本地信件持久化。
- `TimeMailboxNotificationScheduler` 支持本地延迟通知。
- `TimeMailboxEchoService` 生成克制回声，明确声明“不是逝者真实回复”，并只引用已授权证据。
- 信箱 metadata 可进入 KBLite，便于知识库记录“给谁写过信/何时投递”。
- 后端同步为 metadata-only，`DreamJourneyBackendClient.syncMailboxLetter` 删除 `body`、`replyText` 并标记 `contentRedacted = true`。
- 后端 `/mailbox/letters` 会调用 `sanitize_mailbox_letter_payload` 保存脱敏内容。

已有验证覆盖：

- `Scripts/TimeMailboxVerify/main.swift`
- `Scripts/TimeMailboxNotificationVerify/main.py`
- `Scripts/TimeMailboxDeliveryDelayVerify/main.py`
- `Scripts/TimeMailboxAutoDeliveryRefreshVerify/main.py`
- `Scripts/TimeMailboxBackendSyncVerify/main.py`
- `Scripts/TimeMailboxPayloadPrivacyVerify/main.py`
- `Scripts/TimeMailboxTrueBackendFlowVerify/main.py`
- `Scripts/TimeMailboxKnowledgeVerify/main.py`

当前限制：

- 真实本地通知、延迟投递、跨设备 metadata 恢复需要真机验证。
- 当前没有服务端推送/APNs，不支持服务器主动跨设备提醒。

## 8. 长辈关怀看板与亲友权限

### 8.1 亲友关系与权限

已实现能力：

- `FamilyRepository`、`FamilyAccessControlService`、`FamilyAccessIdentityResolver` 支持亲友成员、邀请、接受、撤回、成员级访问状态。
- 后端支持：
  - `POST /family/invite`
  - `GET /family/members/{user_id}`
  - `POST /family/members/{user_id}/{member_id}/accept`
  - `POST /family/invitations/{invitation_code}/accept`
  - `POST /family/members/{user_id}/{member_id}/revoke`
- 邀请会生成 `dreamjourney://family/invite?code=...` deeplink。
- 撤回后的成员读取关怀快照会返回 403；近期也修复了 InMemoryStore 下撤回后直接 accept 重新激活的问题。

已有验证覆盖：

- `Scripts/FamilyAccessControlVerify/main.swift`
- `Scripts/FamilyAccessIdentityVerify/main.swift`
- `Scripts/FamilyInvitationCodeVerify/main.py`
- `Scripts/FamilyMemberAccessStateVerify/main.swift`
- `Scripts/FamilyBackendSyncVerify/main.py`
- `Scripts/FamilyCareOwnerStrictVerify/main.py`

当前限制：

- 真实亲友邀请/接受/撤回需要两台设备或至少两个账号验证。

### 8.2 关怀看板

已实现能力：

- `CareSignalAnalyzer` 只分析授权进入 `familyCircle` 的对话候选。
- 分析指标包括近 7 天窗口、用户发言轮数、字数、词汇多样性、负面情绪、睡眠、身体不适、重复率、语速/停顿、情绪波动。
- 风险级别包括 `insufficientData`、`stable`、`watch`、`attention`。
- `CareDashboardSnapshotPublisher` 会在对话结束后发布最新本地快照。
- 后端 `/care/snapshots`、`/care/snapshots/latest/{user_id}`、`/care/snapshots/{user_id}` 支持保存、读取最新、读取历史。
- 读取时可传 viewerFamilyMemberID 和 requesterPhone，后端会校验成员 active/accepted 和手机号匹配。
- 分享周报使用脱敏摘要，不展示原始 transcript。

已有验证覆盖：

- `Scripts/CareDashboardVerify/main.swift`
- `Scripts/CareDashboardSessionPublishVerify/main.py`
- `Scripts/CareDashboardTrueBackendFlowVerify/main.py`
- `Scripts/CareDashboardRequesterIdentityVerify/main.py`
- `Scripts/CareDashboardShareReportUIVerify/main.py`
- `Scripts/CareDashboardNoDuplicateMetricsVerify/main.py`
- `Scripts/CareDashboardSourceAuditVerify/main.py`

当前限制：

- 当前是规则分析和脱敏周报，不是医学诊断。
- 后续真实验收重点是：亲友看不到原始聊天、撤回后 403、7 天趋势不是 mock 数据。

## 9. 知识库与图谱页面

已实现能力：

- `KnowledgeBaseViewController` 提供人物、地点、事件、事实、图谱 Tab。
- `KBGraphViewController`、`KBGraphLayoutEngine`、`KBGraphNode`、`KBGraphEdge` 负责图谱展示。
- `KBSyncViewController` 提供家庭同步/分享包相关 UI 与隐私收据。
- `KnowledgeBaseSourcePrivacyUIVerify`、`KnowledgeGraphLiveUpdateVerify` 覆盖来源隐私 UI 和图谱更新合约。

当前限制：

- 如果真实账号本地仍有历史 seed，需要先清理或重新登录验证。
- 图谱页面目前主要是本地轻量展示，不是复杂图数据库可视化。

## 10. 家族足迹能力

已实现能力：

- `MapFootprintViewController` 使用高德地图展示家族足迹。
- `AmapDistrictBoundaryProvider`、`FamilyFootprintIllumination` 支持行政区边界点亮。
- 当前产品设定已经改为城市点亮视角，去掉上方“城市/全国/世界”可选项，保留“全家、祖辈、父辈、我们、下一代”代际切换。
- 祖辈、父辈、我们、下一代有不同代级范围和色彩深浅，用于表达家族足迹扩展。
- 本地 fallback 和高德边界缓存均存在，避免地图服务不可用时页面完全崩溃。
- 分享海报能力仍存在于 `FamilyFootprintSharePoster`。

已有验证覆盖：

- `Scripts/FamilyFootprintVerify/main.swift`
- `Scripts/FamilyFootprintIlluminationPolicyVerify/main.py`
- `Scripts/FamilyFootprintFallbackVerify/main.py`
- `Scripts/FamilyFootprintPosterVerify/main.py`

当前定位：

- 足迹已经从“路演视觉重点”降级为阶段一辅助体验。
- 后续只做真实数据和视觉回归，不再作为 P0 主线反复开发。

## 11. 安全与向阳生长能力

已实现能力：

- `SafetyMonitor` 提供本地安全识别。
- `SafetyGuardClient`、`DeepSeekSafetyGuarding` 支持远端安全评估入口和 fail-closed 策略。
- `ConversationWellbeingLimiter` 限制沉迷式对话，避免长时间无边界陪聊。
- 危机/高风险表达会进入边界流程，相关内容不会继续沉淀为普通记忆。
- `CrisisInterventionViewController` 提供危机干预 UI。
- 数字人 TTS 前会调用安全策略，安全不通过则不发送到 TTS。

已有验证覆盖：

- `Scripts/SafetyVerify/main.swift`
- `Scripts/SafetyGuardVerify/main.swift`
- `Scripts/RemoteSafetyGuardVerify/main.swift`
- `Scripts/ConversationWellbeingLimiterVerify/main.swift`
- `Scripts/ConversationWellbeingMemoryBoundaryVerify/main.py`
- `Scripts/ConversationWellbeingUIVerify/main.py`

当前限制：

- 阶段一已有本地和远端 guard 骨架，但还不是完整生产级心理危机干预系统。
- 紧急联系人、专业转介、人工介入、城市服务资源库仍未实现。

## 12. 回忆录、TTS 与声音相关能力

已实现能力：

- `MemoryRepository` 和相关回忆录逻辑仍保留，可基于对话/素材生成回忆录内容。
- DeepSeek 文本能力、火山 TTS 请求工厂、VoiceClone 相关配置均存在。
- `VolcEngineTTSRequestVerify`、`VolcEngineConfigVerify` 覆盖 TTS 请求结构和配置。
- `DigitalHumanSpeechService` 可使用 `VolcEngineAPIKey`、`VolcEngineVoiceType` 或声纹档案 ready speakerId 合成数字人口型 WAV。

当前限制：

- 回忆录生成不是当前 P0 验收主线。
- “聊完了”误触发回忆录界面的历史问题需要继续在真机真实对话中观察，避免结束意图和生成入口混淆。

## 13. 后端服务能力

### 13.1 接口能力

当前后端独立仓库的 `app/main.py` 提供以下主要接口：

| 接口 | 能力 |
| --- | --- |
| `GET /health` | 健康检查，返回环境和 store 类型。 |
| `POST /auth/login` | 手机号/昵称登录或 upsert 用户。 |
| `GET /config/runtime` | 返回脱敏运行时配置状态。 |
| `POST /voice/realtime-token` | 返回火山实时对话配置。 |
| `POST /tts` | 代理火山 TTS，支持 dryRun 脱敏请求预览。 |
| `GET /maps/district` | 代理高德行政区查询，支持 dryRun 脱敏 URL。 |
| `POST /kb/sync` | 保存过滤后的 KBLite 图谱快照。 |
| `GET /kb/snapshot/{user_id}` | 读取用户 KBLite 图谱快照。 |
| `POST /kb/extract` | 代理 DeepSeek 结构化知识抽取。 |
| `POST /memories` / `GET /memories/{user_id}` | 基础记忆记录保存/读取。 |
| `POST /archive/photos` / `POST /archive/items` / `GET /archive/items/{user_id}` | 档案 metadata 保存/读取。 |
| `POST /archive/image-analysis` | 代理 DeepSeek 图片分析。 |
| `POST /mailbox/letters` / `GET /mailbox/letters/{user_id}` | 信箱 metadata-only 保存/读取。 |
| `POST /family/invite` | 创建亲友邀请。 |
| `GET /family/members/{user_id}` | 读取亲友列表。 |
| `POST /family/members/{user_id}/{member_id}/accept` | 指定成员接受邀请。 |
| `POST /family/invitations/{invitation_code}/accept` | 邀请码接受。 |
| `POST /family/members/{user_id}/{member_id}/revoke` | 撤回亲友权限。 |
| `POST /care/snapshots` | 保存脱敏关怀快照。 |
| `GET /care/snapshots/latest/{user_id}` | 读取最新关怀快照。 |
| `GET /care/snapshots/{user_id}` | 读取关怀快照历史。 |

### 13.2 存储能力

已实现能力：

- 后端支持 `STORE_BACKEND=postgres` 和 `STORE_BACKEND=memory`。
- Postgres store 会保存 users、kb_snapshots、memories、archive_items、mailbox_letters、family_members、care_snapshots 等数据。
- InMemory store 用于本地单测和临时调试，进程重启丢数据。
- 独立后端仓库的 `tests/test_core_services.py` 和 `tests/test_postgres_store.py` 覆盖核心服务和 Postgres store 行为。

当前限制：

- 生产长期测试应使用 Postgres，不应使用 memory store。
- 备份、迁移、数据清理策略仍需服务器层面落实。

### 13.3 后端鉴权与脱敏

已实现能力：

- 除 `/health` 外，配置 `BACKEND_API_TOKEN` 后所有接口都会校验 `Authorization: Bearer ...` 或 `X-DreamJourney-API-Token`。
- `Scripts/BackendAuthenticatedSmoke/main.py` 支持本地和远端鉴权 smoke。
- 后端 privacy 服务会处理：
  - KBLite `localOnly` 过滤。
  - archive metadata-only。
  - mailbox 正文/回声删除。
  - care snapshot 原始 transcript 清理。
  - DeepSeek 图片/知识抽取请求上下文脱敏。
  - runtime 配置只返回 configured/missing，不返回 key 原值。

已有验证覆盖：

- `Scripts/DreamJourneyBackendAuthVerify/main.py`
- `Scripts/BackendAuthenticatedSmoke/main.py`
- `Scripts/BackendAuthenticatedSmokeContractVerify/main.py`

当前限制：

- 线上服务器是否已配置 `BACKEND_API_TOKEN`、HTTPS、CORS、日志脱敏、备份，需要按部署文档继续验收。

## 14. 隐私分层能力

当前核心模型在 `MemoryPrivacyScope.swift`：

| 隐私范围 | 当前含义 |
| --- | --- |
| `privateOnly` | 完全不进入生成、后端、家庭、导出等链路。 |
| `localOnly` | 只允许本地对话和时空信箱回声，不允许远端抽取、prompt、后端同步、亲友同步。 |
| `generationAllowed` | 允许远端抽取、prompt、回忆录、信箱回声、后端同步，但不进入亲友/关怀。 |
| `familyCircle` | 允许本地对话、关怀看板、亲友同步、后端同步，但不进入生成型 prompt 和远端抽取。 |

当前主要使用面：

| Surface | 用途 |
| --- | --- |
| `conversation` | 本地对话使用。 |
| `remoteExtraction` | 发给远端模型做结构化抽取/图片分析。 |
| `prompt` | 数字人 RAG prompt 使用。 |
| `memoirGeneration` | 回忆录生成使用。 |
| `timeMailboxEcho` | 信箱边界回声使用。 |
| `export` / `widget` | 导出和小组件使用。 |
| `careDashboard` | 亲友关怀看板使用。 |
| `familySync` | 家庭同步使用。 |
| `backendSync` | 后端 metadata/snapshot 同步使用。 |

已实现边界：

- 后端同步前会根据 `backendSync` 过滤。
- prompt 注入前会根据 `prompt` 裁剪。
- 关怀看板会根据 `familyCircle` 和具体成员可见性裁剪。
- 对外分享、导出、证据日志会尽量避免正文、完整 transcript、API key、token 泄露。

当前限制：

- 隐私模型已经进入主要链路，但仍需真实数据抽查，确认所有 UI 和后端响应都符合预期。

## 15. 自动验证与证据能力

### 15.1 总验证入口

主入口：

```bash
bash Scripts/verify_phase1.sh
```

覆盖范围包括：

- SafetyMonitor 和远端安全 guard。
- 时空信箱、本地通知、延迟投递、后端同步、payload privacy。
- 记忆档案馆、图片分析、截图 OCR、语音转写、声纹样本、后端 metadata。
- 长辈关怀看板、脱敏快照、亲友权限、撤回、周报。
- 后端鉴权、核心服务、Postgres KBLite persistence。
- 数字人启动、TTS/播放策略、实时恢复、诊断、日志。
- KBLite 抽取、sourceRef、prompt 图谱、后端快照、多用户生命周期。
- 真实模式 no-demo state、本地测试数据清理、iPhoneOS Debug build。

### 15.2 真机证据脚手架

已实现：

- `Scripts/phase1_acceptance_evidence_scaffold.py`
- `Scripts/Phase1AcceptanceEvidenceScaffoldVerify/main.py`

证据目录：

- `docs/superpowers/evidence/phase1-memory-archive/`
- `docs/superpowers/evidence/phase1-digital-human-grounding/`
- `docs/superpowers/evidence/phase1-care-dashboard/`
- `docs/superpowers/evidence/phase1-time-mailbox/`
- `docs/superpowers/evidence/phase1-backend-smoke/`
- `docs/superpowers/evidence/phase1_acceptance_manifest.json`
- `docs/superpowers/evidence/phase1_acceptance_checklist.md`

当前限制：

- 脚手架已创建，但真实截图、录屏、设备日志、后端脱敏响应仍需要人工真机测试填入。

## 16. 历史/演示能力清单

这些能力仍存在，但后续真实验收不应依赖：

| 能力 | 代码/脚本 | 当前处理方式 |
| --- | --- | --- |
| 路演 seed 数据 | `RoadshowDemoSeed` | 只在显式参数/env 下启用。 |
| Mock 语音对话引擎 | `MockDialogEngine` | 只用于测试/offline/demo fallback。 |
| 路演路线和证据包 | `RoadshowDemoRoute`、`Roadshow*Verify` | 历史路演资产，非真实验收主线。 |
| Roadshow offline mode | `DREAMJOURNEY_ROADSHOW_OFFLINE` | 真实真机测试必须关闭。 |
| 足迹分享海报 | `FamilyFootprintSharePoster` | 辅助体验，不作为 P0。 |
| OpenAvatarChat 兼容配置 | `OpenAvatarChatBaseURL`、`OpenAvatarChatService` | 不承载 DreamJourney 业务数据。 |

## 17. 当前仍需真实验证的能力

| 优先级 | 能力 | 真实验收点 |
| --- | --- | --- |
| P0 | 记忆档案馆真实素材建库 | 真实文本、照片、语音保存后进入档案馆和 KBLite；后端只保存 metadata；失败不 mock 成功。 |
| P0 | 数字人记忆约束 | 能引用已授权事实；未沉淀事实不编造；连续 3-5 轮不抢话；播放后继续聆听。 |
| P1 | 长辈关怀看板 | 双账号/双设备邀请、接受、撤回；子女只看脱敏指标；撤回后 403。 |
| P1 | 时空信箱 | 延迟投递、本机通知、边界回声、后端 metadata-only、跨设备不恢复正文。 |
| P2 | 后端线上 smoke | HTTPS、API token、Postgres、runtime 脱敏、DeepSeek/Volc/AMap 代理状态。 |
| P2 | 安全服务生产化 | 远端 safety guard、紧急联系人、专家转介、日志和隐私审计。 |
| P2 | 证据包归档 | 把截图、录屏、日志、后端脱敏响应填入 evidence 目录。 |

## 18. 当前不完整或未实现的阶段一外延

| 项目 | 当前状态 |
| --- | --- |
| 完整生产账号体系 | 未实现短信验证、账号注销、权限审计后台。 |
| 云端原始素材存储 | 未实现；当前主要是本地素材 + 后端 metadata。 |
| APNs/服务端推送 | 未实现；信箱使用本地通知。 |
| 专家/热线转介闭环 | 未实现；只有本地/远端安全 guard 和危机 UI 骨架。 |
| 独立适老终端/小程序/音箱端 | 未实现；只有 App 内一键对话和关怀链路原型。 |
| 完整数字人资产生产链 | 未实现；当前为已有资源/兼容层 + TTS/口型播放链路。 |
| 生产级监控与备份 | 未实现；服务器部署文档已有方向，仍需配置和验收。 |

## 19. 关键文件索引

### iOS 核心服务

| 能力 | 文件 |
| --- | --- |
| 配置读取 | `DreamJourney/Sources/Services/AppConfiguration.swift` |
| 后端客户端 | `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift` |
| 隐私模型 | `DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift` |
| KBLite 隐私裁剪 | `DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift` |
| 记忆沉淀统一入口 | `DreamJourney/Sources/Services/Stage1MemoryFacade.swift` |
| 对话记忆 | `DreamJourney/Sources/Services/ConversationMemoryManager.swift` |
| 结构化知识库 | `DreamJourney/Sources/Services/KBLiteManager.swift` |
| 实时对话引擎 | `DreamJourney/Sources/Services/DialogEngineManager.swift` |
| 数字人语音 | `DreamJourney/Sources/Services/DigitalHumanSpeechService.swift` |
| 数字人播放策略 | `DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift` |
| 档案仓库 | `DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift` |
| 声纹档案 | `DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift` |
| 时空信箱 | `DreamJourney/Sources/Services/TimeMailbox/` |
| 关怀分析 | `DreamJourney/Sources/Services/CareDashboard/` |
| 亲友权限 | `DreamJourney/Sources/Services/FamilyRepository.swift`、`FamilyAccessControlService.swift` |
| 安全 | `DreamJourney/Sources/Services/Safety/`、`ConversationWellbeingLimiter.swift` |

### iOS 页面模块

| 页面 | 文件 |
| --- | --- |
| 首页/语音数字人 | `DreamJourney/Sources/Modules/Home/` |
| 记忆档案馆 | `DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift` |
| 结构化知识库 | `DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift` |
| 图谱 | `DreamJourney/Sources/Modules/Knowledge/KBGraphViewController.swift` |
| 时空信箱 | `DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift` |
| 亲友 | `DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift` |
| 亲友可见性选择 | `DreamJourney/Sources/Modules/Family/FamilyVisibilityPickerViewController.swift` |
| 关怀看板 | `DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift` |
| 足迹 | `DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift` |

### 后端

| 能力 | 文件 |
| --- | --- |
| FastAPI 入口 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py` |
| 配置 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/core/config.py` |
| Postgres store | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py` |
| InMemory store | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/in_memory_store.py` |
| 隐私清洗 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/privacy.py` |
| DeepSeek 代理 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/deepseek.py` |
| 火山 TTS 代理 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/tts.py` |
| 火山实时 token | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/tokens.py` |
| 高德代理 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/amap.py` |
| 运行时配置 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/runtime_config.py` |
| 用户身份 | `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/user_identity.py` |

### 验证与证据

| 能力 | 文件 |
| --- | --- |
| 阶段一总验证 | `Scripts/verify_phase1.sh` |
| 后端鉴权 smoke | `Scripts/BackendAuthenticatedSmoke/main.py` |
| 真机证据脚手架 | `Scripts/phase1_acceptance_evidence_scaffold.py` |
| 证据脚手架验证 | `Scripts/Phase1AcceptanceEvidenceScaffoldVerify/main.py` |
| 阶段一证据目录 | `docs/superpowers/evidence/` |
| 当前阶段计划 | `docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md` |

## 20. 结论

当前代码工程已经不是单纯 demo 工程，阶段一核心底座基本成型：真实模式、记忆沉淀、结构化知识库、档案馆、信箱、亲友关怀、数字人 RAG、后端 metadata 服务和隐私分层都有实现。

真正的剩余工作不应继续堆新页面，而是按 P0/P1 做真实验收：

1. 用真实账号和真实素材跑通记忆档案馆建库。
2. 验证数字人只引用已授权记忆，不自由编造。
3. 验证亲友关怀只给脱敏聚合，不泄露原始聊天。
4. 验证时空信箱正文不出端，回声有边界。
5. 验证线上后端鉴权、Postgres 和第三方代理稳定可用。

这份文档后续可作为“当前工程能力基线”。如果继续开发，应优先更新验收证据和缺口状态，而不是重复开发已经封板的路演、足迹或冷启动问题。
