# 阶段一持续推进记录 - 2026-06-13

目标：向 `docs/阶段一.docx` 的阶段一产品规划靠拢，优先保证真机可验收的核心闭环。

## 本轮完成

### 1. 记忆档案馆：补齐语音素材入口

- `MemoryArchiveItemKind` 新增 `voiceSample`。
- 档案馆首页新增“导入语音素材”入口，通过系统文件选择器导入音频。
- 导入音频会复制到 App 沙盒 `Documents/archive_voice_samples`，不再只是占位记录。
- 语音素材沿用四档隐私：
  - 私密：只留档案馆。
  - 本机：只本机保存。
  - 可生成：仅沉淀“语音样本元信息”，不把音频正文当作对话共享。
  - 亲友：需要继续选择亲友可见范围。
- 档案馆统计新增“语音”数量。

### 2. 记忆档案馆：文本素材保存后立即进入结构化抽取

- 新增 `Stage1MemoryFacade.ingestArchiveTextMaterial`。
- 档案馆保存非私密文本素材后，会立即触发 KBLite 抽取。
- 私密素材仍只保存在档案馆，不进入结构化知识库。
- 这解决了“保存明确实体信息后，结构化知识库没有生成”的主要链路问题。

### 3. 时空信箱：回声接入授权记忆证据

- `TimeMailboxRepository.refreshDelivery` 支持传入 `TimeMailboxEchoEvidence`。
- App 运行时从 `KBLiteManager.sanitizedGraph(for: .timeMailboxEcho)` 取授权图谱。
- 回声有匹配记忆时会列出“我能参考到的已授权记忆”。
- 没有匹配记忆时明确说明“不会替Ta编造具体经历”。
- 所有回声继续保留“不是逝者真实回复”的边界声明。

### 4. 时空信箱：未来投递本机提醒

- 新增 `TimeMailboxNotificationScheduler`。
- 用户封存未来投递信件时，会通过 `UNUserNotificationCenter` 注册本机通知。
- 通知只包含“一封封存的信已到达”的通用提示，不暴露收件人姓名、信件正文或回声内容。
- 打开信箱仍会刷新投递状态，通知只是提醒用户回到信箱查看。

### 5. 数字人首帧切换修复仍保留

- 真视频/画布首帧未 ready 前，不再先显示假的 fallback 人像再切换。
- spinner 文案保持“正在准备真人数字人”，直到真实视频首帧 ready。

### 6. 演示数据污染检查

- `RoadshowDemoSeed.applyIfRequested` 只有在显式启动参数或环境变量存在时才会注入演示数据：
  - `--seed-roadshow-demo`
  - `--reset-roadshow-demo`
  - `--roadshow-offline-mode`
  - `DREAMJOURNEY_SEED=roadshow_demo`
  - `DREAMJOURNEY_RESET_DEMO=1`
  - `DREAMJOURNEY_ROADSHOW_OFFLINE=1`
- 足迹页当前 `shouldIncludeDemoExpansion` 默认为 `false`，真实模式不会合并 roadshow expansion points。
- 如果真机仍看到旧路演家庭/妈妈/示例足迹，大概率来自旧安装残留容器数据，可在数字人诊断页使用“清理本机测试数据”入口处理。

### 7. 真机测试数据清理入口

- 数字人诊断页新增“清理本机测试数据”，带二次确认。
- 清理范围：路演 seed/offline 标记、时空信箱、记忆档案、足迹已读/弹跳状态、路演路线完成状态、对话记忆、KBLite 本机图谱、归档照片、归档语音素材、回忆录本机目录。
- 不清理范围：API Key、后端地址、登录信息和服务器数据。
- 本机清理调用 `KBLiteManager.reset(syncToBackend: false)`，不会把空知识库同步到业务后端。
- 新增 `Scripts/LocalTestDataCleanupVerify/main.py`，并接入 `Scripts/verify_phase1.sh`。

### 8. 长辈关怀看板：脱敏快照后端闭环

- 后端新增 `care_snapshots` 存储：
  - `POST /care/snapshots`
  - `GET /care/snapshots/latest/{user_id}`
  - 支持 `viewerFamilyMemberID` 区分全家视角和指定亲友视角。
- iOS `DreamJourneyBackendClient` 新增 `syncCareSnapshot` 和 `fetchLatestCareSnapshot`。
- `CareDashboardViewController` 行为：
  - 本机有真实可见对话时，本地生成 `CareSignalSnapshot` 并上传脱敏聚合快照。
  - 本机无可用对话时，尝试拉取后端最近快照作为真实测试兜底。
  - 页面会显示数据来源：`本机近况` 或 `服务器同步快照`。
- 边界：不上传原始 transcript，不上传私密/localOnly 对话，只上传看板聚合结果。

### 9. 亲友圈：成员 create/list 接入业务后端

- `DreamJourneyBackendClient` 新增：
  - `POST /family/invite`
  - `GET /family/members/{userId}`
  - `POST /family/members/{userId}/{memberId}/accept`
  - `POST /family/members/{userId}/{memberId}/revoke`
- `FamilyRepository` 新增后端同步入口：
  - 打开亲友页时拉取服务器成员并合并到本地列表。
  - 输入手机号复制邀请时先在后端创建亲友成员，再生成邀请文案。
  - 接受邀请时优先调用后端 accept，并校验手机号。
  - 撤回访问时优先调用后端 revoke，后端返回 revoked 状态后再同步本地可见性。
- 去掉亲友页邀请文案里的硬编码路演手机号 `18800000001`。
- 亲友列表高度改为随成员数量动态刷新，避免后端拉到成员后列表显示不全。
- 当前边界：后端仍是 member 级 accept/revoke，尚未拆成独立 invitation code/deeplink 状态机。

### 10. 记忆档案馆：档案条目元数据后端闭环

- 后端新增通用档案 API：
  - `POST /archive/items`
  - `GET /archive/items/{userId}`
- `archive_items` 原有 Postgres 表正式补齐 list 能力，InMemoryStore 也提供同样行为，方便本地和服务器一致测试。
- 服务端新增 `sanitize_archive_item_payload`：
  - 拒绝 `privateOnly` / `localOnly` 档案素材。
  - 允许 `generationAllowed` / `familyCircle` 进入自有业务后端。
  - 强制移除 `localPath`、`fileURL`、`absolutePath`，只保存元数据和已授权文本/分析摘要，不上传图片或音频本体。
- iOS `DreamJourneyBackendClient` 新增：
  - `syncArchiveItem(userId:item:)`
  - `fetchArchiveItems(userId:)`
- 档案馆保存文字、照片、语音素材后，会在后端已配置且用户已登录时同步授权元数据。
- 档案馆页面新增“服务器同步”状态行：
  - 未配置后端时显示“当前仅本机保存”。
  - 未登录时提示登录后同步。
  - 有已授权素材时会拉取后端档案条目数量，显示“服务器已有 x 份 / 本机已授权 y 份”和最近确认时间。
  - 同步失败时明确提示“本机副本已保存”，不阻断建库。
- 隐私策略同步修正：`backendSync` 现在表示“同步到自有后端长期保存/联调”，不是公开分享；私密和本机素材仍不出端。

### 11. 长辈关怀看板：历史脱敏快照后端拉取

- 后端新增 `GET /care/snapshots/{userId}`，支持：
  - `viewerFamilyMemberID`：按亲友成员视角过滤。
  - `limit`：返回最近 N 条，服务端限制在 1-30。
- InMemoryStore 和 PostgresStore 都新增 `list_care_snapshots`，与 `latest` 逻辑保持同一视角过滤。
- iOS `DreamJourneyBackendClient` 新增 `fetchCareSnapshotHistory`。
- 关怀看板在本机无可用 familyCircle 对话时，优先拉取后端历史快照列表：
  - 有历史时使用最新一条渲染页面，数据源显示为“服务器同步历史 x 条”。
  - 历史为空或请求失败时，再回落到原来的 latest 快照兜底。
- 仍只展示脱敏聚合信号，不拉取或显示原始 transcript。

### 12. 时空信箱：授权信件元数据后端同步

- 后端新增通用信箱元数据 API：
  - `POST /mailbox/letters`
  - `GET /mailbox/letters/{userId}`
- `mailbox_letters` Postgres 表和 InMemoryStore 同步补齐，按信件 `id` upsert，避免“立即投递”后 sealed 状态覆盖 delivered/read 状态。
- 服务端新增 `sanitize_mailbox_letter_payload`：
  - 拒绝 `privateOnly` / `localOnly` 信件。
  - 允许 `generationAllowed` / `familyCircle` 的信件元数据进入自有业务后端。
  - 强制移除完整 `body`、`replyText` 和派生 `bodyPreview`，只保存标题、收件人、投递时间、状态、边界确认和隐私范围等元数据。
- iOS `DreamJourneyBackendClient` 新增：
  - `syncMailboxLetter(userId:letter:)`
  - `fetchMailboxLetters(userId:)`
- 信箱页新增“服务器同步”状态行：
  - 未配置后端时说明完整正文和回声仅本机保存。
  - 已配置并登录时显示服务器已有信件元数据数量、本机授权数量。
  - 封存、到点投递、已读状态变化后都会尝试同步授权信件元数据。
- 边界：完整正文、回声文本、本机/私密信件仍不出端。

### 13. 记忆档案馆：旧照片分析优先走业务后端代理

- 后端新增 DeepSeek 图片分析代理：
  - `POST /archive/image-analysis`
  - `dryRun=true` 可返回脱敏后的上游请求，便于服务器部署后自检。
- 新增 `DeepSeekImageAnalysisProxy`：
  - 服务端持有 `DEEPSEEK_API_KEY`，不再要求真机直接持有图片分析密钥。
  - 统一构造 Vision 请求，解析严格 JSON 或从模型输出中抽取 JSON 子串。
  - 返回结构保持与 iOS `KBImageAnalysisResult` 一致：`description`、`detectedPeople`、`scene`、`occasion`、`mood`、`estimatedDecade`。
- iOS `DreamJourneyBackendClient` 新增 `analyzeArchiveImage(imageBase64:)`。
- 档案馆照片分析改为：
  - 已配置 `DreamJourneyBackendBaseURL`：优先走业务后端代理。
  - 后端不可用或未配置：回落到原本本机 `DeepSeekService.analyzeImage`。
- 失败时仍标记 `analysisStatus=failed`，不会用 mock 结果假装分析成功。

### 14. 亲友邀请：邀请码与 deeplink 真实跨设备闭环

- 后端 `POST /family/invite` 现在会生成：
  - `invitationCode`
  - `invitationURL = dreamjourney://family/invite?code=...`
- 后端新增 `POST /family/invitations/{invitationCode}/accept`：
  - 接受端只需提交当前登录手机号。
  - 手机号不匹配时拒绝。
  - 已撤回的邀请不会被旧邀请码重新激活。
  - 已接受的邀请可幂等返回 active 状态。
- InMemoryStore 和 PostgresStore 都支持按 `invitationCode` 接受邀请；Postgres 新增 `idx_family_members_invitation_code` 表达式索引。
- iOS `DreamJourneyBackendClient` 新增 `acceptFamilyInvitationCode`。
- `FamilyRepository` 新增：
  - `FamilyInvitationShare`：复制邀请文案时带邀请码和 deeplink。
  - `invitationCode(from:)`：支持纯邀请码、`dreamjourney://family/invite?code=...` 和粘贴文本中提取 code。
  - `acceptBackendInvitationCode`：用当前登录手机号调用后端接受，不再要求本机先有该成员。
- iOS 注册 `dreamjourney://` URL Scheme：
  - 冷启动/热启动 URL 会缓存 pending code。
  - 登录后进入主 Tab 会自动切到亲友页并尝试接受邀请。
- 亲友页输入框现在支持“手机号 / 邀请码 / 邀请链接”三种接受方式。

### 15. 数字人：启动首帧淡入，减少打开应用的明显切换

- 定位根因：`DigitalHumanAvatarView` 的 WKWebView 首次加载时会先显示 web 壳层、loading 文案，再等 DHLive 首帧后切到真人 canvas；`MiniMateLoader.js` 还会提前把 `screen2` 置为可见。
- iOS `DigitalHumanAvatarView` 现在默认让 WKWebView 透明：
  - 只在收到 `avatar_video_surface_ready` 后，180ms 淡入真人数字人。
  - `avatar_first_frame_drawn` 仅保留为诊断事件，避免 DOM 尚未完成 video-ready 状态时过早露出 loading 壳层。
  - 如果 2.8 秒内没有首帧，只记录 `avatar_startup_waiting_for_video` 诊断，不再把 loading 壳层揭到用户面前，避免“先加载壳、再真人”的明显切换。
  - 启动显隐过程写入 `DigitalHumanPlaybackEvidenceStore`，真机诊断可追踪。
- Web 资源 `MiniMateLoader.js` 不再抢先显示 `screen2`，改由首帧 ready 统一接管。
- HTML 中 `#screen2` 默认保持隐藏，真人 canvas 仍由 `body[data-video-ready="true"]` 控制透明淡入。
- 新增 `Scripts/DigitalHumanStartupRevealVerify/main.py`，并纳入 `Scripts/verify_phase1.sh`。

### 16. KBLite：后端快照恢复与用户生命周期隔离

- iOS `DreamJourneyBackendClient` 新增 `fetchKnowledgeBaseSnapshot(userId:)`，对齐后端已有 `GET /kb/snapshot/{user_id}`。
- `KBLiteManager` 新增 `bootstrapFromBackendIfNeeded`：
  - 主 Tab 启动后，如果已配置 `DreamJourneyBackendBaseURL` 且用户已登录，会尝试拉取服务器 KBLite 图谱快照。
  - 只补齐可同步图谱，不覆盖本机私密/localOnly 数据。
  - 拉取失败只写日志，不阻断本机建库。
- `KBLiteManager.applyRemoteSnapshotIfUseful` 支持按人物、地点、事件、事实合并服务器快照，避免同一实体重复堆叠。
- `UserManager.login` 登录后会强制 `reloadForCurrentUser`，`logout` 后会 `clearForLoggedOutUser`：
  - 避免 KBLite 单例在未登录时加载 `kb_graph_default.json` 后，把旧 default/路演残留写入真实用户图谱。
  - 退出登录后只清空内存态，不把空图谱同步到服务器。
- 新增并纳入 `verify_phase1.sh`：
  - `Scripts/KBLiteBackendSnapshotVerify/main.py`
  - `Scripts/KBLiteUserLifecycleVerify/main.py`

### 17. 记忆档案馆：语音素材元信息进入结构化知识库

- `KBLiteManager.ingestArchiveVoiceSampleMetadata` 新增“语音样本元信息”事实入库：
  - 只记录“保存了哪份语音素材、用途是什么”。
  - 不把音频本体或未转写内容当作用户对话。
  - 不从标题中臆造人物、地点、事件。
  - 同一标题重复导入会合并，不重复生成多条事实。
- `Stage1MemoryFacade.ingestArchiveVoiceSampleMetadata` 作为统一入口，档案馆保存非私密语音素材后调用。
- `MemoryArchiveViewController.savePickedVoiceSample` 不再用 `recordUserTurn` 伪装成对话沉淀，改为专门的档案素材元信息入库。
- 新增并纳入 `verify_phase1.sh`：
  - `Scripts/KBLiteArchiveVoiceVerify/main.swift`
  - `Scripts/MemoryArchiveVoiceKnowledgeVerify/main.py`

### 18. 时空信箱：信件元信息进入结构化知识库

- `KBLiteManager.ingestTimeMailboxLetterMetadata` 新增“信件元信息”事实入库：
  - 记录收件人、标题、计划投递时间和信件来源。
  - 通过 `MemorySourceRef(kind: .timeMailboxLetter, id: letter.id)` 做去重锚点。
  - 不保存完整正文，不保存回声文本。
  - privateOnly 信件不入库；localOnly 信件只保留本机可见；generationAllowed / familyCircle 才按既有隐私策略进入后续链路。
- `Stage1MemoryFacade.ingestTimeMailboxLetterMetadata` 作为统一入口。
- `TimeMailboxViewController.sealLetter` 在封存信件后沉淀元信息，同时继续走原有后端 metadata-only 同步。
- 新增并纳入 `verify_phase1.sh`：
  - `Scripts/KBLiteTimeMailboxVerify/main.swift`
  - `Scripts/TimeMailboxKnowledgeVerify/main.py`

### 19. 本次继续推进补充：真实验收门禁与残留清理

- 记忆档案馆文本/照片素材保存后，会沉淀“档案素材元信息”到 KBLite，并通过 `MemorySourceRef(kind: .memoryArchiveItem)` 保留来源锚点；不会把照片本体、音频本体或未授权正文伪装成对话。
- KBLite 导入和多用户合并链路会清理历史路演/示例图谱残留，降低旧容器、旧分享包把 `妈妈`、示例亲友、路演照片重新带回真实测试的风险。
- 对话记忆的用户轮次和 AI 轮次都会追加 `conversationTurn` 来源引用，结构化知识库能追踪事实来源，而不是只给出无出处实体。
- 清理本机测试数据时会同步移除派生亲友成员，避免路演亲友残留在真实账号下继续显示。
- 真机证据扫描新增更多 forbidden token，包含路演亲友 ID、陈岚/陈浩/陈予、外滩老照片、`roadshow_demo_photo_placeholder`。
- 长辈关怀看板在 `insufficientData` 或 0 轮真实用户发言时不允许分享周报；页面只显示“等待真实关怀数据”，提示先用「亲友范围」完成真实对话。
- 时空信箱本机通知不再暴露收件人姓名；后端同步继续保持 metadata-only，不包含 `body`、`replyText` 或 `bodyPreview`。
- 数字人启动超时不再显示 loading 壳层；只有真人 video surface ready 后才淡入。

### 20. 向阳生长：渐进式脱敏锁首版

- 新增 `ConversationWellbeingLimiter`，按本轮连续使用时长和最终用户发言轮次给出三档决策：
  - `allow`：正常继续。
  - `nudge`：接近阈值时给出一次温和提醒，引导用户喝水、休息、看看外面的世界。
  - `limit`：超过阈值后阻止继续开麦，并把当前会话安全收尾。
- UI 接入点放在两个空档：
  - 开麦前检查，避免用户已经超过硬限制还继续录音。
  - AI 播放结束后检查，避免在用户讲话中途打断。
- 脱敏锁不替代 `SafetyMonitor`：
  - 生命风险表达仍走全屏危机干预。
  - 脱敏锁只处理“聊太久/太频繁”的节制边界。
- 脱敏锁提醒使用 `TGMessage.wellbeingNotice`：
  - 页面上可见，但不写入 `Stage1MemoryFacade`。
  - 回忆录生成前会过滤 `wellbeingNotice`，避免“今天先到这里”等边界提示污染记忆沉淀。
- 新增并纳入 `verify_phase1.sh`：
  - `Scripts/ConversationWellbeingLimiterVerify/main.swift`
  - `Scripts/ConversationWellbeingUIVerify/main.py`
  - `Scripts/ConversationWellbeingMemoryBoundaryVerify/main.py`

### 21. 记忆档案馆：人格线索与口头禅关联到具体人物

- `KBLiteManager.ingestArchiveTextMaterialMetadata` 增强“性格描述 / 口头禅 / 人格线索”素材处理：
  - 如果标题能识别出具体姓名，例如“林桂芳的性格”，会创建或复用 `KBPerson`。
  - 档案事实会写入 `relatedPersonIds`，让数字人 prompt 的“相关人物 -> 关联事实”能稳定带出这些线索。
  - 通用亲属称呼如“妈妈 / 奶奶”仍不会被当作具体人物写入，避免泛称或旧测试残留污染图谱。
- 这使阶段一“人格 prompt text / 口头禅素材”不再只是普通文字事实，而能进入人物维度检索：
  - 用户问“林桂芳平时怎么说话”时，prompt context 可以带出“她慢性子，说话轻声细语，常说慢慢来”等档案事实。
- `Scripts/KBLiteArchiveMaterialMetadataVerify/main.swift` 增加覆盖：
  - 人格素材创建/复用具体人物。
  - 档案事实保留 `memoryArchiveItem` 来源锚点。
  - prompt context 能检索到人格线索内容。

### 22. 记忆档案馆：语音样本形成按人物声纹档案

- 新增 `MemoryArchiveVoiceProfileStore`：
  - 语音样本保存后可绑定具体人物姓名，3 段同一人物语音进入 `readyForTraining`。
  - 泛称如“妈妈 / 奶奶”不会创建声纹档案，避免再次把测试泛称污染成真实人物。
  - `speakerId` 只保存在本机人物声纹档案中，不写入 KBLite fact，也不作为档案元数据同步到业务后端。
- 记忆档案馆导入语音流程增强：
  - 先询问“这是谁的声音”，再选择私密 / 本机 / 可生成 / 亲友范围。
  - 可生成范围下，样本足够后会用人物声纹 profile 发起训练；训练失败不阻塞素材归档。
  - 亲友范围仍仅同步脱敏元数据，不把音频或声纹凭证共享给亲友链路。
- `VoiceCloneService.trainVoice` 增加 `persistAsCurrent`：
  - 旧回忆录兜底调用默认保持全局 speakerId 行为。
  - 人物声纹档案训练传 `persistAsCurrent: false`，避免某位长辈音色覆盖整个 App 的全局默认音色。
- KBLite 语音元信息增强：
  - 无明确人物时仍只保存 catalog fact，不凭空造人。
  - 有明确人物时创建/复用 `KBPerson`，并把语音样本 fact 写入 `relatedPersonIds`，可被后续 prompt context 检索。
- 新增/增强验证：
  - `Scripts/MemoryArchiveVoiceProfileVerify/main.swift`
  - `Scripts/VoiceCloneProfilePersistenceVerify/main.py`
  - `Scripts/KBLiteArchiveVoiceVerify/main.swift`

### 23. 长辈关怀看板：亲友访问状态进入快照读写入口

- 后端 `care/snapshots` 入口增加亲友访问校验：
  - `viewerFamilyMemberID` 为空时仍表示本人 / 全家视角，不走亲友成员校验。
  - `viewerFamilyMemberID` 指向亲友成员时，必须同时满足 `accessStatus=active` 和 `invitationStatus=accepted`。
  - `pending`、未知成员、`revoked` 成员不能上传、读取最新快照或读取历史快照。
- 这把阶段一“亲友关怀看板”的隐私闭环从“前端裁剪 + 内容脱敏”推进到“后端读写入口也承认邀请 / 撤回状态”：
  - 已撤回亲友即使保留旧 `viewerFamilyMemberID`，也无法继续读取历史聚合信号。
  - 待接受邀请的成员不能提前看到或写入看板数据。
- `DreamJourneyBackend/tests/test_core_services.py` 增加覆盖：
  - pending / unknown / revoked 亲友访问返回 403。
  - accepted + active 亲友可以写入并读取自己的看板快照。
- `Scripts/CareDashboardBackendSyncVerify/main.py` 增加静态验收锚点，防止后续改动绕开亲友访问状态校验。

### 24. 长辈关怀看板：跨会话亲友范围历史进入本机趋势

- `ConversationMemory` 新增 `careDashboardTranscriptHistory`：
  - 每次对话结束时，把当前 transcript 追加到关怀历史，最多保留最近 160 轮。
  - 兼容旧本机 JSON；没有该字段时以 `recentTranscript` 兜底。
  - 只负责保存候选对话轮次，真正进入看板前仍由 `CareDashboardInputPolicy` 按隐私范围和亲友可见性过滤。
- `CareDashboardViewController.reloadSnapshot` 改为读取 `getCareDashboardTranscriptHistory()`：
  - 当前进行中的会话会参与本机看板刷新。
  - 过去会话中已授权给亲友范围的内容也会参与本机趋势分析。
  - `localOnly`、`generationAllowed`、未授权 selected-member 内容仍不会进入关怀看板。
- 新增 `Scripts/ConversationMemoryCareHistoryVerify/main.swift`：
  - 验证第一轮已结束会话和第二轮进行中会话都会出现在关怀历史。
  - 验证通过 `CareDashboardInputPolicy` 后，亲友范围发言可进入看板输入。
  - 验证第二轮结束后，多轮用户关怀发言仍被保留。

## 真机验收建议

### 记忆档案馆

1. 进入“档案”。
2. 点击“添加文字素材”，选择“可生成”。
3. 输入：

   ```text
   我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。
   ```

4. 保存后等待 3-10 秒。
5. 进入“结构化知识库”，预期应出现人物、地点、事件或事实。
6. 再导入一段本地音频，选择“可生成”，确认档案统计中的“语音”数量增加，并在结构化知识库“事实”里看到一条语音样本元信息。
7. 如果已配置 `DreamJourneyBackendBaseURL` 并登录，后端应能通过 `GET /archive/items/{userId}` 查到该素材元数据；响应中不应包含 `localPath`。
8. 如果服务器配置了 `DEEPSEEK_API_KEY`，导入旧照片时应优先走后端图片分析代理；可用 `POST /archive/image-analysis?dryRun=true` 检查上游请求是否脱敏且不暴露 key。
9. 卸载重装或换设备登录同一账号后，打开主界面会尝试从 `GET /kb/snapshot/{userId}` 拉回已同步 KBLite 图谱；如果服务器已有快照，结构化知识库应恢复对应实体。

### 时空信箱

1. 先完成上面的记忆档案馆文本素材沉淀。
2. 进入“信箱”，写给“林桂芳”或“陈建国”的信。
3. 投递时间选择“立即”或“1 分钟”。
4. 封存后进入结构化知识库，预期“事实”中出现一条时空信箱元信息；不应出现完整信件正文。
5. 打开投递后的信件。
6. 预期回声包含：
   - “不是逝者真实回复”。
   - 如有匹配，出现“我能参考到的已授权记忆”。
   - 如无匹配，明确说明不会编造具体经历。
6. 如果选择未来投递，首次使用时系统会请求通知权限；到点后预期收到“时空信箱有一封信到达”的本机提醒。
7. 如果已配置 `DreamJourneyBackendBaseURL` 并登录：
   - 选择“本机”时，页面应仍提示完整内容只保存在本机，后端不会保存该信件。
   - 选择“可生成”或“亲友”时，后端应能通过 `GET /mailbox/letters/{userId}` 查到信件元数据。
   - 响应不应包含完整 `body`、`replyText` 或 `bodyPreview`。

### 长辈关怀看板

当前代码已验证：

- 空数据显示“数据不足”，不会显示“状态稳定”。
- 数据不足或 0 轮真实用户发言时不能分享周报，只展示真实数据引导。
- 周报只含脱敏聚合信号，不含原始聊天内容。
- selected-member 可见性会过滤非授权成员内容。
- 亲友成员可从后端拉取；邀请会先写入后端 `family_members`。
- 亲友接受邀请会写入后端 `accessStatus=active`、`invitationStatus=accepted`。
- 亲友撤回会写入后端 `accessStatus=revoked`，再次拉取成员时仍可识别撤回状态。
- 关怀看板快照可按 `viewerFamilyMemberID` 上传/拉取。
- 关怀看板历史快照可按 `viewerFamilyMemberID` 拉取最近 N 条；本机无数据时页面会显示“服务器同步历史 x 条”。
- 关怀看板快照读写会校验亲友状态：只有已接受且 active 的亲友成员可按 `viewerFamilyMemberID` 读写；pending、未知或 revoked 成员返回 403。
- 本机看板会读取跨会话亲友范围历史：多次结束对话后刷新看板，应看到数据覆盖和趋势不是只来自最后一次对话。
- 亲友邀请可复制 `dreamjourney://family/invite?code=...` 链接；另一台设备登录被邀请手机号后，可通过链接或粘贴邀请码接受邀请。

## 已运行验证

- `MemoryArchive verification passed`
- `TimeMailbox verification passed`
- `TimeMailboxNotification verification passed`
- `TimeMailboxBackendSync verification passed`
- `CareDashboard verification passed`
- `CareDashboardBackendSync verification passed`
- `CareDashboardShareReportUI verification passed`
- `MemoryArchiveBackendSync verification passed`
- `MemoryArchiveImageAnalysisProxy verification passed`
- `FamilyBackendSync verification passed`
- `FamilyInvitationCode verification passed`
- `DigitalHumanStartupReveal verification passed`
- `KBLiteArchiveMaterialMetadata verification passed`
- `KBLiteImportSanitizer verification passed`
- `ConversationTurnSourceRef verification passed`
- `ConversationMemoryCareHistory verification passed`
- `DreamJourneyBackend pytest 36/36 OK`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `LocalTestDataCleanup verification passed`
- `FamilyLocalTestCleanup verification passed`
- `RealDeviceNoDemoStateTokens verification passed`
- `FastAPI smoke verification passed`
- `git diff --check`
- `bash Scripts/verify_phase1.sh`，其中包含 `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`

结果：以上均通过。

## 下一步

1. 真机跨设备 smoke：A 设备创建亲友邀请，B 设备登录被邀请手机号，通过 `dreamjourney://family/invite?code=...` 接受。
2. 真机数字人启动 smoke：冷启动 App，观察首页数字人区域应从空白/背景直接淡入真人层，不应先闪出 loading 壳层或绿色背景。
3. 补真机证据包：档案入库截图、结构化知识库截图、信箱回声截图、信箱后端元数据响应、亲友邀请码接受截图、关怀周报导出文本、数字人冷启动录屏。
