# DreamJourney V4 剩余非真机功能闭环计划

日期：2026-08-08  
状态：`ACTIVE_R3_PRODUCT_SURFACE`
日常非真机开发唯一入口：本文件

## 1. 目标

在不依赖真机、真实 COS 凭据、真实短信、强身份/活体 Provider 或 M2 法律放行的前提下，完成当前工程仍可独立实施的 V4 功能开发，并把每个外部条件收敛为明确、可验证、默认关闭的 Gate。

本计划完成后，应只剩：

1. 真实 Provider 配置与生产回执。
2. 真实设备上的权限、音频、数字人和媒体验收。
3. M2 上线前的法律、安全、运营和备案结论。

## 2. 当前工程基线

- iOS：`feature/prd-stitch-ui-adaptation@204393e4`
- 后端：`main@3556b60`
- 两个工作区在本计划创建时均与远端同步且无未提交修改。
- 前置生产计划：`2026-08-06-dreamjourney-v4-production-functional-closure-plan.md`
- 前置统一证据：`docs/superpowers/status/2026-08-06-v4-unified-non-device-evidence-p3-s2.md`

前置计划继续约束真实 Provider、部署、真机和发布决策；本文件取代它作为日常非真机开发顺序。不得在两个计划中重复开发同一功能。

## 3. 已完成且不得重做

| 域 | 当前事实 | 后续只允许做什么 |
| --- | --- | --- |
| A0 Provider 能力 | 后端 inventory、fail-closed、iOS typed consumer 已完成并部署 | 仅在新增能力时扩展原模型 |
| A1 存储代码 | 单一腾讯 COS adapter、HTTPS/SSE、HEAD 校验、授权读取、删除回执已完成 | 等配置；只修真实 smoke 暴露的问题 |
| A1.1 扫描代码 | ClamAV sidecar、离线/超时/签名库异常 fail-closed 已完成 | 等容量和部署；不再增加第二套扫描器 |
| A2 文档处理 | text/PDF/DOCX 解析、Candidate handoff、来源和失败状态已完成 | 等 COS E2E；不提前接 OCR/ASR/视觉 |
| B3 安全退出 | 账号切换、退出、删除、旧任务回调和缓存隔离已完成 | 回归受影响链路 |
| C0-C1 声音资格/生命周期 | admission、training/preview/accepted、暂停/删除回执合同已完成 | 接真实 Provider 前保持默认关闭 |
| C2 Echo 复刻链路 | accepted profile、Tencent PCM audio-drive、故障注入与证据 Gate 已完成 | 最终仅补真实 Provider/真机证据 |
| M0 产品结构 | 三 Tab、Archive、Echo、Profile、Candidate/Memory 基础交互已存在 | 只补缺失状态和真实路由，不重做视觉 |

## 4. 执行规则

1. 每次只推进一个 `ND-*` Work Item，开始前检查已有源码、测试、最近提交和工作区差异。
2. 行为变化先补测试、模型 smoke 或静态检查，再实现。
3. 每项至少通过相关测试、`git diff --check`；iOS 变化还需适用的模拟器或 generic iPhoneOS 构建。
4. 每项独立提交。后端变化按该项要求推送、部署和线上 smoke；纯本地 fake 合同不得冒充真实 Provider 通过。
5. 外部配置缺失时将真实启用部分标记 `WAITING_EXTERNAL_GATE`，自动进入下一项，不暂停整个目标。
6. 新入口必须由服务端 capability/release policy 控制。M1、M2 未过门时保持 default-off。
7. 不新增第四 Tab，不改变当前 Stitch 三 Tab 和全屏 Echo 结构，不进行无关重构。

## 5. R0：计划与基线收敛

### ND-R0-01 唯一计划入口

**交付物**

1. 创建本文件并记录实际提交基线。
2. 标明已完成能力、外部门和剩余顺序。
3. 后续状态只更新本文件；前置计划不再追加日常执行记录。

**Gate**

- 文档路径与提交基线有效。
- 两个仓库状态已核对。
- `git diff --check` 通过。

**完成后进入**：`ND-R1-01`。

## 6. R1：M0 数据权利闭环

### ND-R1-01 ExportJob 与 CopyExportManifest

**执行状态**：`COMPLETE`（2026-08-08）

**实现证据**

- 后端：`main@fbd484f`，已推送并部署；数据库迁移头为 `0084`。
- iOS：`feature/prd-stitch-ui-adaptation@cf1993e6`。
- 已验证异步状态机、幂等 request key、owner 隔离、部分导出清单、失败重试、过期清理和账号租约隔离。
- 后端相关 78 项测试、部署态 Postgres smoke、iOS 合同检查、release QA 检查和 workspace 模拟器构建均通过。

**现有实现**

- 后端已有同步 `/auth/data-export` 和 owner-scoped 脱敏导出。
- iOS 已有 typed client、临时文件隔离和“我的”导出入口。

**剩余实现**

1. 在现有 exporter 外增加异步 `ExportJob`，不复制第二套数据扫描逻辑。
2. 固定 `queued / running / ready / partial / failed / expired` 生命周期和幂等 request key。
3. 生成用户可读摘要与机器可读 `CopyExportManifest`，列出模块、条目数、来源、状态、外部边界、保留期和未完成项。
4. 生成短期、owner-scoped 下载凭据；不返回永久对象 URL、bucket key、Provider 原始回执或其他用户数据。
5. 无真实对象存储时使用隔离 fake adapter 验证包生成，并明确媒体字节 `unsupported`；不得标记完整导出。
6. iOS 增加任务状态、失败重试、过期处理和分享完成后的临时文件清理。

**Gate**

- A/B owner、账号切换、注销后禁止导出、重复请求、过期和敏感字段负向测试。
- 后端 fake/Postgres smoke、iOS model/UIQA、generic build。

### ND-R1-02 删除与外部 effect 对账

**执行状态**：`COMPLETE`（2026-08-09）

**实现证据**

- 后端：`main@67bbbbe`，已推送并部署；数据库迁移头仍为 `0084`。
- iOS：`feature/prd-stitch-ui-adaptation@dc00d61a`。
- 已实现 access-first 五域对账、逻辑回执幂等、Provider 超时与失败脱敏、有限重试、人工复核证据和恢复后外部资产不复活边界。
- 已通过后端相关 97 项测试、部署态 Postgres smoke、iOS 合同检查、release QA 检查和 workspace 模拟器构建。

1. 复用现有 provider-effect receipt，统一对象存储、声音、数字人、通知和备份的 `pending / completed / failed / unsupported / unknown`。
2. 权限撤销必须先于外部删除；Provider 未确认不得显示“已删除完成”。
3. 补幂等 reconcile worker、超时、重复回调、人工处理和 dead-letter 证据。
4. 30 天恢复不得错误复活已由外部 Provider 删除的资产。
5. iOS 只展示可解释状态，不显示 Provider 原始错误或内部标识。

**Gate**：fake provider 全矩阵、Postgres 并发/重放、iOS 状态解析、统一数据权利 smoke。

## 7. R2：M0 受控 cohort 与运行控制

### ND-R2-01 能力级 cohort admission

**执行状态**：`COMPLETE`（2026-08-09）

**实现证据**

- 后端功能：`main@cf07c61`；部署态 smoke 修正：`main@3546043`。均已推送，服务器代码已同步，API 已按 `cf07c61` 重建，数据库迁移头保持 `0084`。
- iOS：`feature/prd-stitch-ui-adaptation@460d1b47`。
- 媒体采集、媒体处理和数据导出已使用独立 feature decision；采集绑定 `ownerTruthMediaStorage`，处理绑定 `ownerTruthMediaProcessing`，能力不可用时返回 `capabilityUnavailable`。
- 客户端传入 `cohort=closedPilotAdultSelf` 不能自入组；服务端仍返回 `unassigned`，只有服务端 allowlist 能授予 cohort。
- 已通过后端相关 165 项测试、线上 release-policy/runtime capability smoke、新增 iOS 静态组合 Gate、release QA package、`git diff --check` 和 workspace 模拟器构建。

1. 复用现有 release policy 和 `closedPilotAdultSelf`，为媒体摄入、处理、Candidate、导出和删除分别判定。
2. cohort 只能由服务端审批，客户端 launch arg 不能获得真实能力。
3. capability 缺失、owner/vault 不一致或策略版本过期时 fail-closed。

### ND-R2-02 自动停用与恢复

**执行状态**：`COMPLETE`（2026-08-09）

**实现证据**

- 后端：`main@a806469`，已推送、部署并通过线上 `/config/runtime` smoke；数据库迁移头保持 `0084`。
- iOS：`feature/prd-stitch-ui-adaptation@7e4bf602`。
- 扫描器、Provider、typed media worker、媒体任务 backlog/dead-letter、对象存储删除对账和能力级 kill switch 已形成短时、无用户数据的运行控制证据。
- 能力受阻或证据过期时会 fail-closed；恢复后签发新 readiness epoch，客户端不会沿用中断前缓存。
- 已通过后端 66 项自动停用 Gate、队列语义测试、iOS typed snapshot/UIQA、release QA package、`git diff --check` 和 workspace 模拟器构建。

1. 复用 worker readiness、backlog、dead-letter 和 kill switch。
2. 扫描器不可用、Provider 不健康、队列积压、删除对账异常或预算超限时关闭对应能力。
3. 恢复必须经过新的 readiness epoch，不自动沿用旧客户端状态。

### ND-R2-03 合成账户 E2E

**执行状态**：`COMPLETE`（2026-08-09）

**实现证据**

- 后端 Gate：`main@a155b8b`，能力绑定修正 `46dbb4c`，异步导出事务修复 `019235a`，下载边界与处理能力凭据修正 `175e4dd / 1177fae`；均已推送并部署。
- 部署态 Postgres Gate 已通过，数据库迁移头为 `0084`，同一合成账户完整经过 Source、Processing、Candidate、Decision、MemoryVersion、Context、Export、Delete 和 Reconcile。
- Gate 同时证明默认关闭、跨 Owner 拒绝、fake Provider 外部媒体边界保持 `partial`、删除后 Context 不再选择撤权媒体、Provider 删除回执和物理删除完成。
- 后端完整 1953 项测试、相关合同测试与 `git diff --check` 通过；证据文件位于服务器 API 容器 `/app/tmp/qa/v4-synthetic-account-e2e/result.json`。

固定一条不使用真实用户数据的组合 Gate：

`Source -> Processing -> Candidate -> Decision -> MemoryVersion -> Context -> Export -> Delete/Reconcile`

真实 Provider 未配置时验证 fail-closed 与 fake adapter；配置后同一 Gate 可切换为 deployed evidence。

## 8. R3：M0 产品面非真机收敛

### ND-R3-01 Candidate/Memory 审核面

1. 盘点现有 Candidate 列表、详情、编辑、接受、拒绝和来源引用，只补真实路由或缺失状态。
2. 处理中、待审核、已确认、已拒绝、已被新版本替代必须来自 typed contract。
3. 未确认、失败处理和已撤权 Source 不进入确定性 Echo Context。

### ND-R3-02 导出、删除和能力状态

1. 将 R1 状态接入“我的”和档案详情。
2. Provider 不可用时隐藏动作或展示明确不可用原因，不展示假成功。
3. 保持现有视觉密度、背景、卡片和三 Tab 结构。

**Gate**：模拟器 UIQA、公开 M0 regression、默认关闭功能探测、generic iPhoneOS build。

## 9. R4：Provider 非真机合同收尾

### ND-R4-01 COS/扫描器部署前矩阵

1. 保持腾讯 COS 为唯一首发存储，不新增第二生产 adapter。
2. 完成缺配置、错误 region、SSE 缺失、扫描器离线/超时、EICAR、删除未知回执的组合 Gate。
3. 真实配置继续标记 `WAITING_EXTERNAL_GATE`，不在仓库保存凭据。

### ND-R4-02 OTP Provider 合同

1. 保留 synthetic adapter，仅完善真实 adapter port 的发送、受理、送达回执、限流、重放和恢复状态。
2. 未选定真实短信 Provider 前不编造 SDK 字段；以 provider-neutral contract 完成非真机 Gate。
3. iOS 只消费 challenge/attempt/retryAfter/recovery 状态。

## 10. R5：M1 非真机生产合同收尾

### ND-R5-01 真实 Provider 边界证明

1. 对训练、查询、试听、接受、合成、暂停和删除建立 capability matrix。
2. Provider 不支持删除时保持 `unsupported/partial`，禁止 UI 显示已删除。
3. accepted profile 之外禁止进入 Echo；不得降级成腾讯默认音色并冒充复刻成功。

### ND-R5-02 Echo 绑定与证据

1. 继续强制 `owner + voiceProfileId + profileVersion + role + purpose + textHash + outputMode` 绑定。
2. 角色/账号切换、停止、过期和旧回调必须被 generation token 丢弃。
3. 证据包保持脱敏，输出 `audioOwner / fallbackReason / providerLogId hash / binding result`。

**Gate**：fake provider lifecycle、PCM contract、runtime fault injection、release default-off regression。

## 11. R6：M2 默认关闭的闭测合同

仅实施无需外部批准即可安全完成的 default-off 代码；不得开放真实入口。

### ND-R6-01 闭测 API 收敛

1. 复用现有 PublicationVersion、ShareGrant、Visitor reader 和 cleanup contract。
2. 明确正式闭测路由与 QA-only 路由边界，所有正式路由继续受 D0 Gate 和 cohort 拒绝。
3. Publication 只能来自 active/confirmed MemoryVersion 的独立脱敏副本。

### ND-R6-02 iOS default-off 壳层

1. 发布管理与 Visitor 入口只允许位于“我的”受控区域，不新增 Tab。
2. 未成年、匿名、无 grant、过期、撤回和账户切换均立即清除会话与缓存。
3. Voice/DH 不可用时只能回退 M2 中性文字 Visitor，不能回到私人 Echo。

**Gate**：A/B owner、过期、撤回、深链、缓存隔离、默认关闭和公开入口探测。

## 12. R7：统一非真机发布门

### ND-R7-01 组合 runner

统一运行并生成脱敏 manifest：

1. M0 Source/Candidate/Memory/Context。
2. ExportJob、CopyExportManifest、删除和 effect reconciliation。
3. cohort、kill switch、readiness 和自动停用。
4. COS/扫描器/OTP fail-closed。
5. M1 lifecycle、PCM 和 Echo 绑定。
6. M2 default-off、Publication/Visitor 隔离。
7. iOS 相关静态检查、模拟器 UIQA 和 generic build。

### ND-R7-02 最终交接

输出三份互不混淆的结论：

- `NON_DEVICE_CODE_COMPLETE`
- `WAITING_EXTERNAL_PROVIDER`
- `WAITING_TRUE_DEVICE`

非真机完成不能改变 M0/M1/M2 的真实发布结论。

## 13. 外部并行清单

以下事项不阻塞 R1-R7 的可执行代码，但阻塞相应真实上线：

| 域 | 外部输入 |
| --- | --- |
| COS | region、private bucket、HTTPS endpoint、SSE/保留策略、最小权限凭据、测试租户 |
| ClamAV | 至少满足官方运行内存的独立 sidecar/主机和签名库更新策略 |
| OTP | 短信 Provider、签名、模板、地域、测试号码和服务端凭据 |
| M1 身份 | 成年强身份/活体 Provider、同意文本、真实测试主体 |
| Voice | 生产 slot、训练/查询/删除能力、保留和删除条款 |
| M2 | 成年校验、法律/隐私/安全评估、备案、closed-beta cohort 和 incident owner |

## 14. 当前交接点

- 已完成：`ND-R0-01`、`ND-R1-01`、`ND-R1-02`、`ND-R2-01`、`ND-R2-02`、`ND-R2-03`
- 当前 Work Item：`ND-R3-01 Candidate/Memory 审核面`
- 后续 Work Item：`ND-R3-02 导出、删除和能力状态`
- 任何外部 Gate 缺失均不得暂停可继续的非真机任务。
