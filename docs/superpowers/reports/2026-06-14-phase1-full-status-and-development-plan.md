# 阶段一工程实现状态与后续开发计划 - 2026-06-14

基准文档：`/Users/yxj/Documents/Codex/Video/docs/阶段一.docx`  
iOS 分支：`feature/phase2-mock-dialog-engine`  
iOS 仓库路径：`/Users/yxj/.config/superpowers/worktrees/DreamJourney_dev/phase2-mock-dialog-engine`  
后端仓库路径：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`  

本文档用于替代“继续下一步”的口头循环，作为后续真机验收和缺陷修复的单一状态基线。

## 1. 阶段一目标复述

阶段一产品不是普通陪聊工具，也不是路演展示器。目标是一个克制、安全、可沉淀真实记忆的数字哀伤辅导工具。

核心目标拆解如下：

1. 记忆档案馆：低门槛上传旧照片、语音、文字描述，形成可追踪的记忆库、人格线索和声纹素材。
2. 时空信箱：采用“投递与回声”的克制延迟交互，避免即时复活式聊天，且回声必须带边界感。
3. 向阳生长：识别危机表达、限制沉迷式对话、引导回到现实生活。
4. 长辈关怀看板：子女只能看到脱敏聚合周报和风险信号，看不到老人原始聊天。
5. 数字人/声纹：用授权记忆和声音素材做陪伴表达，但必须避免制造“死者复活”的幻觉。
6. 一个大脑，两副面孔：底层记忆库、RAG、语音、风控能力可支撑勿忘 App 和后续适老终端。

## 2. 总体达成度

当前工程已经具备阶段一核心链路的真机验收基础，但还不是完整可上线版本。

| 维度 | 当前估算 | 说明 |
| --- | ---: | --- |
| 工程实现完成度 | 72% | App 侧主要模块和后端最小服务已成型，仍缺真实设备、真实账号、真实服务的连续验收闭环。 |
| 阶段一产品契合度 | 78% | 已从路演模式转向真实测试模式，核心方向与“记忆沉淀 + 克制陪伴 + 家庭关怀”一致；适老终端 B 面仍偏原型。 |
| 真机验收证据完整度 | 38% | 有大量自动验证和部分真机反馈，但缺 P0/P1 模块的系统化截图、录屏、后端脱敏响应和跨设备证据包。 |
| 生产化成熟度 | 45% | 后端、隐私分层和鉴权已启动，但长期稳定性、APNs、专家转介、安全服务、数据备份仍未生产化。 |

结论：下一阶段不应继续堆 UI 或路演体验，而应集中做真实素材、真实账号、真实后端的验收闭环。

## 3. 当前实现状态

| 模块 | 已实现内容 | 当前缺口 | 状态 |
| --- | --- | --- | --- |
| 记忆档案馆建库核心 | 文本、照片、截图 OCR、语音素材、隐私范围、KBLite 入库、sourceRef、后端 metadata sync、图片分析代理、声纹样本状态、友好失败文案。 | 真实照片分析、真实语音转写、同一人物 3 段声纹样本、speakerId 绑定和后端 metadata-only 响应仍需真机验收。 | P0 待真机验收 |
| KBLite 结构化知识库 | 对话抽取、档案素材元信息入库、信箱元信息入库、后端快照恢复、多用户隔离、prompt 授权裁剪、路演/泛称清理。 | 需要用真实账号连续沉淀多轮素材，验证结构化知识库不是旧 seed 或 mock 残留。 | P0 待真机验收 |
| 数字人对话记忆约束 | 实时对话、RAG payload、`.prompt` 授权图谱、无证据不编造约束、TTS/WAV/系统 TTS 兜底、播放证据日志。 | 需要真机 3-5 轮验证：引用已沉淀事实、未沉淀事实不编造、不抢话、口型停随音频。 | P0/P1 待真机验收 |
| 时空信箱 | 本地信件、延迟投递、本机通知、边界回声、KBLite 元信息入库、后端 metadata-only 同步、正文/回声不出端。 | 需要真实信件投递、通知、跨设备只恢复 metadata、后端响应脱敏抽查。 | P1 待真机验收 |
| 长辈关怀看板 | 亲友范围对话候选、脱敏快照、7 天趋势、历史快照、active/accepted 权限、撤回后 403、原始 transcript 不展示。 | 需要两台真机完成邀请、接受、撤回、读取拒绝和周报人工抽查。 | P1 待真机验收 |
| 向阳生长/安全边界 | 本地 SafetyMonitor、危机干预页、边界消息不入库、渐进式对话限制、脱敏锁。 | Safety Guard 服务端化、紧急联系人、专家转介未生产化。阶段一可先验本地规则。 | P1/P2 |
| 足迹点亮 | 默认城市点亮、高德行政区边界、本地兜底、代际色彩、去掉城市/全国/世界可选项。 | 与阶段一哀伤辅导主线关系弱，只做视觉回归，不再反复开发。 | 已封板 |
| 后端服务 | FastAPI、Postgres、Redis 预留、KBLite、档案、图片分析、信箱、亲友、关怀、TTS、高德代理、API token。 | 服务器 smoke、HTTPS 正式域名、长期数据、备份、CORS/鉴权、运行日志脱敏仍需验收。 | P2 |
| 适老终端 B 面 | App 内有一键对话/潜行建库原型和关怀看板数据链路。 | 独立小程序/音箱未实现，不应在阶段一验收前扩范围。 | 后置 |

## 4. 已封板事项

以下事项不再作为主动开发任务加入 backlog，只在全量验证或真机出现新证据时重开缺陷。

| 已封板项 | 封板原因 | 回归方式 |
| --- | --- | --- |
| 数字人冷启动明显切换 | 已完成 poster/ready 门禁、透明 WebView 和启动揭示验证。 | `Scripts/DigitalHumanStartupRevealVerify/main.py`、真机冷启动录屏。 |
| 路演/演示 UI 清理 | 真实模式已通过 runtime gate 和 no-demo state 校验。 | `Scripts/RealDeviceRuntimeGateVerify/main.py`、`Scripts/RealDeviceNoDemoStateTokensVerify/main.py`。 |
| 足迹默认城市点亮 | 产品方向已明确，足迹不是当前 P0 主线。 | `Scripts/FamilyFootprintIlluminationPolicyVerify/main.py`、真机视觉回归。 |
| 结构化知识库旧 seed/泛称清理 | 导入清理、prompt 图谱裁剪和真实模式门禁已有验证。 | `Scripts/KBLiteImportSanitizerVerify/main.swift`、真实账号复测。 |
| 用户可见底层错误治理首轮 | OCR、语音识别、声纹训练失败已改为友好文案。 | 对应 MemoryArchive 验证脚本和真机失败场景。 |

## 5. 证据记录

### 5.1 最近 iOS 分支提交

- `055aa94 Document phase1 implementation backlog`
- `15bbed5 Use prompt-safe graph for dialog grounding`
- `a9209f2 Add phase1 acceptance task ledger`
- `770c6a2 Hide raw voice profile training errors`
- `29a828c Use friendly voice profile training failures`

### 5.2 后端仓库状态

后端仓库 `main` 最近提交：

- `b47fc4f Sync backend archive analysis services`
- `37ef596 Ignore private deployment notes`
- `3a99be7 fix: stabilize docker deployment on server`

### 5.3 已有自动验证覆盖

`Scripts/verify_phase1.sh` 覆盖以下关键能力：

- 记忆档案馆：素材保存、隐私、照片分析代理、截图 OCR、语音转写、声纹样本、失败文案。
- KBLite：抽取、入库、sourceRef、隐私裁剪、后端快照恢复、多用户隔离、prompt 图谱。
- 数字人：启动揭示、资源校验、TTS/播放策略、播放日志、对话结束沉淀、RAG payload。
- 时空信箱：延迟投递、通知、后端 metadata-only、回声证据和隐私边界。
- 长辈关怀：脱敏快照、趋势、成员权限、历史读取、撤回状态、分享周报 UI。
- 后端：Postgres store、auth token、真实后端流的 memory store smoke。
- 真实模式：no-demo state、runtime gate、local cleanup 和 iPhoneOS Debug build。

最近关键验证日志：

- `/tmp/dreamjourney_verify_phase1_prompt_archive_snapshot.log`

该日志中已有：

- `DialogMemoryGrounding verification passed`
- `DialogRealtimeRAGFinalASR verification passed`
- `DialogMemoryRAGPayload verification passed`
- `KBLitePromptGraphSanitization verification passed`
- `** BUILD SUCCEEDED **`

## 6. 当前偏离与纠正

| 偏离/风险 | 当前纠正 |
| --- | --- |
| 早期围绕路演 demo、足迹分享、冷启动视觉反复打磨，容易偏离阶段一核心。 | 这些任务已封板，后续只回归，不再主动开发。 |
| 数字人容易自由发挥，弱化记忆沉淀和边界。 | 对话 RAG 已改用 prompt-safe 图谱；下一步用真机验证“有证据才说”。 |
| 结构化知识库曾残留 seed/mock 或泛称人物。 | 已有 import sanitizer 和 prompt graph sanitizer；下一步用真实账号重建库验证。 |
| 后端与 OpenAvatarChat 概念混淆。 | DreamJourney 自有业务后端使用 `DreamJourneyBackendBaseURL`；`OpenAvatarChatBaseURL` 只保留旧兼容，不承载业务数据。 |
| 适老终端 B 面容易扩成新产品。 | 阶段一只验 App 内一键对话和关怀链路，独立小程序/音箱后置。 |

## 7. 后续开发计划

### P0-1：记忆档案馆真实素材建库验收

目标：证明真实素材能稳定进入档案馆、KBLite、后端 metadata 和数字人可引用链路。

执行步骤：

1. 真机登录真实测试账号，清理旧 seed/demo 数据。
2. 首页隐私范围选择“可生成”。
3. 档案馆新增文字素材：
   - `我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。林桂芳性格慢，常说慢慢来，日子要一张一张照好。`
4. 保存后等待 5-10 秒，进入结构化知识库检查人物、地点、事件、事实、来源。
5. 导入真实照片，确认优先走 `DreamJourneyBackendBaseURL` 图片分析代理；失败只显示可重试，不允许 mock 成功。
6. 导入真实语音素材，确认补转写/摘要/人物绑定。
7. 同一具体人物导入 3 段语音，确认声纹档案进入 `readyForTraining` 或友好失败状态。
8. 查询后端 `/archive/items/{userId}`，确认只含 metadata，不含本地路径、图片/音频本体。

验收证据：

- 档案馆截图。
- 结构化知识库截图。
- 后端 archive items 脱敏响应。
- 声纹档案状态截图。
- 对应真机日志和 `Scripts/verify_phase1.sh` 通过日志。

### P0-2：数字人对话记忆约束真机验收

目标：数字人优先引用授权记忆，没有证据时不编造。

执行步骤：

1. 先完成 P0-1 的至少一条真实结构化记忆。
2. 首页使用“可生成”隐私范围进行 3-5 轮语音对话。
3. 询问已沉淀事实，例如“林桂芳以前常说什么”“我们以前在哪里开过照相馆”。
4. 询问未沉淀事实，例如“她最喜欢哪首歌”，观察是否明确表示还没有记住，而不是编造。
5. 结束对话后等待 5-10 秒，检查本轮新事实是否进入结构化知识库。
6. 抽取设备日志，确认 `DialogMemoryGrounding` / RAG payload 发送记录存在且不含未授权内容。

验收证据：

- 对话录屏。
- 结构化知识库更新截图。
- 设备日志片段。
- 如失败，先记录具体问题，不直接扩大重构范围。

### P1-1：长辈关怀看板跨设备验收

目标：子女只能看到脱敏聚合信号，撤回后不能继续读取。

执行步骤：

1. A 设备登录主账号，创建亲友邀请。
2. B 设备登录被邀请手机号，接受邀请码或 deeplink。
3. A 设备用“亲友”范围完成 3-5 轮真实对话。
4. B 设备查看关怀看板，确认只有趋势、摘要、周报，无原始 transcript。
5. A 设备撤回 B 权限。
6. B 设备再次读取 latest/history，后端应返回 403，App 显示权限已撤回或未生效。

验收证据：

- 邀请、接受、撤回截图。
- B 设备关怀看板截图。
- 后端 403 响应。

### P1-2：时空信箱真实信件验收

目标：信件正文只在本机，后端只保存 metadata；回声只引用授权记忆。

执行步骤：

1. 先沉淀一条具体人物记忆。
2. 创建给具体姓名的信件，隐私选择“可生成”或“亲友”。
3. 设置 1 分钟后投递，确认本机通知不暴露收件人和正文。
4. 打开信件，确认“原信仅本机显示”和“不是逝者真实回复”的边界。
5. 查询后端 `/mailbox/letters/{userId}`，确认没有 `body`、`replyText`、`bodyPreview`。
6. 换设备登录同账号，确认只能恢复 metadata，不会凭空出现正文。

验收证据：

- 投递通知截图。
- 信件阅读页截图。
- 后端 mailbox letters 脱敏响应。

### P2-1：线上后端 smoke 与安全配置验收

目标：服务器后端可长期支撑真机测试。

执行步骤：

1. 确认 App 的 `DreamJourneyBackendBaseURL` 指向当前可用 HTTPS 地址。
2. 运行：
   - `GET /health`
   - `GET /config/runtime`
   - `POST /archive/image-analysis?dryRun=true`
   - `GET /kb/snapshot/{userId}`
   - `GET /care/snapshots/latest/{userId}`
3. 检查 `DreamJourneyBackendAPIToken` 是否已启用，未带 token 时除 `/health` 外应返回 401。
4. 检查 DeepSeek、VolcEngine、高德 key 的运行时能力状态只展示 configured/missing，不泄露原值。
5. 检查 Postgres 容器、备份策略和 API 日志脱敏。

验收证据：

- smoke 命令输出。
- 运行时配置脱敏截图。
- Docker compose 状态。
- API token 拒绝未授权访问的响应。

### P2-2：阶段一证据包

目标：形成一份可复盘、可交接的阶段一真机验收包。

内容：

1. 真机截图和录屏：
   - 档案馆建库。
   - 结构化知识库。
   - 数字人对话引用记忆。
   - 时空信箱投递与阅读。
   - 关怀看板脱敏周报。
2. 后端脱敏响应样本：
   - archive items。
   - mailbox letters。
   - care snapshots。
   - runtime config。
3. 自动验证日志：
   - `Scripts/verify_phase1.sh`。
   - 相关局部脚本。
4. 缺陷列表：
   - 只记录真机新问题。
   - 已封板项不重复进入开发队列。

## 8. 不进入下一阶段默认开发的事项

以下事项除非有新真机证据，不进入下一轮默认开发：

- 数字人冷启动首帧反复优化。
- 足迹地图模式结构反复调整。
- 路演引导、路线、seed、offline 模式。
- 新增独立适老小程序或音箱端。
- 未经真实失败证据的 UI 微调。

## 9. 下一次恢复工作的唯一入口

下一次恢复开发时，先不写代码，按顺序执行：

1. P0-1 记忆档案馆真实素材建库真机验收。
2. 记录截图、录屏、后端响应和设备日志。
3. 只有验收失败时，按失败项开单点缺陷。
4. 每个缺陷修复后跑局部验证和 `Scripts/verify_phase1.sh`。
5. 更新本文档的状态表，避免同一问题重复开发。

## 10. 2026-06-14 执行更新

执行记录：`docs/superpowers/reports/2026-06-14-phase1-acceptance-execution-round-1.md`

本轮已完成：

- 使用 3 个只读 agent 完成 P0 记忆档案馆、P0 数字人记忆约束、P1 信箱/关怀/P2 后端链路审计。
- `Scripts/verify_phase1.sh` 自动基线通过，iPhoneOS Debug build 成功。
- 线上 `/health` smoke 通过，返回 production + postgres。
- 发现线上 `/config/runtime` 未带 token 也返回 200，标记为 P2 后端鉴权配置缺口。
- 初次探测真机可见，但 Xcode 真机构建被 Developer Disk Image 挂载失败阻塞；设备重新连接后已解除。
- 修正验收计划：时空信箱当前最短投递延迟为 5 分钟。

当前恢复入口调整为：

1. 先执行 P0-1 记忆档案馆真实素材建库验收。
2. 再执行 P0-2 数字人对话记忆约束验收。
3. 同步配置服务器 `BACKEND_API_TOKEN` 与 iOS `DreamJourneyBackendAPIToken`，用于 P2 authenticated smoke。

补充：2026-06-14 18:19 已完成真机构建、安装和启动；Developer Disk Image 挂载问题已通过重新连接设备解除。

## 11. 2026-06-14 P0/P1 自动开发更新

本轮按 P0 > P1 的顺序先完成无需人工操作的功能修复和自动化验收，不再继续堆路演 UI 或足迹视觉细节。

已完成修复：

- 数字人原生 WAV 播放期间会暂停实时对话 SDK 以避免回声，但过去会把这次内部暂停误判成用户手动结束，导致一轮回答后不再继续聆听。本轮新增内部播放暂停标记，播放结束后自动恢复实时聆听；真正的用户手动结束仍走原结束沉淀逻辑。
- 长辈关怀成员撤回后，`InMemoryStore.accept_family_member` 曾允许同一手机号通过直接 accept 重新变 active。本轮补齐撤回态保护，与邀请码/Postgres 行为对齐。
- `Scripts/verify_phase1.sh` 已纳入数字人实时恢复校验和后端 core services 单测，后续回归会自动覆盖这两个缺陷。

验证结果：

- `python3 Scripts/DigitalHumanRealtimeResumeVerify/main.py` 通过。
- `python3 Scripts/DigitalHumanDialogEndDepositVerify/main.py`、`DigitalHumanPlaybackInterruptVerify`、`DigitalHumanRuntimeLogVerify` 通过。
- `STORE_BACKEND=memory PYTHONPATH=$DREAMJOURNEY_BACKEND_REPO python3 -m unittest discover -s $DREAMJOURNEY_BACKEND_REPO/tests -p test_core_services.py` 通过，共 43 项。
- `STORE_BACKEND=memory PYTHONPATH=$DREAMJOURNEY_BACKEND_REPO python3 Scripts/CareDashboardTrueBackendFlowVerify/main.py` 通过。
- `bash Scripts/verify_phase1.sh` 通过；日志：`/tmp/dreamjourney_phase1_p0p1_after_resume_fix.log`。
- iPhoneOS 真机 Debug build 通过；日志：`/tmp/dreamjourney_p0p1_dev_true_device_build_retry.log`。

状态调整：

- P0 数字人“播放后断会话/抢停”从待开发调整为已自动修复，仍需真机用真实语音验证连续 3-5 轮。
- P1 长辈关怀“撤回后不可继续读取/重新接受”从待开发调整为已自动修复，仍需双真机账号验证 UI 和后端 403。
- P0 记忆档案馆真实素材建库、P0 数字人有证据才回答、P1 时空信箱 5 分钟投递，仍是下一轮人工真机验收主线。

## 12. 2026-06-14 后端鉴权 Smoke 自动化更新

本轮继续推进无需人工真机操作的验收支撑项，针对 P2 中“线上后端 smoke 与安全配置验收”补齐自动化入口。

已完成：

- 新增 `Scripts/BackendAuthenticatedSmoke/main.py`。
  - 默认自测 FastAPI 本地行为：`/health` 公开，`/config/runtime` 在 `BACKEND_API_TOKEN` 配置后未带 token 返回 401，Bearer 与 `X-DreamJourney-API-Token` 均可通过。
  - 远端模式支持 `DREAMJOURNEY_BACKEND_BASE_URL` + `DREAMJOURNEY_BACKEND_API_TOKEN`，可验证 `/health`、`/config/runtime`、`/archive/image-analysis?dryRun=true`、`/kb/sync`、`/kb/snapshot`。
  - 对 runtime、dryRun、snapshot 响应做 secret marker 检查，防止 token/key 泄露。
- 新增 `Scripts/BackendAuthenticatedSmokeContractVerify/main.py`，防止 smoke 能力或总验证入口被误删。
- `Scripts/verify_phase1.sh` 已接入 authenticated backend smoke contract 与本地 smoke。

验证结果：

- `python3 Scripts/BackendAuthenticatedSmokeContractVerify/main.py` 通过。
- `PYTHONPATH=$DREAMJOURNEY_BACKEND_REPO STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py` 通过。
- `bash Scripts/verify_phase1.sh` 通过；日志：`/tmp/dreamjourney_phase1_backend_smoke_verify.log`。

状态调整：

- P2 “后端鉴权 smoke 缺自动入口”已完成。
- P2 “线上 `/config/runtime` 未带 token 返回 200”仍需服务器配置 `BACKEND_API_TOKEN` 后用远端模式复验：
  - `DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn`
  - `DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>`
  - `export DREAMJOURNEY_BACKEND_REPO=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend && PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py --remote`

## 13. 2026-06-14 阶段一真机证据脚手架更新

本轮补齐 P0/P1 真机验收证据包的工程化入口，避免后续截图、录屏、日志和后端响应散落在聊天或临时目录里。

已完成：

- 新增 `Scripts/phase1_acceptance_evidence_scaffold.py`。
  - 默认生成/更新 `docs/superpowers/evidence` 下的阶段一验收结构。
  - 覆盖 `phase1-memory-archive`、`phase1-digital-human-grounding`、`phase1-care-dashboard`、`phase1-time-mailbox`、`phase1-backend-smoke` 五个目录。
  - 每个模块生成 `acceptance_checklist.md`，列出必须保存的截图、录屏、日志和后端脱敏响应。
  - 根目录生成 `phase1_acceptance_manifest.json` 和 `phase1_acceptance_checklist.md`。
  - 明确隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。
- 新增 `Scripts/Phase1AcceptanceEvidenceScaffoldVerify/main.py`。
  - 在临时目录执行 scaffold，验证五个模块目录、根 manifest、模块 checklist 和关键验收文案。
  - 防止证据目录结构、后端 smoke 命令或隐私边界文案漂移。
- `Scripts/verify_phase1.sh` 已接入该 scaffold 验证。

验证结果：

- `python3 Scripts/Phase1AcceptanceEvidenceScaffoldVerify/main.py` 通过。
- `bash Scripts/verify_phase1.sh` 通过；日志：`/tmp/dreamjourney_phase1_evidence_scaffold_verify.log`。

状态调整：

- P2-2 “阶段一证据包”从纯人工整理，调整为已有工程化脚手架。
- P0/P1 真机验收仍未完成；下一次继续时，应把真实截图、录屏、设备日志和后端脱敏响应填入对应 evidence 目录，而不是继续新增路演或 mock 体验。
