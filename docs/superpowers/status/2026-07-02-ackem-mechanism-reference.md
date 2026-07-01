# Ackem 可借鉴机制梳理

日期：2026-07-02

## 结论

Ackem 和 DreamJourney 的产品形态不同。Ackem 是 Windows 桌面端本地 AI 伴侣平台，DreamJourney 是 iOS 端记忆档案、数字人回响和亲友照护产品。因此本工程应借鉴 Ackem 的底层机制，不应照搬桌宠、插件市场、游戏模式、微信通道或电脑助手等平台化能力。

当前最值得吸收的是：记忆可解释、上下文 trace、语音能力抽象、运行 readiness、本地数据导出，以及轻量能力注册表。

## 1. 回响线索可解释

### Ackem 机制

Ackem 的记忆页围绕归档、搜索、时间线、知识图谱、关联网络、情绪热力图和衰减曲线组织，让长期记忆不是黑箱。

### DreamJourney 借鉴方式

DreamJourney 不需要完整复制这些视图，但 Echo 每轮回响应能解释“为什么这样回应”。建议新增一个轻量的回响线索说明：

- 本次 Echo 使用了哪些档案条目。
- 使用了哪些 KBLite 人物、地点、事件、事实。
- 哪些线索来自亲友 persona 或 care snapshot。
- 每条线索的权限：`localOnly`、`generationAllowed`、`familyCircle`。
- 每条线索的来源：本地档案、KBLite 提取、后端 context packet、用户手动编辑。

### 落地边界

第一阶段只做内部 QA/隐藏诊断入口，不急于做公开复杂图谱。公开 UI 可先用“本次回响参考了 3 条档案线索”这类轻量提示。

## 2. Context Packet Trace

### Ackem 机制

Ackem 在对话前构建上下文，并通过 trace 记录记忆、扩展、工具、检索和最终消息组装结果，方便定位问题。

### DreamJourney 借鉴方式

本工程已开始做 `echo context packet v1 trace`，应继续制度化。每轮 Echo 应保存一份可导出的 trace：

- `turnId`、`sessionId`、`userId`、`personaId`。
- 档案线索列表和过滤原因。
- KBLite facts / events / people 命中结果。
- 后端 `/context/build` 返回的 context packet。
- digital human runtime capability。
- voice clone runtime capability。
- TTS / PCM drive / fallback 结果。
- 最终是否进入数字人驱动、音频回放或静音 fallback。

### 验收要求

真机问题不能只靠截图判断。每个 Echo 真机验收包应包含：

- iOS 本地 trace 文件。
- 后端 context packet 响应。
- 数字人 session 响应。
- voice synthesis 响应摘要。
- 失败路径的 `fallbackReason`。

## 3. 语音运行时抽象

### Ackem 机制

Ackem 将 ASR、TTS、TTS engine health、取消、重启和状态事件统一在本地 voice service 后面。

### DreamJourney 借鉴方式

DreamJourney 不应引入 Ackem 的 Python voice-service，因为现有路线是火山语音、腾讯数智人和后端代理。应借鉴其抽象方式，建立统一的语音运行时状态：

- `VoiceRuntimeCapability`
- `VoiceCloneRuntimeCapability`
- `TTSProviderStatus`
- `DigitalHumanAudioDriveStatus`
- `AudioOwner`
- `FallbackReason`

Echo 页面只消费这些状态，不直接散落判断“腾讯是否可用、声音复刻是否可用、PCM 是否成功、是否恢复收音”。

### 目标状态

Echo 的音频链路应能明确回答：

- 当前音频所有者是谁：火山 TTS、本地预览、腾讯数字人、静音 fallback。
- 声音复刻是否已授权、训练中、可合成、禁用或删除。
- 数字人是否 cloudRender、mockContract、audioOnly 或 failed。
- PCM drive 是否完成 chunk 发送、final chunk、播放完成、恢复录音。

## 4. Readiness 与降级态

### Ackem 机制

Ackem 对 embedding、provider、模型下载、预热和 degraded 状态有明确 readiness。

### DreamJourney 借鉴方式

DreamJourney 应建立隐藏诊断面板或 QA readiness 报告，集中检查：

- 后端 `/health` 可达。
- `/config/runtime` 可读。
- `/voice/realtime-token` 可取。
- `/digital-human/sessions` 可创建。
- `/voice/synthesis` 可合成。
- APNs token 已注册并同步后端。
- KBLite 本地 JSON 可读。
- 档案上下文可进入 `/context/build`。
- care snapshot 和 family viewer 权限可验证。

### 验收价值

这个机制可以减少“真机能跑但不知道哪里坏”的情况。每次发布前输出 readiness 快照，作为 release QA 证据之一。

## 5. 本地数据导出与迁移

### Ackem 机制

Ackem 对本地数据目录、记忆归档、导入导出和清空有明确入口。

### DreamJourney 借鉴方式

DreamJourney 的长辈记忆数据更敏感，应提供更强的数据可控性：

- KBLite JSON 导出。
- 回忆录文本和音频导出。
- 档案媒体元数据导出。
- Echo trace 导出。
- 用户删除账户时的数据删除摘要。
- 迁移到新设备时的数据包结构说明。

### 落地边界

第一阶段先做 QA/调试导出，不承诺公开迁移体验。公开迁移需要单独设计隐私、加密和授权流程。

## 6. 轻量 Capability Registry

### Ackem 机制

Ackem 通过插件、skills、gamemode 和 runtime catalog 管理能力，并让上下文构建知道哪些能力可用。

### DreamJourney 借鉴方式

DreamJourney 不需要插件系统，但需要一个轻量能力注册表。建议把后端 runtime config 和 iOS runtime capability 统一成固定结构：

- `digitalHuman`
- `voiceClone`
- `archiveImageAnalysis`
- `archiveMediaUpload`
- `familyCare`
- `pushNotification`
- `contextPacket`
- `tts`

每个 capability 至少包含：

- `enabled`
- `provider`
- `realProviderReady`
- `fallbackMode`
- `contractVersion`
- `lastCheckedAt`
- `debugSummary`

### 工程收益

这样可以避免各页面重复解析 runtime config，也方便后端 acceptance runner 和 iOS 真机 QA 对齐。

## 不建议借鉴的能力

以下 Ackem 能力不适合当前 DreamJourney 主线：

- 插件市场和 OpenForU 用户自创扩展。
- Minecraft 游戏模式。
- 桌宠主动骚扰。
- 微信通道。
- 电脑助手。
- Electron 桌面 IPC 复杂架构。

这些能力会稀释 DreamJourney 的移动端记忆回响定位，短期不应进入路线图。

## 推荐落地顺序

1. 固化 Echo context packet trace，并把真机验收证据包标准化。
2. 做“本次回响线索”隐藏 QA 面板，展示档案、KBLite、persona、care snapshot 命中。
3. 抽象 Echo 语音/数字人运行时状态，统一 fallback 原因。
4. 建立 readiness 报告，覆盖后端、数字人、声音复刻、APNs、KBLite。
5. 增加 KBLite、回忆录、Echo trace 的调试导出。
6. 将 runtime config 收敛为轻量 Capability Registry。

## 成功标准

- 每次 Echo 回响都能解释使用了哪些记忆线索。
- 每次失败都能定位到上下文、后端、声音复刻、TTS、PCM drive、数字人或通知链路。
- 每次 release-like backend acceptance 与 iOS 真机 QA 都能输出同一套 capability 和 trace 证据。
- 新机制不改变当前 3-Tab 产品结构，不引入平台化插件复杂度。
