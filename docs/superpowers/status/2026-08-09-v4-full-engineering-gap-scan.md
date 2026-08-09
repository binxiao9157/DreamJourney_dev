# DreamJourney V4 全工程扫描与剩余开发清单

日期：2026-08-09
状态：`CURRENT_ENGINEERING_BASELINE / RELEASE_NO_GO`
范围：iOS、后端、数据库迁移、部署运行态、QA/Smoke、V4 产品边界
用途：回答“当前到底完成了什么、还要开发什么、哪些不是代码问题”。本文件是扫描报告，不替代 PRD 和执行计划。

对应执行计划：`docs/superpowers/plans/2026-08-09-dreamjourney-v4-complete-functional-development-plan.md`

## 1. 执行结论

当前工程已经形成较完整的 V4 合同、状态机、默认关闭策略和非真机证据，但尚未形成可对外发布的 V4 真实产品闭环。

需要严格区分三种完成度：

| 口径 | 当前判断 | 说明 |
| --- | --- | --- |
| 代码与合同覆盖 | 约 80%–85% | M0–M2 的模型、API、typed client、状态机、默认关闭、负向测试和 QA Gate 大多存在。 |
| 真实 Provider / 部署闭环 | 约 35%–45% | 数据库、API、ClamAV、部分火山合成已运行；短信、COS、OCR/ASR、强身份、媒体 Worker、腾讯数智人会话仍未真实启用。 |
| 可公开发布的 V4 功能 | 约 30%–40% | 当前公开 App 仍主要依赖旧档案/旧 Context 路径；V4 Owner Truth 与 M1/M2 大多 default-off、closed-pilot 或被外部门阻断。 |

因此：

- 不能把 26/26 非真机 Gate 通过解释为“产品已完成”。
- 不能把已有页面、mock Provider、shadow 路由或合同测试解释为“用户可用”。
- 当前统一结论仍为 `NO_GO`，原因不是基础代码无法运行，而是真实身份、媒体、运行 Worker、V4 主链路切换及外部 Provider 证据未关闭。

## 2. 本次扫描基线

### 2.1 代码版本与工作区

| 仓库 | 分支 / 提交 | 状态 |
| --- | --- | --- |
| iOS | `feature/prd-stitch-ui-adaptation@dfd55c82` | 与远端一致，工作区干净 |
| 后端 | `main@8a61720` | 与远端一致，工作区干净 |
| 服务器运行代码 | `e8eacc5` | API 运行代码；与仓库头的差异为后续文档提交，不影响当前 API 行为 |

### 2.2 实际验证结果

1. iOS workspace XCTest：296 项通过，0 失败。
2. iOS generic iPhoneOS Debug 构建：通过。
3. 后端 unittest：1973 项通过，0 失败。
4. 统一非真机闭环：26/26 命令通过，M0、Stage 2、M1、M2 四条 lane 均通过。
5. 线上 `/ready`：数据库读写、迁移 head、认证配置和 incident 状态均为 ready。
6. 两仓库 `git diff --check` 基线无差异。

证据：

- iOS 构建报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260809-131354-iphoneos-generic-build/report.md`
- iOS XCTest：`tmp/engineering-scan/WorkspaceDerivedData/Logs/Test/Test-DreamJourney-2026.08.09_13-17-21-+0800.xcresult`
- 非真机交接：`docs/superpowers/status/2026-08-09-v4-non-device-functional-closure-handoff.md`
- 非真机 manifest：`docs/superpowers/status/2026-08-09-v4-non-device-functional-closure-manifest.json`

注意：直接使用 `.xcodeproj` 运行测试会丢失 CocoaPods/腾讯 SDK 依赖；正确入口是 `DreamJourney.xcworkspace`。这属于构建入口约束，不是业务代码故障。

## 3. 当前真实运行态

### 3.1 已经运行的服务

- FastAPI API
- PostgreSQL
- Redis
- ClamAV sidecar
- 时间信件到期扫描 systemd timer
- 数据库备份、证据保留和备份保留审计 timer

### 3.2 尚未运行的后台执行器

Compose 已定义但服务器当前未启动：

- `async-effect-scheduler`
- `async-effect-worker`
- `business-message-worker`
- `owner-truth-media-worker`
- `owner-truth-worker`
- `publication-lifecycle-worker`

这意味着后端虽然已有异步任务、outbox、dead-letter、replay 和 receipt 代码，但真实生产任务不会自动完成。此项是实际功能阻断，不是单纯运维优化。

### 3.3 线上 capability 事实

| 能力 | 当前线上状态 | 直接影响 |
| --- | --- | --- |
| V2 身份 challenge / OTP | disabled | 新用户不能完成真实手机号身份闭环 |
| Owner Truth 媒体采集 | disabled | V4 图片、音频、文档、视频无法进入真实私有存储 |
| Owner Truth 媒体处理 | disabled | PDF/DOCX/OCR/ASR 处理 Worker 不会真实运行 |
| ClamAV | 已运行、clean/EICAR smoke 通过 | 仅证明扫描器可用，不等于 COS/媒体闭环已启用 |
| 图像 AI 分析 | DeepSeek text-only，`supportsVision=false` | 只能返回可重试失败合同，不能产生真实人物/地点/场景线索 |
| 声音复刻合成 | Provider ready | accepted profile 可合成；训练仍被身份/活体 Gate 阻断 |
| 声音复刻删除 | Provider 不支持真实删除回执 | 可先撤销使用权，但不能宣称第三方已删除 |
| 腾讯数智人 | blocked | 缺少可验证的 scoped/TTL/audience/revocation 会话 credential 合同 |
| Async effect | disabled | 外部副作用无法形成生产级自动完成与对账 |
| M0 closed-pilot cohort | 无实际入组用户 | 客户端不能自行开启，当前 V4 入口保持关闭 |

## 4. iOS 工程扫描

### 4.1 已有公开产品结构

- 三 Tab 固定为“记忆档案 / 回响 / 我的”。
- 公开默认能力主要是文字输入、个人资料、法律中心和账号注销。
- 当前 Stitch 全屏 Echo 和整体视觉结构仍保留。
- 未增加第四 Tab；M1/M2 未通过服务端 Gate 时默认不公开。

### 4.2 已实现但未成为公开主链路的能力

- Owner Truth Source、Candidate、人工确认、更正、MemoryVersion 历史。
- V2 私有媒体 typed client、上传/处理/失败/重试/删除状态恢复。
- 异步导出、部分完成、过期、删除和外部 effect 状态。
- 声音复刻训练/查询/试听/接受/合成/暂停/删除的 capability 消费。
- Publication、ShareGrant、Visitor、数字人、家庭和时间信件等 default-off/QA 壳层。

### 4.3 当前主链路冲突

1. “封存新记忆”在 V4 capability 未开放时仍回退到旧本地/旧档案路径。
2. 生产 Echo 仍主要调用旧 `/context/build`。
3. V4 Owner Truth context 目前主要用于 `/context-shadow/build` 和 QA 对比，并未成为普通 Echo 的唯一权威来源。
4. 旧 `/archive/items`、`/archive/media/upload-intent`、`/archive/image-analysis` 与 V2 Source/Candidate 路由同时存在。

这会导致“V4 代码存在，但普通用户仍走旧业务”的假完成感。后续重点应是有迁移保护的主链路切换，不是再新增第三套模型。

### 4.4 iOS 稳定性与维护风险

代码规模较大的文件：

- `MemoryArchiveViewController.swift`：约 17,156 行
- `OwnerTruthContracts.swift`：约 17,073 行
- `DreamJourneyBackendClient.swift`：约 11,242 行
- `EchoViewController.swift`：约 11,120 行
- `AppDelegate.swift`：约 6,417 行

明确需要处理：

1. `AppCoordinator.swift:835` 存在 `@MainActor` 丢失 warning，在 Swift 6 模式会升级为编译错误。
2. 多处 `UIButton.contentEdgeInsets` 与 CocoaLumberjack API 已废弃，但目前不阻断运行。
3. 大文件继续增加逻辑会提高回归风险，应在后续触碰对应功能时按领域拆分，不能启动无业务目标的大重构。
4. CI/同事验收命令必须统一使用 workspace，否则会产生假失败。

## 5. 后端工程扫描

### 5.1 已完成的基础能力

- FastAPI、PostgreSQL、Redis 和迁移体系稳定，当前 migration head 为 `0085`。
- 认证路由覆盖、Owner/Vault 合同、Source/Candidate/MemoryVersion、Context、数据导出/删除均有实现。
- Provider adapter、runtime capability、release policy、kill switch、outbox、dead-letter、replay、receipt 已建立。
- 文本、PDF、DOCX 本地解析器已实现；OCR/ASR 使用 provider-neutral port。
- M1 声音 profile 状态机与 Echo binding v2 已实现。
- M2 Publication/Visitor 合同和默认关闭策略已实现。

### 5.2 结构性维护风险

- `app/main.py` 约 15,900 行。
- `postgres_store.py` 约 8,108 行。
- `in_memory_store.py` 约 4,337 行。
- 后端已有 252 个 app Python 文件、314 个测试文件、85 组迁移，但入口和 Store 仍过度集中。

处理原则：只在后续接真实 Provider 或改主链路时拆出对应 router/service/repository，不进行一次性框架重写。

### 5.3 文档证据漂移

扫描时发现 `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md` 仍记录 iOS `8a1922b`、后端 `4c0538b`，其 Work Item 判断已不能直接用于排期。

该问题已由 F0-01 关闭。矩阵已更新为 V1.5，并同步：

- 当前提交和迁移 head
- 真实线上 capability
- 公开 / closed-pilot / default-off 暴露状态
- 非真机、外部 Provider、真机三类 Gate
- 旧路径与 V4 路径的实际调用关系

`Scripts/QA/product-v4/product-v4-current-evidence-baseline-check.py` 负责阻止旧提交基线、旧状态和历史快照重新成为当前口径。

## 6. V4 分阶段实际完成度

| 阶段 | 代码状态 | 真实可用状态 | 主要缺口 |
| --- | --- | --- | --- |
| M0 私人记忆资产 | 合同与非真机闭环较完整 | 未形成 V4 公开闭环 | 真实 OTP、COS、Worker、V2 主链路切换、cohort |
| Stage 2 媒体摄入与处理 | Source/Task/Candidate、解析器、状态 UI 已有 | 约处于部署准备态 | COS 配置、真实 Worker、OCR/ASR Provider、真实 E2E |
| M1 本人私有声音 | 状态机、合成、PCM 绑定和负向 Gate 已有 | 仅部分 Provider 可用 | 强身份/活体、训练/删除回执、真机音质与音频路由 |
| M2 发布/访客/在世数字人 | 合同、默认关闭和 QA 壳层已有 | 不具备发布条件 | 成年身份、安全/法律、索引、清理、腾讯 credential、受控 beta |
| M3 长辈健康/纪念互动 | 有硬拒绝和部分历史壳层 | 不应开发或开放 | 产品、医疗、风险处置和合规均未关闭 |
| M4 知识许可 | 有边界合同/硬拒绝 | 不应开发或开放 | 商业、权利、计费、监管均未决策 |

## 7. 必须开发清单

### P0：先形成真实 M0 闭环

#### P0-01 真实短信 OTP 与账号恢复

当前：provider-neutral 合同、限流、重放、恢复状态和 iOS typed client 已完成；线上 Provider 关闭。

需要开发/接入：

1. 选择一个短信 Provider，完成 adapter 的发送、查询/回执和错误映射。
2. 配置签名、模板、地域、测试号码和最小权限服务器凭据。
3. 将发送受理与真实送达区分，保留脱敏审计。
4. 验证登录、刷新、重发、限流、重放、注销后 30 天恢复和一次恢复上限。
5. Provider 失败时保持 fail-closed，不能回退 synthetic OTP。

完成 Gate：线上真实测试短信 E2E、跨账号负向、Postgres 持久化、iOS 登录 smoke。

#### P0-02 Ownership 从 shadow 切到 enforce

当前：191 条认证路由已有覆盖，但 cross-account ownership 仍是 shadow，`productionEnforceReady=false`。

需要开发：

1. 在真实 OTP 证据完成后跑全路由 ownership shadow 审计。
2. 修复仍可能依赖 client `userId` 的边界，统一从 access token subject 派生 Owner。
3. 对 Archive、Context、Family、Message、Export、Voice、Publication 做 A/B Owner 负向回归。
4. 分 cohort 开启 enforce，保留 kill switch 和审计回滚。

完成 Gate：线上 shadow 无未解释差异，受控 cohort enforce 通过，未授权请求稳定 401/403/404。

#### P0-03 腾讯 COS 真实私有存储

当前：COS adapter、HTTPS/region/SSE 校验、HEAD/readback/delete smoke、ClamAV fail-closed 均已编码；服务器没有真实 bucket 配置。

需要开发/配置：

1. 创建专用私有 bucket，固定 region、HTTPS endpoint、SSE 和保留策略。
2. 创建只允许指定前缀 PUT/HEAD/GET/DELETE 的服务端最小权限凭据。
3. 配置 closed-pilot 测试租户，不在仓库存储密钥。
4. 跑 `PUT -> HEAD -> readback -> ClamAV -> delete -> HEAD 404`。
5. 验证 MIME 伪装、哈希不匹配、过期 intent、跨 Owner/Vault、重复提交和删除竞争。

完成 Gate：真实 COS E2E 与删除 receipt 通过，runtime 才允许对 cohort 开启 media storage。

#### P0-04 启动并生产化异步 Worker

当前：任务、lease、outbox、dead-letter、replay 和 readiness 代码已存在；服务器只运行 API/DB/Redis/ClamAV。

需要开发/运维：

1. 逐个启动 `owner-truth-worker`、`owner-truth-media-worker` 和 async-effect worker/scheduler。
2. 为每类 job 固定并发、lease TTL、重试预算、dead-letter 和 drain 行为。
3. 接入 backlog、open dead-letter、最后成功时间和 readiness epoch 监控。
4. 验证容器重启、重复 dispatch、旧 generation、毒消息和人工 replay。
5. 队列积压、扫描器不可用或删除异常时自动关闭对应 capability。

完成 Gate：部署态 Postgres/COS 合成账户 E2E 能在不人工触发 API 内部函数的情况下自动完成。

#### P0-05 文档/OCR/ASR 真实处理

当前：文字、PDF、DOCX 本地解析已实现；图片 OCR、音频 ASR、视觉分析没有真实 Provider；视频明确 storage-only。

需要开发：

1. 先将 PDF/DOCX Worker 接真实 COS 读取并产出来源片段 Candidate。
2. 为 OCR 和 ASR 各选择一个 Provider，固定数据地域、保留、超时、费用与删除政策。
3. 实现 adapter、结果版本、输入版本、输出哈希、置信和失败分类。
4. Provider 不可用时显示明确 unavailable/retryable，不生成虚假人物/地点/转写。
5. Candidate 必须人工确认后才进入 MemoryVersion/Context。

完成 Gate：文档真实 E2E；OCR/ASR 格式矩阵、损坏文件、超时、删除竞争和跨账号负向 smoke。

#### P0-06 “封存新记忆”切换到 V2 Owner Truth

当前：V4 入口存在，但 capability 关闭时仍走旧档案创建路径。

需要开发：

1. 定义旧文字/照片记录到 Source/Candidate/MemoryVersion 的迁移或兼容读取策略。
2. closed-pilot 账户的文字、图片、音频、文档入口统一走 V2。
3. 去除 V4 cohort 内部对旧 `/archive/items` 写路径的回退。
4. 保留旧记录只读兼容，避免破坏现有用户资料。
5. 迁移失败必须可恢复并保留证据，不能双写出两个权威版本。

完成 Gate：新建、处理、审核、更正、版本历史、删除、账号切换完整回归；旧数据仍可读。

#### P0-07 Echo Context 权威链路切换

当前：普通 Echo 使用旧 `/context/build`；V4 Owner Truth context 主要停在 shadow/QA。

需要开发：

1. 将 V4 Context Builder 作为 closed-pilot 账户的主路径。
2. 保留旧 Context 只做短期 shadow 比较，不参与最终回答。
3. 只允许 confirmed/current MemoryVersion 进入确定性上下文。
4. 草稿、失败分析、撤权、删除、跨 Owner、未到期信件不得进入。
5. 输出 selected/filtered/ranking trace，并与 Echo evidence 包关联。
6. shadow 差异稳定后按 cohort 移除旧回退。

完成 Gate：Archive -> Candidate -> MemoryVersion -> Echo E2E、越权负向、删除后不再命中、延迟和 fallback 预算。

#### P0-08 M0 closed-pilot 正式入组

当前：release policy/cohort 代码已完成，但线上没有实际获准账户。

需要开发/运维：

1. 建立服务端审批 allowlist，不接受客户端自报 cohort。
2. 为媒体采集、处理、Candidate、Context、导出和删除分别授权。
3. 支持能力级 kill switch、限额、预算和审计。
4. 建立 3–10 个非生产个人数据的受控测试账户。
5. 未入组用户保持当前公开三 Tab 和旧稳定能力，不看到未验收入口。

完成 Gate：授权/未授权账户对照、退出 cohort、回滚、capability 失效和旧客户端策略过期测试。

#### P0-09 数据导出与删除真实外部闭环

当前：ExportJob、CopyExportManifest、撤权优先和五域 effect receipt 已实现；真实媒体字节、Provider 删除与备份边界仍是 partial/unsupported。

需要开发：

1. 导出实际 COS 媒体字节，生成用户可读包和机器 manifest。
2. 将 COS、声音、数字人、通知和备份的真实删除结果写入 receipt。
3. Provider 未确认时保持 pending/partial/unknown，不能显示完成。
4. 建立 reconcile worker、人工处理队列和过期证据。
5. 验证 30 天恢复不会错误复活已被 Provider 删除的数据。

完成 Gate：创建、导出、撤权、删除、恢复、超期清理和重复请求 E2E。

#### P0-10 生产运行与恢复证据

需要补齐：

1. Worker/Provider 指标、告警和 kill-switch runbook。
2. 数据库定期恢复演练，不只证明备份任务成功。
3. COS 删除、ClamAV 签名更新时间、队列积压和 dead-letter 告警。
4. 服务器仓库所有权和部署账号收敛，解决普通部署账号无法安全 pull、root 缺远端凭据的问题。
5. `.env.backup*` 私密备份的保留、隔离和销毁策略；已有风险豁免不等于可长期无管理堆积。

完成 Gate：一键部署、回滚、恢复演练和 incident 证据均不依赖个人机器临时操作。

### P1：M1 本人私有声音

#### P1-01 成年身份与活体 Provider

1. 接入可验证“在世成年人本人”的强身份/活体 Provider receipt。
2. receipt 绑定 owner、用途、时效和一次训练 generation。
3. 未成年人、逝者、家人代录、缺少同意或过期 receipt 必须服务端拒绝。
4. 不把普通手机号 OTP 当作声音复刻身份资格。

#### P1-02 声音 Provider 生命周期真实闭环

1. 使用真实测试账户完成训练、轮询、试听、人工接受和 accepted 后合成。
2. 固定 voiceProfileId、slot、样本版本、profileVersion 和 Provider 回执。
3. 旧轮询、重复请求、暂停/删除后的旧 PCM 不能进入 Echo。
4. 当前 Provider 不支持删除：需要确认替代 API/商务能力，或明确长期 `unsupported/partial` 产品文案和保留政策。
5. 不允许失败时静默换成腾讯默认音色并冒充复刻成功。

#### P1-03 Echo 复刻音色生产验收

1. accepted profile 必须走 `/voice/synthesis` + `outputMode=tencentAudioDrive`。
2. 角色、owner、profileVersion、用途、textHash 与 PCM 绑定必须一致。
3. 账号/角色切换、停止、过期和旧 generation 必须取消旧音频。
4. Evidence 必须可追踪 voiceProfile、providerLogId、audioOwner 和失败原因，但不泄露原文/PCM。

### P1：M2 Publication / Visitor / 数字人

只有 M0、成年人身份、安全/法律 Gate 关闭后才进入此组。

#### P1-04 Publication / ShareGrant 真实索引与撤回

1. 将 PublicationVersion 写入独立 Visitor 查询索引，不能直接暴露私人 MemoryVersion。
2. 分享授权、撤回、过期、索引清理和 Provider 清理均需真实 receipt。
3. 收件人只看主动发布的副本；家庭关系不自动获得 Persona/私人档案。

#### P1-05 腾讯数智人 scoped session 合同

当前 iOS 静态项目 credential 被判定不满足移动端安全边界，线上数字人因此 blocked。

需要：

1. 与腾讯确认服务端可签发的 session credential 是否具备 scope、TTL、audience、revocation。
2. 若支持，后端 broker 签发短期 credential，iOS 不保存 appkey/accesstoken。
3. 若不支持，不能通过恢复静态移动端 key 绕过 Gate，应选择 H5/服务端渲染替代接入或保持文字 Echo。
4. 实现会话 lease、心跳、释放、配额、重连和上一角色隔离。

#### P1-06 M2 安全、法律和发布产品面

1. 成年身份、持续 AI 标识、退出、敏感内容回退和 incident runbook。
2. 地域、分包商、跨境、保留、内容安全、算法/AI 标识和用户协议评审。
3. 受控 beta 通过后再将 QA 壳层转为正式入口；不新增第四 Tab。

### P2：工程稳定性与可维护性

1. 优先修复 `AppCoordinator.swift` 的 Swift 6 actor 隔离 warning。
2. 在功能改动涉及到时逐步拆分五个超大文件；不做独立“大重构项目”。
3. 统一 CI 使用 workspace，固化 iOS XCTest、generic build、后端全量测试和统一 release Gate。
4. 将 warning 区分为 App-owned、三方 SDK 和仅废弃提示；只批量处理可机械验证的低风险项。
5. 持续运行 V4 当前证据基线检查，阻止过时提交基线和状态回归。
6. 将 Provider、Worker、Context、Voice、Digital Human 的 readiness/evidence 统一到可导出报告。

## 8. 需要外部配置或决策，不应继续用 mock 代替

| 外部项 | 所需输入 | 阻断能力 |
| --- | --- | --- |
| 短信 Provider | 供应商、签名、模板、地域、测试号、服务器凭据 | 新用户登录/恢复 |
| 腾讯 COS | bucket、region、HTTPS endpoint、SSE、保留、最小权限凭据 | V4 私有媒体 |
| OCR/ASR | Provider、地域、保留、费用、删除政策 | 图片文字/音频转写 |
| 成年身份/活体 | Provider 与合规 receipt | M1、M2 |
| 火山声音删除 | API/商务能力或明确不支持政策 | 声音数据权利完整态 |
| 腾讯数智人 | 短期 scoped credential 合同、资产、配额 | M2 数字人 |
| Publication 外部索引 | 存储/索引/清理回执 | Visitor beta |
| 法律与安全 | 地域、分包商、跨境、未成年人、第三方材料、成本止损线 | M2 发布批准 |

仍需对照决策登记册收敛的重点：`DR-009`、`DR-017`、`DR-022`、`DR-026`、`DR-027`、`DR-031`、`DR-034`、`DR-035`。其中部分代码边界已经实现，但产品/法务/Provider 证据尚未关闭，必须更新登记册，不能靠代码自行判定通过。

## 9. 需要真机验收，不属于继续堆代码

1. M0：相册/文件选择、权限、前后台切换、大文件、弱网、旧任务恢复。
2. M1：录音质量、扬声器/听筒/蓝牙路由、复刻音色听感、PCM 有声、打断和麦克风恢复。
3. M2：腾讯数智人长会话、口型、声音同步、重连、配额和后台恢复。
4. APNs：真实 token、Provider delivery、前后台通知到达与点击路由。

这些项目应在对应真实 Provider 和 closed-pilot 开启后验收；提前反复跑真机无法替代尚未启用的服务器能力。

## 10. 当前明确不开发或不公开

1. M3 长辈健康、医生/干预和危机协同。
2. M4 知识许可、计费和商业化市场。
3. 逝者声音复刻或逝者数字人。
4. 未成年人声音/数字人。
5. 家庭成员自动继承私人 Persona 或全部记忆访问权。
6. 第四 Tab 或以“长辈关怀”替换当前“我的”。
7. 视频语义理解；首版保持私有存储、元数据和状态，不伪造分析。
8. 时间信件、关怀等延期能力的公开放出；现有合同保留，除非产品重新纳入当前里程碑。

## 11. 推荐执行顺序

### Wave 0：证据和工程门（1–2 个开发日）

- 更新实现证据矩阵。`COMPLETE (F0-01)`
- 修复 Swift 6 actor warning。
- 固化 workspace CI 和部署账号/runbook。

### Wave 1：真实身份（3–5 个开发日 + Provider 配置）

- P0-01 真实 OTP。
- P0-02 ownership shadow 审计与 closed-pilot enforce。

### Wave 2：真实媒体（5–8 个开发日 + COS 配置）

- P0-03 COS。
- P0-04 Worker。
- P0-05 PDF/DOCX 真实 E2E，OCR/ASR 按 Provider 顺序接入。

### Wave 3：V4 主链路切换（5–8 个开发日）

- P0-06 创建入口切 V2。
- P0-07 Echo Context 切 V4。
- P0-08 closed-pilot 入组。

### Wave 4：数据权利与运行态（3–6 个开发日）

- P0-09 真实导出/删除。
- P0-10 Worker、恢复、告警和部署标准化。

### Wave 5：M1（5–10 个开发日 + 身份/声音 Provider）

- P1-01 强身份/活体。
- P1-02 训练/接受/删除回执。
- P1-03 Echo 真实音色与真机验收。

### Wave 6：M2（必须单独批准）

- Publication/Visitor 外部索引与撤回。
- 腾讯数智人 credential broker 或替代方案。
- 安全/法律 Gate、受控 beta、真机长会话。

以上工期只估算已知代码工作，不包含供应商审核、短信模板审批、COS/身份服务采购、法务评审或真机问题修复时间。

## 12. 下一步唯一建议

先执行 **P0-01 真实 OTP Provider 接入** 与 **P0-03 COS 外部配置准备** 两条并行前置；代码主线优先 P0-01，运维/产品同时准备 COS。原因：没有真实身份就不能安全开启 cohort，没有 COS 就不能让 Stage 2 从合同态进入真实数据闭环。

在外部配置未到位时，不应继续新增 mock 页面或重复扩展合同；可实施的内部工作仅限剩余 Wave 0、Worker 部署脚本、V2 主链路切换保护和证据基线维护。

## 13. 扫描后的发布判断

当前可确认：

- 工程可构建、自动测试稳定。
- 非真机合同覆盖较完整。
- 线上 API、数据库、迁移和 ClamAV 健康。
- V4 Provider 能力默认关闭和 fail-closed 基本有效。

当前不可确认：

- 真实新用户能够登录。
- V4 私有媒体能够上传、处理和删除。
- V4 Owner Truth 已成为普通 Echo 的唯一权威来源。
- 声音复刻训练和第三方删除已完成真实闭环。
- 腾讯数智人满足移动端 credential 安全要求。
- M2 可以公开发布。

最终结论：`ENGINEERING_BASELINE_HEALTHY / NON_DEVICE_COMPLETE / EXTERNAL_AND_PRODUCTION_CUTOVER_INCOMPLETE / RELEASE_NO_GO`。
