# DreamJourney V4 剩余工程功能闭环计划

日期：2026-08-03
状态：`READY_TO_EXECUTE`
iOS 基线：`41378921`（`feature/prd-stitch-ui-adaptation`）
Backend 基线：`2f5ba8a`（`main`）
日常开发唯一入口：本文件

## 1. 计划定位

本计划基于当前真实代码、已部署证据和 V4 终版产品目标，接替
`2026-08-02-dreamjourney-v4-remaining-functional-closure-plan.md` 的后续功能开发。

旧计划已完成其原定的 Wave 0-6：M0 文字主链、引导式访谈、双推荐、数据权利、
家庭静态贡献、公开 M0 UI 和统一非真机发布门。旧计划继续作为历史验收证据，
不再作为后续功能开发清单。

本计划只解决尚未形成真实产品闭环的部分：

1. Stage 2 私有媒体摄入与处理；
2. M0 生产依赖收敛；
3. M1 在世成年人本人私有声音；
4. M2 在世主体主动发布、Visitor 和在世数字人；
5. 必要的统一发布门与集中真机验收；
6. M3/M4 在产品、法律和外部 Gate 未满足前保持明确阻断。

执行时每轮只读取：本文件当前 Slice、相关源码/测试、最近提交和工作区差异。
只有阶段切换、产品范围冲突或 Gate 变化时才回查 V4 Product Spec 与决策登记册。

## 2. 当前真实完成基线

| 能力域 | 当前可复用实现 | 真实剩余缺口 | 当前判定 |
| --- | --- | --- | --- |
| M0 Owner Truth | Source、Candidate、确认、MemoryVersion、Projection、Context、Citation、Correction 已完成部署 Postgres 闭环 | 真机权限与真实身份 Provider 验收 | `NON_DEVICE_FUNCTIONAL_VERIFIED` |
| 引导式访谈与推荐 | 自然输入、会话边界、批量确认、连续性/完整性推荐、Life Map 已完成后端与模拟器验证 | 真实用户体验与真机回归 | `NON_DEVICE_FUNCTIONAL_VERIFIED` |
| M0 数据权利与 Family | owner-bound session、跨账号拒绝、导出/删除、静态家庭贡献已完成部署 smoke | 真实短信、Provider 删除回执和运营流程 | `PARTIAL_EXTERNAL` |
| Stage 2 媒体 | 后端已实现私有上传、filesystem/S3/COS 适配、内容扫描接口、PDF/DOCX、本地文本提取、OCR/ASR 端口、重试和迁移 `0073/0074` | 尚未部署；iOS 未接新接口；真实对象存储、OCR/ASR 和删除回执未验收 | `BACKEND_FOUNDATION_ONLY` |
| M1 Voice | 已有声音训练/查询/试听、合成、Echo PCM audio-drive、腾讯数字人 runtime 与大量 QA 合同 | 主体/活体/质量 Gate、真实 Provider 删除、试听与 Echo 一致性、真机五轮验收未关闭 | `PARTIAL_DEVICE_PROVIDER_REQUIRED` |
| M2 Publication/Visitor | 已有迁移 `0050-0057`、draft/projector/share-grant/safety/lifecycle 的 G0 领域代码 | 无正式产品 API、独立公开读取链、iOS 产品面、真实成年校验和发布 Gate | `CONTRACT_ONLY_DEFAULT_OFF` |
| M3/M4 | 已有部分 hard deny、memorial/care/schema 资产 | 产品、法律、合规、Provider 和运营 Gate 未满足 | `EXTERNAL_BLOCKED` |
| 生产运维 | migration、UoW、Job/Outbox、release policy、readiness 和大量 deployed smoke 已有 | Stage 2 worker、真实 SMS、真实媒体 Provider、容量/恢复基线仍需补齐 | `PARTIAL` |

以下内容不得重新开发：M0 Owner Truth Authority、KBLite 兼容边界、三 Tab、全屏 Echo、
引导式访谈基础状态机、双推荐基础算法、已有数据权利模型和家庭静态贡献合同。

## 3. 完成目标与发布里程碑

### R1：M0 + Stage 2 Closed Pilot

用户可以在现有“记忆档案”中上传文字、图片、音频、PDF/DOCX 和视频文件；文件先进入
私有 SourceObject，状态、失败、重试和删除可见；文本/PDF/DOCX 可生成待确认 Candidate，
图片 OCR 和音频 ASR 只有在用户授权且 Provider 可用时运行；视频只存储，不伪造理解结果。

### R2：M1 私有本人声音 Closed Beta

完成强身份和成年人校验的在世本人可以录制/上传授权样本、训练、试听、启用、暂停和删除
自己的音色。Echo 使用同一已验收 voiceProfile；Provider 失败不得静默换成其他音色。

### R3：M2 在世主体 Publication / Visitor / Digital Human Closed Beta

在世成年人主动选择已确认 MemoryVersion，生成独立、脱敏、可撤回的 PublicationVersion；
完成成年人校验的受邀 Visitor 只读取公开副本。数字人只能使用该 Publication 与明确授权的
声音/形象，不能读取私人 Projection 或 Family 私人关系。

### R4：统一候选发布包

M0、Stage 2、M1、M2 分别形成独立 release policy、kill switch、证据包和退出结论。
未通过 G3/G4 的阶段继续关闭，不阻塞已通过阶段。

## 4. 优先级与连续执行顺序

优先级固定为：`P0 Stage 2 + M0 生产依赖` -> `P1 M1 Voice` ->
`P2 M2 Publication/Visitor/DH` -> `Gate-bound M3/M4`。

除独立测试工作外，不跨阶段提前实现公开 UI，不并行修改同一 Authority writer。

## 5. Phase A：Stage 2 后端部署闭环

目标：把 Backend `2f5ba8a` 的本地基础推进到部署 Postgres 可用状态。

### A1. 部署现有 Stage 2 基础

- 部署 Backend `2f5ba8a`，执行迁移 `0073`、`0074`；
- `/ready` 必须报告数据库、schema、auth 和 worker 依赖状态；
- 先启用私有 filesystem volume 或已批准的 S3/COS 私有 Bucket；
- 保持 OCR、ASR 和公开入口关闭。

验证：`scripts/verify_backend.sh`、
`scripts/run-backend-owner-truth-media-processing-gate.sh`、迁移 replay/rollback、
部署后隔离 Postgres smoke、跨 Owner 404、无公开 URL/对象 key 泄漏。

### A2. 新增部署态媒体 E2E smoke

- 创建 upload intent；
- 上传固定 text/PDF/DOCX fixture；
- Worker 消费后生成 `import` Source；
- Candidate extraction 只生成待确认项；
- 重放命令不重复创建对象、Source 或 Candidate；
- 失败三次后收敛为终止失败，人工重试创建新的 processing generation。

产物：正式的 `run-backend-owner-truth-media-processing-deployed-smoke.sh` 和脱敏报告。

### A3. 私有对象生命周期与删除

- SourceObject 删除先阻断读取和后续处理；
- 对象存储删除使用 outbox/provider effect，保存 receipt；
- `pending / partial / unsupported / completed` 与数据权利状态一致；
- 删除失败可重试，不把数据库 tombstone 冒充物理删除完成；
- 备份保留和 purge 状态可披露。

**Phase A Gate**：部署环境可稳定完成私有文件上传、处理、重试和删除状态闭环；客户端
或日志中不存在对象凭据、私有 URL、原文和 Provider 密钥。

预计：2-3 个集中工程日。

## 6. Phase B：Stage 2 iOS 产品闭环

目标：复用现有档案 UI，把旧 mock/local-only 媒体路径切到新的 Owner Truth SourceObject。

### B1. Typed client 与本地状态

- 新增 SourceObject upload intent、content upload、status read、processing retry 合同；
- 使用 AccountLease、vault ID、command ID 和 cancellation/generation fence；
- 本地只保存必要 receipt 和待上传文件，不保存 server object key；
- App 重启后恢复上传/处理状态，账号切换后不串数据。

### B2. 统一创建入口

- “封存新记忆”继续作为通用创建器：文字、图片、音频、文档、视频；
- “相册影像/语音档案”等卡片只做分类浏览，不重复触发创建；
- 图片/音频选择是否允许外部 OCR/ASR 必须显式确认；
- 视频文案明确为“已保存，暂不分析”。

### B3. 状态、失败与重试

- UI 统一展示：待上传、上传中、已验证、排队中、处理中、已处理、失败、可重试；
- 区分“云端文件未同步”和“文件已同步但 AI/Provider 暂不可用”；
- 终止失败保留“重新处理”，无需重新选文件；
- 取消、后台恢复和旧回调不能覆盖新一代状态。

### B4. Candidate handoff

- 处理成功的文字只进入待确认 Candidate；
- 用户确认后才进入 MemoryVersion/Projection/Context；
- failed/unconfirmed 内容不得进入 Echo 确定性回答、推荐或 Publication；
- 详情可追溯到 SourceObject、派生 Source 和 Candidate，但不暴露内部 ID 给普通用户。

### B5. UIQA 与发布范围

- 模拟器用固定文档、图片、假音频和假视频完成正向/失败/重试/重启 UIQA；
- closed-pilot 由服务端 release policy 授权；普通 release 默认隐藏；
- 保持三 Tab 和现有 Stitch 视觉，不重构档案首页。

**Phase B Gate**：不使用 QA header 和本地假状态时，closed-pilot 模拟器可完成
`选择文件 -> 上传 -> 处理 -> Candidate -> 确认 -> Context`。

预计：3-5 个集中工程日。

## 7. Phase C：M0 生产依赖收敛

目标：把 M0 从“部署可验证”推进到真实 closed-pilot 可运营。

### C1. 真实手机号 OTP Adapter

- 保留现有 `/v2/auth/challenges` 合同；
- 接入一个服务器侧短信 Provider adapter，客户端不持有短信密钥；
- 覆盖发送、限流、过期、错误次数、重放、换号/丢号恢复和号码冲突；
- synthetic adapter 仅允许测试环境，生产配置错误时 fail closed。

### C2. 常驻 Worker 与 Scheduler

- Candidate extraction、Projection、媒体处理、删除和消息任务使用明确的 worker profile；
- 每类任务只有一个 active lease，支持 drain、重启、死信和人工 replay；
- API 进程不以同步副作用冒充异步投递完成。

### C3. 数据权利外部回执

- 对象、Voice、Digital Human 和通知 Provider 分层记录删除/撤销结果；
- 不支持项明确显示 `unsupported`，不可用单一 `deleted=true` 覆盖；
- 导出 manifest 说明第三方裁剪和仍处于保留期的数据。

### C4. DFX 最小生产基线

- 跑固定数据集的检索延迟、跨 Vault、撤权、Projection lag 和重复任务测试；
- 建立 p50/p95/p99、失败分母、SQL 数、Context 大小和资源使用基线；
- 先测真实基线，再决定是否优化，不为追逐文档目标进行无证据重构。

**Phase C Gate**：真实手机号账号可进入 M0 closed pilot；关键 worker 可恢复；导出/删除状态
可解释；Owner Truth 在部署环境不存在跨账号、重复写和静默失败。

预计：3-5 个集中工程日，不含短信采购和运营审批等待。

## 8. Phase D：M1 在世成年人本人私有声音

目标：收敛现有火山声音复刻、后端 TTS、腾讯 audio-drive 和 Echo 代码，形成单一真实链路。

### D1. Authority 与资格 Gate

- 只允许完成强身份和成年人校验的在世本人；
- Family 代录、未成年人和逝者路径服务端 hard deny；
- 保存 purpose、授权文本版本、样本版本、撤销和 expiry；
- voiceProfile 不能只凭 Provider `ready` 自动视为用户已验收。

### D2. 样本与质量流程

- 随机授权语句、录音时长/格式/SNR 检查、本人确认；
- 状态统一：草稿、待上传、训练中、待试听、已接受、已暂停、删除中、已删除、失败；
- 失败可重试但不跨 voice slot/profile 静默替换。

### D3. Echo 单一路径

- 有 accepted voiceProfile：`/voice/synthesis?outputMode=tencentAudioDrive`；
- 无 accepted profile：明确使用中性默认声音或文字模式，并在 UI 披露；
- Provider 失败：明确失败，不使用其他用户、其他角色或旧角色音色；
- Echo audio owner 只有 Tencent audio-drive；本地播放器仅用于试听。

### D4. 禁用、删除和退出

- 暂停立即阻断新合成；
- 删除进入 provider effect，保存 providerLogId/receipt；
- 未获得删除回执时保持 `pending/partial`；
- 账号注销和撤销授权同步关闭 Echo 使用权。

### D5. 非真机 Gate

- mock Provider 合同、PCM 格式、角色 voiceProfile 选择、旧回调隔离、删除重放；
- iOS QA evidence 显示 voiceProfileId、roleVoiceSource、outputMode、audioOwner、providerLogId；
- 普通 M0 release 在 M1 policy 关闭时仍完整可用。

### D6. 集中真机 Gate

- 试听音色与 Echo 音色一致；
- 有声、口型动、可点击打断、停止后恢复麦克风；
- 连续五轮无前字丢失、尾音、异常声、旧角色声音或双数字人；
- 前后台、耳机/扬声器切换、弱网和 Provider 失败可恢复。

**Phase D Gate**：G3 Provider 和 G4 真机均通过后才可标记 M1 Beta；否则代码保留但服务端关闭。

预计：4-6 个集中工程日，另加 Provider 与真机验收时间。

## 9. Phase E：M2 Publication / Visitor / Living Digital Human

目标：在不读取私人 Projection 的前提下，实现独立、可撤回的在世成年人授权互动域。

### E1. Publication Authority API

- 基于现有 `0050-0057` 和 domain 代码补正式路由；
- Owner 只能选择 active confirmed MemoryVersion；
- draft 支持脱敏预览、第三方内容提示和二次确认；
- publish 生成不可变 PublicationVersion，不保存私人查询快捷入口。

### E2. 独立 Public Projection 与读取角色

- Publication projector 使用独立表/索引/数据库读取角色；
- 不允许 `isPrivate=false`、私人 Projection filter 或 KBLite 直接公开；
- Source 删除、Memory 修正/删除、异议或 grant 过期先暂停访问，再清索引。

### E3. ShareGrant 与 Visitor principal

- 只允许已验证成年账号，或完成成年校验的限次/过期邀请；
- grant 绑定 publicationVersion、scope、TTL、usage limit 和撤回状态；
- Family 关系不自动获得 grant；匿名访问保持关闭。

### E4. Visitor QA 与安全

- Visitor 只检索独立 Public Projection；
- 持续 AI 身份披露、来源、不确定性、“不知道”、举报和确定性退出；
- 连续两小时提醒、高风险表达切换中性安全助手；
- Persona 不参与医疗、金融、支付和重大现实决策。

### E5. iOS 产品面

- “我的”承载发布管理和授权状态；
- 分享预览明确显示公开范围、第三方裁剪和撤回后果；
- Visitor 通过受邀入口进入，不新增第四 Tab；
- M2 关闭时不存在入口、深链、旧缓存或回退泄漏。

### E6. Living Digital Human 组合

- 只消费已发布 Persona/Memory 副本与已授权声音/形象；
- 腾讯 session、声音和 Visitor session 使用同一 scope/expiry；
- session 失败回退 M2 文字 Visitor，不回退私人 Echo；
- 退出或撤回立即释放 session 并阻断后续音频。

### E7. 撤回、争议和删除传播

- 撤回先阻断新访问；
- Public Index、缓存、share grant、数字人 session 和 Provider 资产分层 receipt；
- 第三方异议触发 suspended/conflict hold，不由最后写入者覆盖。

### E8. M2 Gate

- G0：合同、负向策略和迁移；
- G1：模拟器发布/访问/撤回 UIQA；
- G2：部署 Postgres、独立角色、索引重建和跨域隔离；
- G3：数字人/Voice Provider 配额、删除、成本和退出；
- G4：成年人、隐私/法律、安全评估、算法备案、投诉和真机。

**Phase E Gate**：G4 未关闭时只能做内部 closed beta/default-off，不得公开发布。

预计：8-12 个集中工程日，不含监管、法务和供应商等待。

## 10. Phase F：M3/M4 明确阻断与启动条件

M3 老人健康、成人纪念互动和 M4 知识许可不在本轮自动实现。当前只维持：

1. 未成年人虚拟亲属、Family 代录、无专项授权逝者声音/肖像/DH 永久 deny；
2. Care、TimeLetter、Memorial interaction 和知识许可默认关闭；
3. 旧入口、深链、缓存和 Provider 回调不能绕过服务端 policy；
4. 产品/法律/隐私/运营分别给出 GO、适用地域、责任主体、退出和删除规则后，
   才为对应阶段建立独立计划。

这些阶段保持 `EXTERNAL_BLOCKED` 不降低前述 R1-R3 的真实完成度，也不能被标记为已完成。

## 11. Phase G：统一发布门与集中设备验收

### G1. 非真机统一 Gate

- Backend 全量测试、lint/compile、migration upgrade/rollback/replay；
- 部署 `/ready`、Postgres E2E、A/B owner isolation、worker restart 和 provider failure；
- iOS 静态检查、XCTest、模拟器 UIQA、release scope regression；
- `git diff --check` 和 generic iPhoneOS build；
- 每个阶段独立 evidence bundle，不输出误导性的单一“全部完成”。

### G2. 真机集中验收

只在非真机 Gate 全绿后执行：

- M0：登录/刷新、相册/文件/麦克风权限、前后台、通知跳转、弱网和重启；
- Stage 2：真实文件选择、上传恢复、照片/音频授权与大文件边界；
- M1：训练/试听/Echo 音色一致、PCM audio-drive、口型、打断和音频路由；
- M2：受邀 Visitor、撤回即时阻断、数字人 session 生命周期和长会话。

签名、Provider、配额或法规阻断只影响对应阶段，不得阻断 M0 文字核心。

## 12. 并行协作边界

为缩短日历时间，可固定三条并行 Lane：

| Lane | 负责内容 | 不得并行修改 |
| --- | --- | --- |
| Backend Authority | schema、route、service、worker、provider adapter、部署 | 同一 migration、`app/main.py` 同一区域、同一 Authority writer |
| iOS Product | typed client、状态机、页面、模拟器 UIQA | `OwnerTruthContracts.swift` 和 Echo audio lifecycle 同时只允许一个 owner |
| QA/Release | fixture、negative corpus、deployed smoke、evidence bundle | 不修改生产逻辑以迎合测试 |

合同冻结后 iOS 与 QA 才可并行；涉及身份、Owner Truth、Publication writer、Voice audio owner
的变更必须由主控 agent 串行收敛。

## 13. 每个 Slice 的固定完成定义

一个 Slice 只有同时满足以下条件才算完成：

1. 改变真实用户流程或生产 Authority 行为，不只是新增文档、flag、mock 或 shadow；
2. 正向、失败、重试、重启、重复请求和跨账号负向按风险覆盖；
3. iOS 变化通过相关静态检查/XCTest/模拟器 UIQA/generic build；
4. 后端变化通过单测、全量验证、迁移和 Postgres smoke；
5. 后端功能完成本阶段 Gate 后推送、部署并跑线上 smoke；
6. `git diff --check` 通过，iOS 与 Backend 独立提交；
7. 状态只允许 `FUNCTIONAL_VERIFIED / DEVICE_REQUIRED / EXTERNAL_BLOCKED`，
   default-off、contract-only 或 provider 未验收不得冒充完成。

## 14. 预计工作量与最快路径

| 里程碑 | 顺序工程量 | 三 Lane 合理并行后的日历量级 | 外部等待 |
| --- | ---: | ---: | --- |
| R1：Stage 2 Closed Pilot | 5-8 人日 | 3-5 个集中开发日 | 对象存储/OCR/ASR 采购可后置 |
| M0 生产依赖 | 3-5 人日 | 2-4 个集中开发日 | SMS 与运营流程 |
| R2：M1 Voice Beta | 4-6 人日 | 3-5 个集中开发日 | Provider、配额、真机 |
| R3：M2 Closed Beta | 8-12 人日 | 6-9 个集中开发日 | 身份、法务、监管、Provider |
| 统一 Gate/真机 | 3-5 人日 | 2-4 个验收日 | 签名、设备、账号 |

不含外部等待，剩余可直接开发的功能约为 23-36 人日；三条 Lane 不冲突并行时，
现实日历量级约 14-23 个集中开发日。缩短时间的方式是复用现有领域代码、先冻结合同、
按阶段交付，不是跳过 Authority、删除、跨账号和失败验证。

## 15. 当前唯一下一步

从 `A1` 开始：确认 Backend `2f5ba8a` 已推送但尚无 Stage 2 部署证据，部署迁移
`0073/0074`，保持 OCR/ASR 和公开入口关闭，运行现有 media processing Gate，并补一条
部署态隔离 Postgres E2E。A1/A2 通过后，再启动 iOS `B1` typed client；不重新进入
Owner Truth、访谈或推荐基础开发。
