# DreamJourney V4 剩余功能加速闭环计划

日期：2026-08-05
状态：`IN_PROGRESS`
日常开发唯一入口：本文件

## 1. 计划口径

本计划以当前两个仓库的已提交实现为基线，目标是尽快完成 **不依赖真机的 V4 功能开发**。

- iOS 基线：`feature/prd-stitch-ui-adaptation@307abfb3`
- 后端基线：`main@069bc6f`；P0-S1 至 P0-S4 已完成代码和部署态非真机验证。
- 已完成且不再重复开发：M0 的 Wave 0-6（Owner Truth、引导式访谈、双推荐、数据权利/Family 基础、三 Tab M0 UI、统一非真机 Gate），以及 Stage 2 的 iOS B1-B5。
- 当前不计入完成条件：真机权限、真实短信送达、APNs 到达、真实 OCR/ASR 质量、真实 Voice/Digital Human 听感与配额、签名和设备性能。
- 但不把 `mock`、`shadow`、`default-off` 或静态检查误写为已发布功能；它们只能算相应 Slice 的代码完成。

日常执行时只读取本文件的“当前执行指针”、对应源码/测试、最近提交和工作区差异。阶段切换或产品范围冲突时，才回查 V4 产品定义。

## 2. 当前事实与剩余范围

| 能力域 | 当前状态 | 仍需完成的功能工程 |
| --- | --- | --- |
| M0 Owner Truth / 访谈 / 推荐 / M0 UI | `FUNCTIONAL_VERIFIED` | 不重复实现；仅在后续改动影响其边界时回归。 |
| Stage 2 媒体 | 上传、处理、Candidate handoff、iOS 状态、私有对象删除/回执与部署态 Postgres smoke 已完成 | 真实对象存储、处理 Provider 与 closed-pilot 运行配置仍按独立外部 Gate 收敛。 |
| 手机号 OTP | 通用服务端 adapter 与 fail-closed 已完成 | 真实短信供应商仅在获得明确 Provider 后配置，不阻塞其他功能开发。 |
| Worker / Scheduler | lease、outbox、worker profile、drain/重启/死信与部署态运行证据已完成，默认关闭 | 真实 closed-pilot 启用仍需独立运维批准。 |
| 数据权利 | owner scope、导出/删除状态、统一外部 effect 回执、脱敏证据投影已完成 | 对象、Voice、DH、通知、备份的真实 Provider 执行与上游回执。 |
| M1 本人私有声音 | 训练/试听/合成/PCM/DH 技术资产已存在 | V4 所需资格、样本状态、单一路径、暂停/删除和非真机 Gate 收敛。 |
| M2 Publication / Visitor / DH | 领域模型、迁移和 G0 合同存在 | 正式 API、独立公开 Projection、ShareGrant/Visitor、iOS 产品面和撤回传播。 |
| M3/M4 | `EXTERNAL_BLOCKED` | 不在本计划自动启动；只维持 server-side deny 与入口隔离。 |

## 3. 当前执行指针

已完成：`P0-S1`、`P0-S2`、`P0-S3`、`P0-S4`、`P1-S1`、`P1-S2`、`P1-S3`、`P1-S4`、`P2-S1`。当前执行：`P2-S2：ShareGrant、Visitor 与安全回答。`

完成当前 Slice 后，不停留等待，按本文件顺序进入下一个未完成 Slice。只有缺少真实 Provider、不可逆生产迁移、数据删除授权或重大产品决策时才暂停。

## 4. P0：完成 R1 的私有媒体与 M0 生产依赖

### P0-S1：Stage 2 私有对象生命周期闭环

**状态**：已完成。删除阻断、重试 generation、typed receipt、dead-letter、Owner 负向验证和部署态 PostgreSQL smoke 均已有证据；真实对象存储启用仍属于外部 Gate。

**目标**：让已上传 SourceObject 的删除成为真实状态机，而非单纯数据库标记。

实施：

1. 复用现有 `owner_truth_media_source_object`、async effect 和 data-rights 模型，增加删除请求、读取阻断、处理取消和 provider-effect receipt 的正式合同。
2. 删除请求一旦接受，立即阻断下载、重新处理和 Candidate 继续生成；已在途处理必须在提交前重验对象状态。
3. 统一公开给客户端的状态：`accessRevoked`、`pending`、`partial`、`unsupported`、`completed`；不得把数据库 tombstone 当成物理删除完成。
4. 同一删除命令幂等；失败可重试；新的重试 generation 不得复活已撤权对象。
5. iOS 只展示脱敏状态、重试和结果，不保存对象 key、私有 URL 或 provider 错误正文。

验证：后端单测、迁移 upgrade/rollback、disposable Postgres delete/retry smoke、A/B Owner 负向验证、iOS typed-state XCTest/模拟器 UIQA、`git diff --check`。

完成定义：SourceObject 删除后的读取/处理/Candidate/Context 均被正确阻断；本地与服务端状态一致；默认公开发布态不暴露 Stage 2 功能。

### P0-S2：常驻 Worker 与 Scheduler 运行闭环

**状态**：已完成。job family、唯一 consumer lease、heartbeat、drain/restart、dead-letter/replay 和默认关闭的 Compose profile 已完成部署态非真机验证。

**目标**：将已存在的 lease/profile 基础收敛为可部署的异步运行时，不让 API 同步伪装任务成功。

实施：

1. 将 Candidate extraction、Projection、媒体处理、删除、消息五类任务注册为明确 job family；每类任务只有一个 active consumer lease。
2. 完成 claim、heartbeat、lease expiry、drain、重启恢复、dead-letter、人工 replay 和重复 command/effect 的幂等策略。
3. 统一 worker profile 与 scheduler profile 的配置、readiness、暂停和安全退出；默认仍为关闭，按 closed-pilot job family 独立启用。
4. 加入部署 Postgres smoke：双 worker 竞争、半途崩溃、旧 lease 提交、dead-letter replay、drain 后零消费。

验证：现有 async-effect/worker/scheduler 测试、容器 disposable Postgres smoke、部署 `/ready`、worker restart smoke、`git diff --check`。

完成定义：每类任务有可证明的唯一 active consumer；未知完成状态不重复执行副作用；API、worker 和 scheduler 的完成语义清晰分离。

### P0-S3：数据权利外部回执收敛

**状态**：已完成。迁移 `0078`、追加式 hash-only 回执、跨账号拒绝、历史状态折叠、脱敏证据投影及部署态 disposable Postgres smoke 已通过。真实 Provider 的删除/停用动作仍留在后续对应 Slice，不能据此宣称外部数据已物理删除。

**目标**：将对象、Voice、数字人和通知的撤销/删除结果统一纳入已有数据权利模型。

实施：

1. 以既有 data-rights/provider-effect receipt 为基础，为每个外部域定义 `pending / partial / unsupported / completed` 的最小回执字段与查询投影。
2. 账号删除、授权撤销、SourceObject 删除和 Voice/DH 停用共享同一“先阻断访问，后执行外部 effect”的语义。
3. 导出 manifest 仅披露外部处理状态、保留期和未完成项，不泄露 provider 标识、对象 key 或密钥。
4. 为无 Provider 配置的域保留 `unsupported` 或 `pending`，不伪造 completed。

验证：跨域 receipt 单测、Postgres idempotency/重放 smoke、导出脱敏检查、跨账号拒绝、release scope regression。

完成定义：用户能获得准确且可解释的删除/撤销状态；没有一个外部域能通过写 `deleted=true` 绕过真实 receipt。

### P0-S4：M0 DFX 最小生产基线

**状态**：已完成。`m0-dfx-baseline-v1` 已将 Context、Stage 2 媒体/Candidate/Projection 和
跨 Vault/撤权组合为固定合成回归证据；部署容器 smoke 在 `069bc6f` 通过，`7/7` 样本成功。
报告明确标记队列年龄、SQL 数、进程资源和 Projection 时钟为 `notMeasured`，不输出生产性能
承诺。

**目标**：先建立可重复测量，而不是无证据优化。

实施：

1. 为 Context、Projection、Candidate/媒体任务记录统一的耗时、队列年龄、失败分母、SQL 数、Context 大小和资源指标。
2. 使用固定 synthetic 数据集运行检索、跨 Vault、撤权、Projection lag 和重复任务基线；报告携带 commit、环境、数据规模、并发、窗口和失败样本。
3. 将阈值视为告警/回归门，不为了满足数字提前引入新数据库、缓存或微服务。

验证：固定基线脚本、结果 schema 检查、部署容器 smoke、回归阈值测试、脱敏证据包。

完成定义：每次后端发布都能产出可比较的 DFX 报告；未测项目保持明确未测，不输出性能承诺。

**P0 Gate**：Stage 2 删除、Worker/Scheduler、权利回执和 DFX 均完成代码/部署态非真机证据；真实 SMS、OCR/ASR 和设备测试仍可单列为外部 Gate。

## 5. P1：M1 在世成年人本人私有声音非真机闭环

### P1-S1：资格、同意与 voiceProfile 状态机

**状态**：非真机合同完成，默认关闭。服务端现在只接受可信资格来源；客户端提交的资格字段不再能授权训练或合成。profile 生命周期、显式试听接受、旧 profile fail-closed、Family/未成年人/跨账号 hard deny 和 iOS 脱敏投影均已有回归证据。真实的服务端年龄/活体资格回执 Provider 仍是外部启用条件，未满足前 M1 不得公开启用。

1. 基于现有 `voice_dh_authority`、`voice_dh_consent_policy` 和训练 preflight，固定“在世本人 + 强身份/成年人结果 + purpose + consent version + expiry”缺一不可。
2. 将 profile 状态统一为：`draft`、`uploadPending`、`training`、`previewReady`、`accepted`、`paused`、`deleting`、`deleted`、`failed`；禁止 Provider `ready` 自动等于用户已接受。
3. Family 代录、未成年人、逝者和跨账号 profile 在服务端 hard deny；iOS 只消费脱敏资格结果。

### P1-S2：样本、质量与试听确认合同

**状态**：非真机合同完成，默认关闭。服务端只接受 `voice-sample-v1` 的 PCM16 单声道 WAV 样本，完成格式、10–30 秒时长、10MB 上限与基础信噪/响度/削波测量；iOS 仅允许选择该可验证格式。每次提交前，服务端签发并绑定 owner/profile 的短时随机授权语句，iOS 必须展示并经用户显式确认后才携带 receipt 提交。失败训练仅能用同一 profile、同一 provider slot 和递增 `retryGeneration` 的 CAS 重试；旧试听回执会失效，用户试听成功后仍须显式接受才会进入 `accepted`。真实语句 ASR 校验、活体/年龄 Provider 和真实训练听感仍为后续外部/真机 Gate，不能据此宣称已完成生产验证。

1. 固定样本版本、格式/时长/SNR 校验、随机授权语句和本人确认 receipt。
2. 训练失败只能在同一 profile/slot 的明确 retry generation 内重试，禁止静默切换其他音色。
3. 试听成功后由用户显式接受，才把 profile 提升为 `accepted`。

### P1-S3：Echo 单一路径与角色选择

**状态**：非真机合同完成，默认关闭。`/voice/synthesis` 的 Tencent PCM 响应现在绑定 profile、owner、role、persona scope、数字人 ID、用途、output mode 和 audio owner；iOS 仅接受与当前本人角色完全匹配的绑定。无可用 profile、绑定不匹配或 provider 失败均进入可解释的非复刻回退，不能复用旧角色、其他用户或默认腾讯音色。模拟器 PCM mock 已验证分片、最终帧、顺序与打断清理。

1. `accepted` profile 唯一可走 `/voice/synthesis?outputMode=tencentAudioDrive`；输出 PCM 与 profile/owner/role 绑定。
2. 无 accepted profile 只允许中性默认声音或文字模式，并有可解释的状态；Provider 失败不得落回其他用户、旧角色或未授权声音。
3. 保持腾讯 audio-drive 为 Echo 的唯一音频 owner；本地播放器仅用于试听。

### P1-S4：暂停、删除与退出

**状态**：非真机合同和 QA 已完成，默认关闭。暂停、删除、账号删除和合成使用同一 owner 串行边界；删除先撤销本地使用权，再持久化去标识化的 async effect / Provider-effect `accepted` 回执。没有上游回执时只显示 `pending/partial`，不会把本地 tombstone 或 outbox 受理误报为 Provider 清理完成。真实 Provider 删除执行器和上游回执对账仍是外部启用 Gate。

1. 暂停立即拒绝新合成；删除写 provider effect 并保留 receipt。
2. 未收到 provider 回执时维持 `pending/partial`；账号删除与授权撤销同步关闭 profile 使用权。
3. iOS QA 证据展示 `voiceProfileId`、`roleVoiceSource`、`outputMode`、`audioOwner`、`providerLogId`，但普通用户不可见。

验证：mock provider、PCM 合同、角色切换/旧回调隔离、删除重放、iOS XCTest、模拟器 UIQA、普通 M0 release regression。

**P1 Gate**：M1 的全部非真机合同与 QA 完成，仍默认关闭；真实 Provider 训练/删除与真机听感独立进入后续验收，不阻塞 M0。

## 6. P2：M2 Publication / Visitor / 在世数字人闭环

### P2-S1：Publication Authority 与独立公开副本

**状态**：已完成，仍为内部 QA-only 且默认关闭。后端 `main@b8c36ef` 的 `0079/0080` 已部署，生产数据库迁移账本为 `0080`；隔离 Postgres smoke 已验证 Owner fence、并发确认重放、独立公开副本不可变、直接身份信息拒绝，以及 Source/MemoryVersion/Vault 变化后的自动阻断。未携带 QA 条件的内部写路由在认证前统一返回 `404`，没有新增 Visitor 或公开读取入口。

1. 在既有 `0050-0057` 上补正式 Owner API：仅可选择 active、confirmed MemoryVersion；草稿有脱敏预览、第三方提示和二次确认。
2. 发布生成不可变 `PublicationVersion` 和独立 Public Projection；禁止从 private Projection、KBLite 或 `isPrivate=false` 快捷公开。
3. Source/Memory 修正、删除、撤权或争议发生时，先阻断新读取，再安排独立索引清理。

### P2-S2：ShareGrant、Visitor 与安全回答

1. ShareGrant 绑定 publication version、scope、TTL、usage limit、成人资格和撤回状态；Family 关系不自动授权，匿名访问关闭。
2. Visitor 仅可读取独立 Public Projection；回答必须带 AI 身份、来源/不确定性和“不知道”路径。
3. 高风险表达、持续会话阈值和医疗/金融/支付限制走服务端 policy，不能由客户端绕过。

### P2-S3：iOS 产品面与在世数字人 scope

1. “我的”承载发布管理、预览和授权状态；Visitor 经受邀入口进入，不新增第四 Tab。
2. M2 关闭时，入口、深链、缓存和降级路径都不得泄露；M2 session 失败只能回退 M2 文字 Visitor，不能回退私人 Echo。
3. 数字人会话、声音和 Visitor session 使用同一 publication/grant scope 与 expiry；退出/撤回立即释放 session 与音频。

### P2-S4：撤回、争议、删除传播

1. 撤回先阻断访问，再处理 Public Index、缓存、grant、数字人 session 和 Provider 资产。
2. 第三方异议进入 `suspended/conflictHold`；不可由最后写入者直接覆盖。
3. 每一步写可重放、可查询、脱敏的 receipt。

验证：后端 API/负向策略/迁移、A/B visitor isolation、独立 projection Postgres smoke、iOS 模拟器发布/访问/撤回 UIQA、M2 default-off regression。

**P2 Gate**：只形成 default-off 的内部 closed beta 功能；成年人核验、法务/隐私、Provider 成本和真机为独立外部 Gate，未关闭不得公开发布。

## 7. P3：统一非真机发布证据

在 P0-P2 功能完成后，不新增产品功能，只收敛证据：

1. 将 M0、Stage 2、M1、M2 分别接入统一 release gate；每个 lane 产生独立 evidence bundle。
2. 强制后端全量测试、迁移 replay/rollback、部署 Postgres E2E、worker restart、A/B authorization、provider failure；iOS 强制 XCTest、模拟器 UIQA、generic iPhoneOS build、release scope regression。
3. 输出明确剩余项：`DEVICE_REQUIRED`、`EXTERNAL_PROVIDER_REQUIRED`、`PRODUCT_OR_LEGAL_REQUIRED`；不生成“全部完成”的笼统结论。

## 8. 并行与提交规则

| Lane | 可并行内容 | 不可并行边界 |
| --- | --- | --- |
| Backend Authority | P0-S1、P0-S2、P0-S3 依次实施 | 同时只能有一个人修改 owner-truth writer、effect kernel 或 data-rights writer。 |
| iOS Consumer | 已冻结的后端合同对应 typed client、状态 UI、UIQA | 不自行推测字段或提前公开入口。 |
| Independent QA | 固定 smoke、迁移/静态检查、证据包 | 不修改业务 writer 或生产开关。 |
| M1 / M2 | P0-S2 合同稳定后可分别并行 | 共用 AuthZ、ReleasePolicy、provider-effect 时由主控串行合并。 |

每个 Slice 必须：先补最小测试/检查，再实现；运行相关测试、smoke、`git diff --check` 和适用构建；后端通过后单独提交、推送、部署并跑线上 smoke；iOS 通过后单独提交。未经明确要求不推送真机包，不开启 default-off 功能。

## 9. 明确不进入本计划的事项

1. M3 老人健康、成人纪念互动、M4 知识许可/收益；保持 deny/default-off，等待独立产品、法律和运营计划。
2. 真机麦克风、相册、通知、播放路由、数字人听感、蓝牙、弱网性能和签名验证。
3. 未选定的真实 SMS/OCR/ASR/Voice/DH Provider 的账号配置、成本、DPA、配额和删除回执。
4. 与 V4 闭环无关的 UI 重构、Stitch 视觉改版或替换现有 Owner Truth/KBLite 主链。

## 10. 完成后的交接标准

功能开发完成时，必须能明确回答：

- M0、Stage 2、M1、M2 各自启用什么能力、默认是否关闭、谁可访问、何时撤回；
- 每个异步副作用由哪个 worker 执行、如何恢复、如何避免重复；
- 每个外部 Provider 的成功、失败、未知和删除状态如何回执；
- Echo/Voice/Digital Human 何时只能使用已授权 profile/publication，何时必须降级或拒绝；
- 哪些事项只剩真机或外部验收，而不是尚未实现的代码。
