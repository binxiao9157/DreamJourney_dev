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
- 通知只包含“有信到达”和收件人提示，不暴露信件正文。
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
  - 强制移除完整 `body` 和 `replyText`，只保存 `bodyPreview`、标题、收件人、投递时间、状态、边界确认和隐私范围。
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
6. 再导入一段本地音频，确认档案统计中的“语音”数量增加。
7. 如果已配置 `DreamJourneyBackendBaseURL` 并登录，后端应能通过 `GET /archive/items/{userId}` 查到该素材元数据；响应中不应包含 `localPath`。
8. 如果服务器配置了 `DEEPSEEK_API_KEY`，导入旧照片时应优先走后端图片分析代理；可用 `POST /archive/image-analysis?dryRun=true` 检查上游请求是否脱敏且不暴露 key。

### 时空信箱

1. 先完成上面的记忆档案馆文本素材沉淀。
2. 进入“信箱”，写给“林桂芳”或“陈建国”的信。
3. 投递时间选择“立即”或“1 分钟”。
4. 打开投递后的信件。
5. 预期回声包含：
   - “不是逝者真实回复”。
   - 如有匹配，出现“我能参考到的已授权记忆”。
   - 如无匹配，明确说明不会编造具体经历。
6. 如果选择未来投递，首次使用时系统会请求通知权限；到点后预期收到“时空信箱有一封信到达”的本机提醒。
7. 如果已配置 `DreamJourneyBackendBaseURL` 并登录：
   - 选择“本机”时，页面应仍提示完整内容只保存在本机，后端不会保存该信件。
   - 选择“可生成”或“亲友”时，后端应能通过 `GET /mailbox/letters/{userId}` 查到信件元数据。
   - 响应不应包含完整 `body` 或 `replyText`，只允许出现短 `bodyPreview`。

### 长辈关怀看板

当前代码已验证：

- 空数据显示“数据不足”，不会显示“状态稳定”。
- 周报只含脱敏聚合信号，不含原始聊天内容。
- selected-member 可见性会过滤非授权成员内容。
- 亲友成员可从后端拉取；邀请会先写入后端 `family_members`。
- 亲友接受邀请会写入后端 `accessStatus=active`、`invitationStatus=accepted`。
- 亲友撤回会写入后端 `accessStatus=revoked`，再次拉取成员时仍可识别撤回状态。
- 关怀看板快照可按 `viewerFamilyMemberID` 上传/拉取。
- 关怀看板历史快照可按 `viewerFamilyMemberID` 拉取最近 N 条；本机无数据时页面会显示“服务器同步历史 x 条”。
- 亲友邀请可复制 `dreamjourney://family/invite?code=...` 链接；另一台设备登录被邀请手机号后，可通过链接或粘贴邀请码接受邀请。

## 已运行验证

- `MemoryArchive verification passed`
- `TimeMailbox verification passed`
- `TimeMailboxNotification verification passed`
- `TimeMailboxBackendSync verification passed`
- `CareDashboard verification passed`
- `CareDashboardBackendSync verification passed`
- `MemoryArchiveBackendSync verification passed`
- `MemoryArchiveImageAnalysisProxy verification passed`
- `FamilyBackendSync verification passed`
- `FamilyInvitationCode verification passed`
- `DreamJourneyBackend unittest 33/33 OK`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `LocalTestDataCleanup verification passed`
- `FastAPI smoke verification passed`
- `git diff --check`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

结果：以上均通过。

## 下一步

1. 真机跨设备 smoke：A 设备创建亲友邀请，B 设备登录被邀请手机号，通过 `dreamjourney://family/invite?code=...` 接受。
2. 补真机证据包：档案入库截图、结构化知识库截图、信箱回声截图、信箱后端元数据响应、亲友邀请码接受截图、关怀周报导出文本。
