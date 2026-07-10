# DreamJourney 当前工程实现与 PRD 对齐说明

日期：2026-07-01  
范围：iOS 工程 `DreamJourney_dev`、后端工程 `DreamJourneyBackend`、最新 PRD/阶段规划/腾讯数智人替代方案相关文档、当前分支已提交实现。

> 本文用于给产品、开发、测试和后续接手同事快速理解：当前工程已经实现了什么、对应 PRD 哪些闭环、哪些能力仍需真机/服务端/产品决策继续验收。本文不记录任何密钥、token、SecretId、SecretKey 或服务器私密配置。

## 2026-07-10 基线补充

- 本轮基于 iOS `9999290`、后端 `481869e` 继续开发。
- 2026-07-02 已完成 Echo 本人/家人角色音色路由、角色切换 runtime guard、消息中心和 Context V2 证据链。
- 2026-07-03 已完成家人 voice profile 绑定修复和旧试用槽默认值清理。
- 声音复刻合同现升级为 v2：iOS 使用逻辑 `vp_...` profile；后端把它独占绑定到火山 `providerSpeakerId=S_...`，训练、refresh、合成都只在服务端解析 provider ID。
- `/voice/synthesis` 现在强制验证 profile owner、ready、enabled、provider readiness 和质量验收；不再允许任意用户直接拿 `S_` ID 合成。
- `voice_clone_slots` 删除策略为 `retireOnDelete`，三个试用槽属于 QA 容量，不是多用户生产容量。

## 1. 当前仓库与版本

### iOS 工程

- 路径：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 当前分支：`feature/prd-stitch-ui-adaptation`
- 当前对齐远程：`origin/feature/prd-stitch-ui-adaptation`
- 当前版本：`1f638db Refine autobiography book archive entry`
- 最近关键提交：
  - `1f638db Refine autobiography book archive entry`
  - `381ccc9 feat: adapt archive autobiography modes`
  - `cddf9d7 fix: update digital human virtualman key`
  - `4f8201f fix: override digital human virtualman key`
  - `401b079 fix: stabilize cloned voice digital human playback`
  - `4491204 test: add voice clone pcm drive QA gates`
  - `52e6f28 feat: expand echo digital human canvas`

### 后端工程

- 路径：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`
- 当前分支：`main`
- 当前对齐远程：`origin/main`
- 当前版本：`f279bff feat: add voice clone quality acceptance gate`
- 最近关键提交：
  - `f279bff feat: add voice clone quality acceptance gate`
  - `13a2893 fix: expose voice clone synthesis provider logs`
  - `9801c26 docs: record tencent digital human backend deploy`
  - `d34fdca feat: add tencent audio-drive pcm synthesis contract`
  - `7e89f0d feat: add tencent digital human cloud session contract`
  - `805689e fix: support voice clone 2 trial slots`
  - `9d1cde4 feat: add family account lifecycle contracts`
  - `15efa23 feat: add voice synthesis viseme timeline contract`

## 2. PRD 当前主线目标

结合最新 PRD 和阶段规划，当前产品目标可以归纳为：

1. 登录/注册进入产品。
2. 在“记忆档案”中沉淀本人或家庭成员的记忆材料。
3. 将档案材料用于“回响”对话，形成语音优先的陪伴体验。
4. 在“我的”中承载个人资料、家庭成员、关怀信号、账号安全和声音复刻等能力。
5. 数字人从隐藏验证逐步转为公开能力，但需要保证普通 Echo 主链路可降级。
6. 未完成或未验收能力必须用 feature flag、隐藏入口或 QA-only 参数控制，不能默认误暴露。

当前公开信息架构仍保持三栏：

- `记忆档案`
- `回响`
- `我的`

Stitch UI / htmlCode 仍是视觉主依据，MCP screenshot 只作为辅助复核。

## 3. 公开 MVP 已实现能力

### 3.1 登录与基础会话

已实现：

- 登录/注册入口保留。
- 后端已有 `/auth/login` 等基础认证相关接口。
- iOS 侧已围绕发布态做过多轮 smoke 和 release regression。

仍需关注：

- 真实账号体系、短信/手机号验证、token 刷新和异常恢复还需要结合正式后端策略继续验收。

### 3.2 记忆档案 / 自传式档案

已实现：

- “记忆档案”作为第一 Tab，保留 Stitch 目标风格。
- 当前档案页已经演进为自传/家庭故事模式：
  - 本人视角展示“我的自传”。
  - 家庭成员视角展示家庭故事/只读模式。
  - 新增书籍式入口，用于承载自传章节、素材数量和估算页数。
- 支持文本、照片、时间信件等公开档案类型。
- 照片档案支持：
  - 本地保存状态。
  - 云端同步状态。
  - AI 分析状态。
  - 失败/可重试状态。
  - 人物、地点、场景、标签等结构化分析字段展示。
- 档案详情支持：
  - 素材类型。
  - 采集来源。
  - 分析状态。
  - 文件状态。
  - 云端状态。
  - AI 分析可用/不可用/失败说明。
- 后端 `/archive/items` 已承载不同档案类型和 metadata。
- 后端 `/archive/image-analysis` 已支持 provider 不可用时返回可持久化的失败/重试合同，避免前端长期只显示“同步失败”。
- Echo 构造上下文时已避免把失败分析的空人物/地点线索当作有效上下文注入。

与 PRD 对齐：

- 符合“记忆档案馆”作为核心记忆沉淀入口。
- 符合 AI 分析为主、后端辅助处理，并向用户披露 AI 分析边界的要求。
- 符合家庭数字人档案可见性和上传者管理权限的基础合同方向。

仍需关注：

- 真机相册权限、照片选择、前后台切换后的文件不丢失，需要继续真机验收。
- 视频和录音档案仍属于扩展/隐藏能力，不能视为公开完整闭环。
- 真实视觉模型 provider 尚未最终验收，当前失败/重试合同已稳定，但真实人物/地点/场景识别质量还需 provider 选择后验证。

### 3.3 时间信件

已实现：

- 时间信件已从隐藏壳层推进到公开基础能力。
- 创建入口位于用户自己的档案创建链路中。
- 支持：
  - 文字内容。
  - 图片附件。
  - 打开时间 `openAt`。
  - 选择一个或多个家庭亲友作为收件人。
  - 草稿编辑。
  - 草稿删除。
  - 封存。
  - 封存后详情查看。
- 明确暂不支持：
  - 视频。
  - 音频。
- 封存后禁止删除/修改。
- 本地通知和应用内提醒中心/提醒入口已接入基础逻辑。
- 后端 metadata 已包括：
  - `openAt`
  - `recipients`
  - `sealedAt`
  - `deliveryStatus`
  - 投递/调度/通知相关状态字段
- 后端删除封存时间信件会返回不可删除合同。

与 PRD 对齐：

- 对齐“时间信件逻辑已经明确”的产品决策。
- 对齐“本人和收件人到达时间后收到提醒”的本地与应用内提醒基础合同。

仍需关注：

- APNs provider delivery 尚未完成端到端真机证据。
- 跨账号收件人通知、服务端定时投递和失败补偿仍需 release-like 后端和真机验收。

### 3.4 回响 Echo

已实现：

- “回响”作为第二 Tab，维持语音优先对话体验。
- 支持档案上下文参与回响。
- 回响状态机已覆盖：
  - 聆听中。
  - 思考中。
  - 等待回信。
  - 已回信。
  - 失败/重试。
- 等待回信策略已按 PRD 方向实现：
  - 约 10 轮作为基础判断。
  - 内容/情绪可提前触发。
  - 延迟回信状态可持久化。
  - 本地通知和后端 delayed reply 合同已建立。
- 停止语义已修正：
  - 停止按钮只停止当前麦克风/对话轮次。
  - 不应主动关闭腾讯数字人视图。
  - 页面退出或 provider 确认失败才关闭/移除数字人。
- 连续对话已做过多轮修复：
  - 数字人说完后可恢复聆听。
  - 用户主动停止才结束本轮。
  - 普通 Echo fallback 可用。

与 PRD 对齐：

- 对齐“回响”作为核心情感交互闭环。
- 对齐“档案 -> 回响”的主链路。
- 对齐等待回信和通知提醒方向。

仍需关注：

- 真机端麦克风、语音识别、播放路由、前后台切换、打断说话等仍需持续回归。
- APNs 真正送达还未形成完整证据。
- 生产语音质量不能只用模拟器或 mock 证明。

### 3.5 腾讯数智人公开能力

已实现：

- 数字人已经从 QA-only/hidden 逐步转为公开 Echo 能力。
- iOS 已接入腾讯数智人云渲染 SDK。
- 后端提供 `/digital-human/sessions`，iOS 不保存腾讯 appkey/accesstoken。
- 后端 `/config/runtime` 暴露数字人能力。
- 当前 iOS 包内存在数字人 asset virtualman key 本地覆盖逻辑：
  - 正式路径以后端 `/digital-human/sessions` 返回的 `assetKey/providerAssetId/providerProjectId` 为主。
  - 包内 `DreamJourneyDigitalHumanAssetVirtualmanKey` 只在 QA/debug launch arg `DJUseLocalDigitalHumanAssetOverride` 存在时覆盖后端 asset。
  - Echo 日志会输出 `assetSource=backendSession` 或 `assetSource=localQAOverride`，用于真机排查数字人资产来源。
- 已修过的问题：
  - 错误本地预览数字人闪现。
  - 停止按钮误关闭数字人。
  - 数字人说完后麦克风状态不清晰。
  - 火山/腾讯/本地播放器争抢音频 owner 的一部分问题。
  - 腾讯云渲染画面尺寸和全屏展示问题。
  - Echo 新增 `audioOwner=tencentDigitalHuman/localPreview/fallbackMuted/volcengineLocalTTS` 日志，方便定位当前是谁在负责播放或静音交接。
- Phase 1 稳定性保护已补充：
  - `Scripts/QA/prd-stitch-ui/tencent-digital-human-phase1-stability-check.swift` 防止本地 asset 在 release 路径静默覆盖后端 asset。
  - 真机 PCM-drive smoke 会断言 `assetSource=backendSession`、`audioOwner=tencentDigitalHuman`、`audioOwner=fallbackMuted`。
  - 真机 smoke 不传 `DJUseLocalDigitalHumanAssetOverride`，确保默认验证后端 `/digital-human/sessions` 下发的正式 asset。
  - 停止按钮路径不应 `close/remove/nil` 腾讯 runtime；只中断当前播放/麦克风轮次，页面退出才释放 session。
  - 非真机模拟器验证：
    - `run-tencent-digital-human-phase1-non-device-gate.sh` 是 Phase 1 的一键非真机 gate，会串起 Phase 1 静态 guard、runtime stub、Tencent backend PCM-drive mock、静态 release regression、模拟器 Debug 编译和 `git diff --check`。
    - `run-digital-human-runtime-stub-smoke.sh` 可验证会话合同、runtime stub 生命周期和面板截图。
    - `run-tencent-backend-pcm-drive-mock-smoke.sh` 可验证线上 runtime 能力、复刻 TTS 输出腾讯 audio-drive 兼容 PCM、prepared PCM 切块、final chunk、stop probe 清理 active request。
    - 该 smoke 会在安装前重新写入构建产物 `Info.plist` 的 `DreamJourneyBackendBaseURL/DreamJourneyBackendAPIToken`，避免本机 `LocalConfig.plist` 把测试错误导向临时本地后端。
    - `preparedByteCount` 用于校验发送给腾讯的实际 PCM 字节数；它允许 preroll/tail silence/fade 等稳定性处理，不再错误要求等于后端原始 PCM 字节数。
  - 本轮按要求不跑真机验证；真实设备上的声音、口型、打断和麦克风恢复仍需单独真机回归。
- 普通 Echo fallback 存在：
  - 腾讯数字人配置失败、连接失败或 provider 不可用时回到普通回响。

与 PRD 对齐：

- 对齐“数字人要公开”的最新方向。
- 对齐“失败降级、不影响普通 Echo 主链路”的要求。

仍需关注：

- 当前数字人 asset 来源需要产品/工程统一：
  - 当前正式路径已经改为后端 `/digital-human/sessions` 优先。
  - 包内 override 仅用于 QA/debug 临时切换。
  - 长期仍需确认是否彻底移除包内默认 asset key，还是继续保留 QA 覆盖能力。
- 腾讯资产并发配额、projectId/virtualmanKey 对应关系必须由服务端和腾讯控制台保持一致。
- 真机完整链路仍需持续验证：
  - 有声。
  - 口型动。
  - 可打断。
  - 停止后恢复麦克风。
  - 关闭 App 重开后仍能稳定加载。
  - 推荐脚本：`Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh`。设备上线后应先跑该脚本，再做 5 轮人工连续对话确认。

### 3.6 声音复刻与复刻音色合成

已实现：

- 声音复刻入口已公开。
- iOS 不直连火山/豆包声音复刻 API，统一走后端代理。
- 后端支持火山声音复刻 V3/2.0 试用槽位方向：
  - 训练。
  - 查询/刷新状态。
  - 样本状态。
  - `voiceProfileId`。
  - 授权确认。
  - 禁用/删除合同。
  - provider log id 暴露，便于与火山客服定位问题。
- 复刻 TTS 合成已迁到后端。
- 后端 `/voice/synthesis` 支持：
  - 普通合成。
  - 复刻音色合成。
  - `tencentAudioDrive` 输出模式。
  - 输出腾讯 audio-drive 兼容 PCM：16kHz、16bit、mono。
- `tencentAudioDrive` 响应包含 `voiceProfileId`、`outputMode`、PCM 格式、采样率、位深、声道、字节数、`durationSeconds`、`providerRequestId/providerLogId`。
- iOS Echo 主链路已经接入后端复刻 PCM：
  - 有 ready/accepted 且质量已确认的 `voiceProfileId` 时，Echo 优先请求 `/voice/synthesis` + `outputMode=tencentAudioDrive`，再把 PCM 喂给腾讯数智人 audio-drive。
  - 没有可用复刻音色时，UI 会提示“暂未启用复刻音色”。
  - provider 失败或音频格式不兼容时，UI 会提示“复刻声音生成失败，请稍后重试”，并且不再静默切回腾讯默认 text voice。
  - QA 日志输出 `voiceProfileId/outputMode/providerLogId/providerRequestId/durationSeconds/audioOwner`，方便和试听音色、后端 provider 日志交叉排查。
- 已有质量确认/试听相关后端 gate。

与 PRD 对齐：

- 对齐“声音复刻基础能力”和“数字人使用复刻音色”的方向。
- 对齐“密钥不下发到 iOS，统一后端代理”的安全要求。

仍需关注：

- “试听复刻声音是本人，但 Echo 数字人是否稳定使用本人音色”仍需真机端完整回归。
- 腾讯云渲染自带合成和跨供应商 PCM audio-drive 是两条不同链路，不能混用播放 owner。
- 复刻音色质量、成本、槽位管理、用户授权文案仍需产品和运营规则补齐。
- 真机上偶发 `sami error`、异常声响、前后几字没声等问题需要继续抓日志定位。

### 3.7 我的 / 个人资料 / 家庭 / 关怀

已实现：

- “我的”作为第三 Tab，未切成“长辈关怀”。
- 个人资料支持：
  - 昵称/名称。
  - 性别。
  - 地区。
  - 手机号展示/合同。
  - 保存中、成功、失败、网络异常、非法输入状态。
  - 本地持久化和 backend-ready client。
- 家庭成员：
  - 手机号邀请入口。
  - 邀请中、已加入、失败状态。
  - 不提供删除家人操作。
  - 后端 revoke/删除关系路线按当前规则返回不可执行合同。
- 关怀/心境追踪：
  - 关怀快照后端合同。
  - 最新/列表读取。
  - 空态、失败态、过期态和重试逻辑。
  - 已接入 P0 release regression gate。
- 账号注销：
  - 二次确认。
  - 不支持数据导出。
  - 提示数据保留 30 天。
  - 30 天内同手机号重新注册可恢复。
  - 恢复次数限制为 1 次。
  - 后端 soft delete、restore deadline、purge contract。

与 PRD 对齐：

- 对齐“我的”承载个人、家庭和关怀入口。
- 对齐家庭成员手机号邀请、不删除家人、账号注销 30 天保留和一次恢复的明确规则。

仍需关注：

- 真正的手机号注册/恢复链路需要结合认证体系进一步验收。
- 医生/干预/升级关怀仍未公开，属于后续产品决策。

## 4. 隐藏或未完全公开能力

以下能力当前不应被视为公开完整能力：

| 能力 | 当前状态 | 原因 |
| --- | --- | --- |
| 语音档案真实录音上传 | 有数据模型、详情、mock/隐藏 QA | 麦克风、录音质量、真机文件稳定性未完整验收 |
| 视频档案真实选择/压缩/上传 | 有 schema、缩略图占位、上传状态、失败/重试 UI | 真机视频选择、压缩、对象存储 PUT 未验收 |
| Echo 文本/图片输入 | flag 存在但默认隐藏 | PRD 当前主链路是语音优先 |
| 密码修改 | 壳层/合同存在，默认隐藏 | 安全策略未完成 |
| 医生联系/主动干预 | 占位/合同方向 | 医疗和合规边界未决策 |
| 数字继承完整生命周期 | 基础 persona/family 合同存在 | 产品、法律、权限生命周期未完整决策 |
| APNs provider delivery | 后端/本地通知合同存在 | 真机 APNs 到达证据不足 |

## 5. 后端接口实现概览

当前后端围绕 PRD 主线已经形成以下接口组：

### Runtime 与配置

- `GET /config/runtime`
- 暴露能力包括：
  - archive image analysis。
  - media upload intent。
  - voice realtime token。
  - voice clone。
  - voice synthesis。
  - Tencent audio-drive。
  - Tencent digital human session。

### 个人资料与账号

- `GET /profile`
- `POST /profile`
- 账号软删除、恢复、清理合同已实现于对应服务/路由中。

### 记忆档案

- `POST /archive/photos`
- `POST /archive/items`
- `GET /archive/items/{user_id}`
- `DELETE /archive/items/{item_id}`
- `POST /archive/image-analysis`
- `POST /archive/media/upload-intent`

### 时间信件

- 复用 `/archive/items` 的 `timeLetter` metadata。
- 封存后删除保护。
- 到期/投递状态字段已进入合同。

### 回响延迟回信

- `POST /echo/delayed-replies`
- `GET /echo/delayed-replies`
- `POST /echo/delayed-replies/dispatch-due`

### 推送设备

- `POST /devices/push-token`

### 家庭与关怀

- `POST /family/invite`
- `GET /family/members`
- `POST /family/members/accept`
- `POST /family/invitations/accept`
- `POST /care/snapshots`
- `GET /care/snapshots/latest`
- `GET /care/snapshots`

### 声音复刻与语音合成

- `POST /voice/profiles`
- `GET /voice/profiles/{profile_id}`
- `POST /voice/profiles/{profile_id}/refresh`
- `POST /voice/profiles/{profile_id}/quality-acceptance`
- `POST /voice/profiles/{profile_id}/disable`
- `DELETE /voice/profiles/{profile_id}`
- `POST /voice/synthesis`
- `POST /voice/realtime-token`

### 腾讯数智人

- `POST /digital-human/sessions`
- 由后端统一持有腾讯会话配置，iOS 只拿短期 session/credential。

## 6. 当前验证体系

### iOS 常用检查

- `git diff --check`
- iOS Debug 构建。
- 真机构建覆盖签名：
  - Team：本机可用开发团队。
  - Bundle ID：本机可用 bundle id。
- release QA package：
  - `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- 公开 MVP release regression：
  - `Scripts/QA/prd-stitch-ui/run-release-regression.sh`

### 核心业务 smoke

- Archive -> Echo：
  - `Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh`
- 关怀/心境追踪：
  - 已串入公开 MVP P0 gate。
- 时间信件：
  - `Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh`
- 隐藏媒体：
  - hidden media backend sync / UIQA combo gate。
- 声音复刻：
  - deployed backend smoke。
  - voice clone PCM drive QA gate。
  - quality acceptance gate。
- 腾讯数智人：
  - backend session smoke。
  - iOS true-device build/smoke 脚本。
  - Tencent backend PCM drive POC smoke。
  - Phase 1 非真机 gate：
    - `Scripts/QA/prd-stitch-ui/run-tencent-digital-human-phase1-non-device-gate.sh`
    - 可通过 `RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh` 接入 release regression。
    - 该 gate 明确不跑真机验证。

### 最近已知验证边界

- iOS 真机构建曾通过，App 可安装启动。
- 当前最后一次真机构建产物路径：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/true-device-debug-build/DerivedData/Build/Products/Debug-iphoneos/DreamJourney.app`
- 最近一次自动构建时设备处于不可用/离线状态，因此无法完成最后一段真机交互验证。
- 后端 deployed smoke 已验证过 voice clone runtime、ready profile refresh、Tencent audio-drive PCM 输出合同。

## 7. 当前主要缺口

### P0：必须继续收敛

1. 真机 Echo 数字人完整链路。
   - 数字人稳定加载。
   - 有声音。
   - 口型同步。
   - 可打断。
   - 停止后恢复麦克风。
   - App 重启后仍稳定显示。

2. 声音复刻进入 Echo 数字人。
   - 试听复刻音色已经能证明 provider 输出。
   - 仍需确认 Echo 数字人实际播放的是复刻音色，而不是腾讯默认音色或 fallback 音色。

3. APNs/provider delivery。
   - 本地通知和后端合同已存在。
   - 真机 APNs 到达、前后台行为和失败恢复仍未完整闭环。

4. 相册/麦克风/播放路由真机验收。
   - 模拟器和静态脚本不能替代真实设备权限、音频路由和前后台行为。

### P1：继续产品化

1. 数字人 asset 策略统一。
   - 当前代码已改为后端 session asset 优先。
   - iOS 包内 override 仅作为 QA/debug 手段。
   - 仍需产品/工程确认长期是否完全删除包内默认 asset key，还是保留 QA 覆盖能力。

2. 声音复刻成本和配额策略。
   - 后付费自定义音色、试用槽位、用户数扩张成本需要产品/运营决策。

3. 时间信件跨账号投递。
   - 已有本地和后端 metadata。
   - 需要补服务端定时任务、APNs、收件人视角消息中心。

4. 视觉 AI provider。
   - 当前有失败/重试合同。
   - 需要确定支持真实视觉输入的 provider 后验收人物/地点/场景线索质量。

### P2：质量和维护

1. 更新旧状态文档。
   - 2026-06-20 的实现说明已部分过期。
   - 需要避免“数字人仍隐藏”等旧口径误导后续同事。

2. 发布态截图和最终视觉 QA。
   - Stitch 更新后需要重新跑最终视觉对齐。

3. SDK 分发策略。
   - 腾讯 iOS SDK 当前已按工程策略处理，但如果 SDK 体积、授权或仓库策略变化，需要在 onboarding 文档中继续同步。

## 8. 给后续开发同事的接手说明

1. 拉取 iOS 当前分支后，代码层面可以编译当前工程。
2. 真机跑腾讯数智人需要：
   - 工程内包含腾讯云渲染 SDK。
   - 后端部署环境已经配置腾讯数智人会话参数。
   - 腾讯控制台对应 asset/project 有有效并发配额。
3. iOS 不应保存腾讯 appkey/accesstoken。
4. 声音复刻、TTS、PCM 转换都应走后端，不应在 iOS 直连火山/豆包密钥接口。
5. 如果修改数字人 asset：
   - 同时检查后端 `/digital-human/sessions`。
   - 检查 iOS 包内 `DreamJourneyDigitalHumanAssetVirtualmanKey` 是否覆盖了后端返回。
   - 跑真机 smoke，不要只看模拟器。
6. 如果修改 Echo 音频链路：
   - 必须明确 audio owner。
   - 避免 iOS 本地播放器、火山实时对话和腾讯云渲染同时抢占 `AVAudioSession`。
   - 停止按钮不应关闭数字人视图。

## 9. 建议下一步

### 2026-07-01 CFL-Lite Context Packet v0 更新

本轮在推进完整 CFL 方案前，先落地轻量 `Context Packet v0`：

- 后端新增 `/context/build`，聚合现有 archive、KB、care、voice profile、digital-human runtime 信息。
- 后端新增 `ContextPacketBuilder`，只使用现有 store 数据，不引入 Mem0 / Zep / Weaviate / Kafka / LangGraph。
- iOS `DreamJourneyBackendClient` 新增 `EchoContextPacket` 和 `buildEchoContextPacket(...)`。
- Echo 在每个 final 用户语音回合开始时请求 context packet，并只输出 `[CFLite]` trace 日志，不改变现有回复生成、数字人播放、复刻声音 PCM-drive 逻辑。
- release regression 新增 `context-packet-v0-check.swift`，防止 `/context/build` 客户端和 Echo trace 被误删。

当前可观测字段包括：

- `traceId`
- archive available/included 数量
- KB fact 数量
- `voiceProfileId`
- `cloneReady`
- `digitalHumanSessionReady`
- `digitalHumanProviderMode`
- `crossScopeArchiveIncluded`
- `fallbacks`
- `latencyMs`

这一步是 CFL v2 的前置状态：先证明结构化上下文和 trace 能稳定工作，再决定是否拆成独立 CFL 服务或引入检索/排序/压缩组件。

### 2026-07-01 CFL-Lite Context Packet v1 更新

本轮继续把 v0 从“散落日志”推进到“结构化 Echo Trace Record”，仍然不改变 Echo 回复生成、腾讯数字人播放、声音复刻 PCM-drive 或现有 UI。

后端 `/context/build` 更新：

- `schemaVersion` 从 `0` 升级到 `1`。
- `policy.privacyScope` 明确记录本轮上下文允许使用的数据边界：
  - `scope`
  - `scopeLabel`
  - `viewerUserId`
  - `ownerUserId`
  - `digitalHumanId`
  - `viewerFamilyMemberID`
  - `allowedArchiveScopes`
  - `allowedDigitalHumanIds`
  - `canUseFamilyData`
  - `crossScopeArchiveIncluded`
- 新增 `trace` 摘要，便于后续回放和排查：
  - `archiveItemIds`
  - `archiveItemKinds`
  - `archiveItemsIncluded`
  - `kbFactCount`
  - `voiceProfileId`
  - `voiceCloneReady`
  - `voiceOutputMode`
  - `digitalHumanSessionReady`
  - `digitalHumanProviderMode`
  - `fallbacks`
  - `privacyScope`
  - `crossScopeArchiveIncluded`
  - `latencyMs`

iOS 更新：

- `EchoContextPacket` 解析 v1 的 `privacyScope` 和 `trace.archiveItemIds`。
- 新增 `EchoTraceRecord`，将一轮 Echo 的档案、声音复刻、数字人、fallback 和 privacy scope 聚合成一条结构化记录。
- `EchoViewController` 新增 `lastEchoTraceRecord`，每个 final 用户语音回合成功构建 context 后会保存最近一轮 trace。
- Echo 日志新增 `[CFLite] trace record`，可以直接看到：
  - 本轮用了哪些档案 ID。
  - 是否有可用复刻音色。
  - 用的是哪个 `voiceProfileId`。
  - 数字人 session 是否 ready。
  - 为什么 fallback。
  - 是否混入跨 scope 档案。
  - context 构建耗时。

QA 更新：

- `context-packet-v0-check.swift` 已升级为 `context-packet-v1-check.swift`。
- release regression 和 release QA package 已改为检查 v1 guard。
- 后端单测覆盖 `privacyScope`、`trace.archiveItemIds`、`voiceProfileId`、`voiceOutputMode` 和跨 scope 档案隔离。

下一步如果继续走 CFL-Lite，建议优先做“Echo trace 持久化/导出”：

- 本地保留最近 N 轮 `EchoTraceRecord`。
- QA 一键导出 trace JSON。
- 真机问题反馈时直接拿 trace 对照后端 provider log、腾讯 session log 和声音复刻 log。

### 2026-07-01 Echo Trace 持久化与导出更新

本轮已补齐 CFL-Lite 的本地证据留存能力：

- 新增 `EchoTraceStore`。
  - 使用 `UserDefaults` 本地持久化最近 20 轮 `EchoTraceRecord`。
  - 超过 20 轮时只保留最新 20 轮。
  - 支持 `exportRecentRecords(...)` 导出 `echo-trace-records.json`。
- `EchoTraceRecord` 已支持 `Codable`，并新增 `recordedAt`，便于导出后按时间排序或对照日志。
- Echo 每次成功构建 `/context/build` 后：
  - 更新 `lastEchoTraceRecord`。
  - 写入 `EchoTraceStore.shared.record(record)`。
  - 继续输出 `[CFLite] trace record` 日志。
- 新增 QA launch arg：
  - `DJRunEchoTraceExportSmoke`
  - 该 smoke 会写入 `echo-trace-export-smoke-result.json`，验证 22 条 mock trace 只保留最新 20 条，最早保留 `uiqa-turn-2`，最新为 `uiqa-turn-21`。
- 新增静态 guard：
  - `Scripts/QA/prd-stitch-ui/echo-trace-export-check.swift`
  - 已接入 release regression 和 release QA package。

验证说明：

- `context-packet-v1-check.swift` 通过。
- `echo-trace-export-check.swift` 通过。
- `release-qa-package-check.swift` 通过。
- iOS Debug Simulator compile-only 构建通过。
- 模拟器交互安装 smoke 需要通过 installable simulator helper 执行，不能直接使用项目默认 Bundle ID，也不能用全局 `PRODUCT_BUNDLE_IDENTIFIER=...` 覆盖。

### 2026-07-01 Installable Simulator UIQA Bundle Guard

本轮固化本机模拟器 UIQA 构建/安装约束，避免后续真机/模拟器验证反复踩同一个坑：

- 新增共享脚本：
  - `Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh`
  - 默认本机 QA Bundle ID：`com.yxj.dreamjourney.app`
  - 默认本机 Team ID：`2BTR77V3R8`
  - 构建时只通过项目自有变量传入：
    - `DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER`
    - `DREAMJOURNEY_DEVELOPMENT_TEAM`
  - 明确禁止全局 `PRODUCT_BUNDLE_IDENTIFIER=...` 覆盖，避免 Pods framework bundle id 被一起污染。
  - 构建后校验 app bundle id、arm64 simulator 架构、ad-hoc 签名并安装到 booted simulator。
- 新增静态 guard：
  - `Scripts/QA/prd-stitch-ui/installable-simulator-uiqa-bundle-guard-check.swift`
  - 已接入 release regression 和 release QA package。
- 已迁移模拟器 UIQA smoke：
  - `run-archive-to-echo-smoke.sh`
  - `run-echo-delayed-reply-notification-smoke.sh`
  - `run-echo-trace-export-uiqa-smoke.sh`
- 新增 Echo Trace 可安装模拟器 smoke：
  - `Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh`
  - launch arg：`DJRunEchoTraceExportSmoke`
  - 结果文件：`echo-trace-export-smoke-result.json`
  - 导出文件：`echo-trace-records.json`
  - 断言最近 20 条 trace 保留规则：最早 `uiqa-turn-2`、最新 `uiqa-turn-21`。

执行方式：

```bash
RUN_ECHO_TRACE_EXPORT_UIQA_SMOKE=1 \
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

注意：

- 项目文件里仍可能存在协作默认值 `com.gaominge.dreamjourney.app`，但本机可安装 UIQA 一律不使用该默认值。
- 后续新增模拟器 UIQA smoke 必须复用 `run-installable-simulator-uiqa.sh`，不得自行拼接 `xcodebuild PRODUCT_BUNDLE_IDENTIFIER=...`。

后端部署说明：

- 服务器仓库已拉取到 `35449e5 feat: add context packet v1 trace`。
- Docker 重启需要服务器 `sudo`/docker 权限；当前会话无法完成容器重启。
- 在线 `/context/build` 当前仍返回 `schemaVersion=0`，重启后应返回 `schemaVersion=1`、`policy.privacyScope` 和 `trace`。
- 服务器侧需要执行：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --build
```

1. 先做真机数字人 + 复刻音色完整回归。
   - 重点验证 Echo 中实际使用复刻音色。
   - 验证腾讯数字人口型同步和打断恢复。

2. 统一数字人 asset 配置策略。
   - 明确是否继续保留 iOS 包内 override。
   - 如果保留，要在部署和测试说明中写清楚优先级。

3. 更新 PRD 覆盖矩阵。
   - 将自传式档案、数字人公开、声音复刻 PCM-drive、时间信件公开基础能力同步为已实现/待验收状态。

4. 继续补 release-like 后端验收。
   - 时间信件跨账号提醒。
   - voice clone quality acceptance。
   - image analysis provider fallback。
   - digital human session and PCM-drive contract。

5. 真机验收通过后再推进隐藏媒体公开化。
   - 录音档案。
   - 视频档案。
   - 更完整的家庭数字人生命周期。
