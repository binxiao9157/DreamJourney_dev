# DreamJourney 产品确认版 GAP-01 至 GAP-13 执行计划

日期：2026-08-18
状态：`FUNCTIONAL_CODE_COMPLETE_WITH_EXTERNAL_AND_DEVICE_GATES`
日常开发入口：`CANONICAL_EXECUTION_PLAN`
执行控制版本：V1.16

## 0. 目标和基线

本计划将 2026-08-17 产品确认版概要设计落实到当前工程，完成 GAP-01 至 GAP-13，并保持已有稳定能力和 Stitch 三 Tab/全屏 Echo 视觉不被无关重构破坏。

代码基线：

| 工程 | 分支 | 起始 HEAD |
|---|---|---|
| iOS | `feature/prd-stitch-ui-adaptation` | `09394f9869e0b0e20150a43ffe8149a7e607356c` |
| Backend | `main` | `b472b6de9fc43e797936741b63a9de877db48750` |

### 0.1 当前执行进度

更新时间：2026-08-20

| 分类 | 数量 | 当前内容 |
|---|---:|---|
| `COMPLETE` | 18 | 文档基线、PC-00-01、PC-00-02、PC-00-03、PC-A1、PC-A2、PC-A3、PC-A4、PC-A5、PC-B1、PC-B2、PC-B3、PC-B4、PC-C2、PC-D1、PC-D2、PC-E1、PC-E2 代码闭环 |
| `WAITING_EXTERNAL_CONFIGURATION` | 2 | PC-A0：真实短信 Provider 待配置；PC-C1：代码、public/internal 准入隔离与默认关闭完成，真实私有对象存储、内容安全扫描器和视觉 Provider 待配置 |
| 当前执行项 | 0 | 当前确认版功能代码队列已完成 |
| 后续待执行 | 0 | 只保留 PC-A0/PC-C1 外部配置、Production Approval 和真机验收 Gate |

当前代码与部署交接：PC-E2 iOS QA 提交为 `8cd337f1`，Backend 最终部署提交为 `06b6340`；服务器仓库、API 镜像和四个异步 Worker 均已更新，migration head 保持 `0104`。后端 71 项数字人关闭测试、6 项时光信/延迟回复关闭测试、178 项普通能力定向回归、部署态关闭能力 PostgreSQL smoke、稳定 Feature 与命令策略 smoke 均通过；数字人创建/heartbeat、时光信/延迟回复创建与调度、Provider 投递均为零。iOS 最终静态 Gate 和 generic iPhoneOS build 通过，Bundle ID 为 `com.yxj.dreamjourney.app`。readiness 严格报告代码 `3/3 ready`、外部配置 `0/8 blocked`、真机 `0/6 pending`，因此当前生产结论仍为 `NO-GO`。真实短信 Provider、Ownership enforce、APNs、腾讯 COS、内容安全扫描器、媒体 Worker/视觉 Provider、声音身份与 Provider、Publication/Visitor 审批及真机证据继续作为独立 Gate。

每轮只需读取：

1. 本计划当前 Work Item。
2. 《寻梦环游_产品确认版PRD_2026-08-18.md》对应需求。
3. 《寻梦环游_产品确认版当前实现证据矩阵_2026-08-18.md》对应 GAP。
4. 对应 Work Item 涉及 PCQ 决策时，读取《寻梦环游_产品确认版待明确与完善清单_2026-08-18.md》。
5. 相关源码、测试、最近提交和工作区差异。

仅在产品冲突或 Gate 修改时回查今天提供的两份输入；其他历史文档不参与本计划执行，除非用户另行明确要求。

## 1. 执行规则

1. 不从头重写已有 Source/Candidate/Memory、Echo、Family、Voice、Publication 或治理基础。
2. 行为变化先补测试、contract smoke 或静态 Gate，再改实现。
3. 每次只推进一个可独立提交的小闭环；跨仓库任务分别提交。
4. 后端变化必须跑相关 pytest、标准 smoke、`git diff --check`；部署后跑 `/ready` 和 deployed smoke。
5. iOS 变化必须跑相关 XCTest/静态检查、`git diff --check` 和 generic iPhoneOS build；涉及 UI 时补模拟器 UIQA。
6. 数字人、时光信和延迟回复在整个计划中保持产品关闭；代码可以保留，普通流量不得调用。
7. “取消 M1-M4/QA 产品分级”不允许绕过身份、权限、Provider、部署、法律、安全或真机 Gate。
8. 真实 Provider 配置缺失时标记 `WAITING_EXTERNAL_CONFIGURATION`，继续不依赖该配置的 Work Item，不使用 mock 冒充生产完成。
9. 不修改无关 UI，不把内部 trace、Citation、Provider ID 或 QA 文案暴露给普通用户。
10. 已有未提交文件必须先辨明来源，不覆盖、不回退、不混入无关提交。
11. 每个 Work Item 开始前必须填写执行卡；Owner、依赖决策、UI 依据、API/迁移影响和回滚方式缺失时不得进入不可逆实现。
12. 每个 Work Item 关闭时必须登记可复现命令和证据路径；聊天结论、截图描述或“本地通过”不能单独作为完成证据。

### 1.1 Work Item 执行卡

每轮只复制并填写当前 Work Item 的一张执行卡，不要求重新通读全部文档：

```text
Work Item：PC-*
状态：READY | IN_PROGRESS | WAITING_PRODUCT | WAITING_EXTERNAL_CONFIGURATION | VERIFIED | COMPLETE
工程 Owner：<具体执行人>
产品决策依赖：<PCQ-* 或 NONE>
代码基线：iOS=<commit>；Backend=<commit>
UI 设计依据：<下方 UI 矩阵编号、Stitch 画布/htmlCode 版本或 NOT_APPLICABLE>
API 合同：<method/path/schema/reason code；无变化填 NONE>
迁移与兼容：<migration id/backfill/旧客户端策略；无变化填 NONE>
部署运行态快照：<证据路径；不部署填 NOT_APPLICABLE>
验证命令：<测试、smoke、build、UIQA>
验收证据目录：<相对路径>
回滚方式：<feature kill switch、代码回退、迁移 forward-fix 或数据恢复>
外部/真机余项：<明确列出，不得并入 COMPLETE>
```

Owner 是本轮交付责任人，不代表产品决策人。涉及 PCQ 时，产品 Owner 和确认凭证仍以待明确清单为准。

## 2. 总体顺序

```text
Phase 0 产品关闭边界
  -> Phase A 权限与数据基础
  -> Phase B 正式记忆与回响
  -> Phase C 多媒体与导出
  -> Phase D 发布与 Visitor
  -> Phase E 去阶段化与最终回归
```

依赖关系：

- GAP-01、GAP-02、GAP-05 是数据和权限基础。
- GAP-03 依赖 GAP-02；GAP-04/GAP-06 依赖 GAP-02、GAP-05。
- GAP-08 依赖 GAP-03。
- GAP-09 依赖 GAP-03、GAP-05；GAP-10 依赖 GAP-09。
- GAP-13 在 GAP-09/GAP-10 产品闭环完成后做最终命名和策略迁移。
- GAP-11/GAP-12 先做强制关闭，再在最终阶段补零调用证据。

### 2.1 UI 设计依据矩阵

涉及 UI 时，以当前 Stitch 画布和对应 `htmlCode` 源码为视觉主依据，MCP screenshot 只用于辅助复核。今天两份产品输入没有提供新页面的逐像素设计，因此不能凭文字需求声称新页面已完成视觉验收。

| UI 编号 | 页面/区域 | 当前视觉依据 | 开发边界 | 最终 UI Gate |
|---|---|---|---|---|
| UI-01 | 三 Tab、记忆档案、全屏 Echo、我的 | 当前已对齐的 Stitch 画布 + `htmlCode` + 现有工程实现 | 保持整体结构、背景、导航和视觉语言，不做无关改版 | 模拟器多尺寸截图与当前 Stitch/htmlCode 对照 |
| UI-02 | 正式记忆列表、详情、编辑、二次确认 | 产品输入给出信息架构；没有新增 Stitch 页面 | 复用记忆档案的色彩、字体、间距、列表和 Sheet 组件；先完成可用闭环 | 产品补充 Stitch/htmlCode 后做 final visual QA；未补充前只标功能验收通过 |
| UI-03 | Publication 创建、预览、版本和 Grant 管理 | 产品输入给出流程；没有新增 Stitch 页面 | 复用档案选择、详情、确认和设置列表模式，不自行引入新视觉体系 | 公开前必须完成产品流程评审和 Stitch/htmlCode 视觉复核 |
| UI-04 | Visitor 查询入口和会话 | 产品输入给出权限与会话要求；没有新增 Stitch 页面 | 会话视觉延续普通 Echo，但不得出现私人域、Citation 或数字人控件 | 授权/撤权 UIQA + 产品视觉确认 |
| UI-05 | 家庭关系解除、贡献和声音授权 | 现有家庭/设置页面 + 已确认 PCQ-03/PCQ-05 | 提供退出/解除而非删除账户；音色显示累计 5 次创建边界和独立授权 | 权限/撤权 smoke + 模拟器 UIQA |
| UI-06 | 正式记忆 Markdown 导出 | 现有“我的/隐私与数据”设计语言 | 客户端只提供正式记忆 Markdown；不展示完整账户数据导出 | 分享/清理 smoke + 页面截图 |
| UI-07 | 数字人、时光信、延迟回复 | 产品确认关闭 | 普通 UI 完全隐藏，不新增占位、维护页或提示 | release 文案/路由静态 Gate 和零调用证据 |
| UI-08 | 普通消息中心 | 现有 App 导航、列表和系统图标视觉语言；无新增 Stitch/htmlCode | “我的”增加消息中心；记忆档案/回响右上角使用系统铃铛和数字红标；支持一键已读、删除已读 | 多尺寸 UIQA、未读状态一致性和可访问性检查 |

若 Stitch 后续更新，只更新受影响的 UI 编号和视觉验收证据，不借机重构其他页面。

### 2.2 部署运行态快照

代码状态与部署状态分开记录。当前计划建立时只确认两仓库代码 HEAD，未重新采集服务器运行态，因此初始部署状态为 `PENDING_CAPTURE`，不得由代码或旧报告反推为已部署。

每个涉及后端部署的 Work Item 必须在部署前后各保存一份脱敏快照：

| 字段 | 必填内容 |
|---|---|
| 环境 | local/container/staging/production-like；禁止只写“服务器” |
| 时间与版本 | UTC 时间、Backend commit、migration head、容器/image 标识 |
| 基础健康 | `/health`、`/ready` HTTP 状态和结构化 readiness reason |
| Runtime | `/config/runtime` 的功能 enabled/ready/reason；不得保存凭据 |
| Release Policy | audience、cohort、client build、policy revision 和目标 Feature 决策 |
| Worker/Provider | Worker backlog/dead-letter、对象存储、OTP、语音和通知的可用/阻断原因 |
| 数据库 | store 类型、schema/migration head；禁止记录 DSN |
| 证据 | 请求命令的脱敏版本、响应摘要、smoke 结果和执行人 |

默认证据路径：`artifacts/product-confirmed/<YYYYMMDD-HHMM>/<work-item>/runtime-before.json` 与 `runtime-after.json`。仓库不提交含 token、手机号、用户正文、媒体 URL 或 Provider 原始凭据的响应。

### 2.3 API 与迁移合同清单

下表固定每个 GAP 的合同边界。具体 Work Item 开始时必须在执行卡补齐 method/path、请求响应 schema、稳定 reason code、幂等键和权限主体；实现过程中不得用自由文本错误替代合同。

| GAP | API/运行面 | 数据与迁移 | 兼容与回滚要求 |
|---|---|---|---|
| GAP-01 | 测试角色/entitlement 管理、token revision、Session 撤销 | 角色、entitlement、scenario binding、revision 和审计字段；先 nullable/backfill | 默认无 entitlement；关闭管理写入不删除已记录审计 |
| GAP-02 | Candidate、确认、MemoryVersion、Projection/SearchDocument V2 | `owner-truth-v2` schema、facets 索引、未知 schema quarantine | V1 只读兼容；V2 写入可 kill switch，禁止自动改写旧事实 |
| GAP-03 | current memories 列表/详情/历史、correction command | current/version 查询索引、DecisionReceipt、幂等和 expected hash | 写入关闭时保留只读；冲突返回稳定 409，不覆盖旧版本 |
| GAP-04 | Owner search/context build/query ranking | SearchDocument/Projection 排名字段和索引 | 检索故障只用不扩权的 deterministic fallback；不得新增或扩大 KBLite/Legacy 回退 |
| GAP-05 | identity context、VisitorSession、Share/Contribution Grant | Grant、Session、撤权 revision 和过期索引 | 默认拒绝；撤权立即失效；关闭新路由不恢复跨域旧回退 |
| GAP-06 | Citation、grounding、context trace、QA evidence | 审计/trace 仅作证据，不成为事实权威 | 普通 UI 始终隐藏；关闭 trace 导出不改变回答权限 |
| GAP-07 | 图片/文档 upload intent、media job、ExtractionResult、Candidate handoff | 私有对象 metadata、job/lease/retry、processor/input version 和 output hash | 图片/文档独立 kill switch；音频/视频普通流量关闭；失败不生成空 Candidate |
| GAP-08 | ExportJob `formalMemoryMarkdown`、下载/取消 | export type、manifest/hash、临时对象和清理回执 | 可单独关闭 Markdown 类型；客户端不提供完整账户数据导出 |
| GAP-09 | PublicationDraft/Version/PublicProjection 管理 | 多 item 顺序、snapshot hash、确认回执和不可变版本 | 旧版本继续只读；关闭创建不删除已发布版本，撤回单独审计 |
| GAP-10 | ShareGrant 邀请、VisitorSession、PublicProjection query | Grant 状态/有效期/次数、Session revision | 全局 kill switch 或单 Grant 撤销；任何失败不得回退私人 Projection |
| GAP-11 | Release Policy、Runtime、`/digital-human/sessions` | 不新增产品数据；已有 Session/资产按 PCQ-06 处置 | 普通流量固定关闭；回滚含义是恢复关闭策略，不是重新开放 |
| GAP-12 | time letter/delayed reply 创建与调度 | 调度阻断和零投递审计；无生产历史迁移 | 开发/测试数据不补发；重新开放必须另立迁移和产品确认 |
| GAP-13 | `/config/runtime`、Release Policy 稳定 Feature 命名 | policy revision、旧 Feature alias 和到期时间 | 旧客户端期限内兼容；alias 不得形成第二套授权规则 |

补充产品决策合同：

| 决策 | API/运行面 | 数据与迁移 | 回滚要求 |
|---|---|---|---|
| PCQ-02 | 密码设置/登录/修改/重置、OTP 登录和敏感操作再认证 | password hash/revision、失败次数、锁定、重置回执 | 可独立关闭密码登录但不得破坏 OTP；旧 Session 按 revision 撤销 |
| PCQ-03 | 音色创建 preflight/create 返回 creationCount/remainingCount | 单声音主体原子累计创建次数，上限 5 | 不通过删除 profile 返还或篡改历史计数；Provider 未受理请求的计数规则由合同测试固定 |
| PCQ-05 | 家庭退出/解除、Grant 撤销和贡献处置 | Relationship 状态、撤权 revision、审计回执 | 失败关闭，不删除对方账户或已接受 Source 的来源审计 |
| PCQ-11 | 客户端仅 formalMemoryMarkdown | 运维脱敏完整导出审批/协议/审计模型延期 | 客户端始终无完整导出入口；延期能力不得由旧 ZIP Job 自动开放 |
| PCQ-12 | KBLite 无用户路由 | 现有后台读写和权限行为不迁移 | 只回滚 UI/路由变化，不借机停写、扩权或改变现有内部调用 |
| PCQ-13 | 消息列表/未读计数/单条和批量已读/删除已读 | read_at、deleted/archived 状态、未读索引和幂等键 | 删除已读不能删除未读；入口 kill switch 不丢消息 |

迁移规则：expand -> 双读/兼容 -> backfill/验证 -> switch -> contract。涉及不可逆删除时必须单独暂停确认，不能把 down migration 当作数据恢复方案。

### 2.4 验收证据与回滚规范

每个 Work Item 的证据目录使用固定结构，便于其他同事复跑：

```text
artifacts/product-confirmed/<run-id>/<work-item>/
  manifest.json
  checks.log
  smoke.json
  build.log
  runtime-before.json
  runtime-after.json
  uiqa/
  rollback.md
```

`manifest.json` 至少记录执行人、时间、两仓库 commit、环境、命令、结果、PCQ 依赖、外部/真机余项和脱敏声明。只生成了截图或只有终端口头摘要时，Work Item 最多标记 `INTERNAL_READY`，不能标记 `COMPLETE`。

回滚必须按变更类型写清：

1. **UI/客户端**：入口 kill switch、最低版本策略、前一稳定提交和本地缓存兼容。
2. **API/策略**：Feature kill switch、旧客户端兼容映射、错误码恢复和 Session 撤销影响。
3. **数据库**：优先 forward-fix；回退前验证新字段/新行是否会丢失，禁止直接删除生产数据。
4. **Worker/Provider**：停止消费、保留队列、dead-letter/replay、撤销短期凭据和外部副作用对账。
5. **权限/授权**：失败关闭；任何回滚都不得恢复已撤销 Grant、旧 token 或跨账号缓存。

完成后在当前实现证据矩阵中只写证据摘要和目录，不复制完整日志，避免文档和证据形成两套事实。

## 3. Phase 0：新产品边界先落地

### PC-00-01 数字人统一关闭

关联：GAP-11、DH-001。

状态：`COMPLETE`（2026-08-18）。实现提交：iOS `84339ab8`，Backend `0a8d5a8`；验收证据见 `artifacts/product-confirmed/20260818-pc-00-01/PC-00-01/` 和 `docs/superpowers/status/2026-08-18-pc-00-01-digital-human-product-closure.md`。当前连续执行交接点为 `PC-00-02`。

实现：

1. 后端 Release Policy 对普通用户固定拒绝 `digitalHumanLivePanel`。
2. Runtime Capability 返回 `enabled=false`、`releaseVisible=false` 和稳定 reason code。
3. `/digital-human/sessions` 对普通用户失败关闭，不创建、续约或恢复 Session。
4. iOS 隐藏数字人容器、连接状态和 fallback 提示，不启动 RuntimeFactory。
5. QA/内部调用如需保留，必须使用独立 internal entitlement，不得复用普通登录资格。

验证：

- 后端策略、路由负向、Session 创建计数测试。
- iOS release visibility 静态检查和 Echo UIQA。
- 普通 Echo 文字/火山语音回归。

完成定义：普通产品流量的数字人请求和配额消耗为零，Echo 不因关闭而不可用。

### PC-00-02 时光信与延迟回复统一关闭

关联：GAP-12、NOTI-001。

状态：`COMPLETE`（2026-08-18）。实现提交：iOS `80d88d95`，Backend `13081af`；后端测试维护提交 `4a8200e`。Backend `4a8200ec` 已部署到 production-postgres。验收证据见 `artifacts/product-confirmed/20260818-pc-00-02/PC-00-02/` 和 `docs/superpowers/status/2026-08-18-pc-00-02-time-letter-delayed-reply-closure.md`。当前连续执行交接点为 `PC-00-03`。

实现：

1. `timeLetters=false`、`echoDelayedReplies=false`，创建接口对普通用户失败关闭。
2. iOS 隐藏创建、信箱、状态和消息中心中的新入口。
3. Worker 不接收新任务；产品未正式发布，无生产历史迁移或补发，开发/测试数据不作为历史用户数据。
4. APNs 和 InAppMessage 继续支持导出、候选整理、家庭邀请等普通任务通知。

验证：

- 新建/调度拒绝、旧数据可读但不投递、普通通知不受影响。
- release UI 文案和路由静态 Gate。

完成定义：关闭期间新建和投递数量为零，并有“无生产历史迁移/补发”的确认记录。

### PC-00-03 首版可见范围收敛

关联：ARCH-004、DATA-001、KB-001、PCQ-09、PCQ-11、PCQ-12。

状态：`COMPLETE`（2026-08-18）。实现提交：iOS `e4e5034b`，Backend `6d542f9`；Backend smoke 维护提交 `9759f1b` 已部署到 production-postgres，migration head 为 `0093`。验收证据见 `artifacts/product-confirmed/20260818-pc-00-03/PC-00-03/` 和 `docs/superpowers/status/2026-08-18-pc-00-03-first-release-scope-closure.md`。`Gate P0` 已通过，当前连续执行交接点为 `PC-A0`。

实现：

1. 音频和视频的普通用户入口、upload intent、处理任务和运行时能力统一关闭；保留现有代码和内部测试能力，不以 mock 数据或历史壳层冒充首版功能。
2. iOS 不展示语音档案、视频档案的创建入口、路由或“即将开放”占位；后端对普通 Principal 的新增上传和处理请求失败关闭。
3. KBLite 对所有普通用户隐藏页面、入口、路由和导出按钮；现有后端读写、权限和内部兼容调用保持不变，任何调用仍遵守账户、Vault 和 Grant 隔离。
4. 客户端不展示完整账户 ZIP/数据导出入口；只保留本计划 PC-C2 的正式记忆 Markdown 导出。运维脱敏完整导出继续标记 `DEFERRED`，本阶段不实现。
5. 普通消息中心及图片/文档入口不受本项影响；关闭边界必须由后端 Policy/Runtime/API 和 iOS 可见性共同决定，禁止仅靠本地隐藏。

验证：

- Release Policy、`/config/runtime`、upload intent、Worker enqueue 和导出类型的正负合同测试。
- iOS 公开文案、路由、入口和网络调用静态 Gate；图片/文档、正式记忆 Markdown 和消息中心回归。
- 普通流量的音频/视频任务创建、KBLite 用户路由和完整账户导出请求均为零。

完成定义：首版只暴露已确认的图片、文档、正式记忆 Markdown 和普通消息中心；关闭能力不存在可见入口、后台误调用或 mock 成功状态。

### Gate P0

- 数字人、时光信、延迟回复三条能力在 Policy、Runtime、API 和 iOS 四层状态一致。
- 音频/视频普通入口及处理任务关闭，KBLite 无用户入口，客户端无完整账户导出入口。
- 图片/文档、正式记忆 Markdown 和普通消息中心不因关闭策略被误伤。
- 关闭不影响三 Tab、普通 Echo、档案、家人和任务通知。

## 4. Phase A：权限与数据基础

### PC-A0 密码与手机号验证码双登录

关联：AUTH-001、PROF-001、PCQ-02。

状态：`WAITING_EXTERNAL_CONFIGURATION`（2026-08-18）。密码全链路、synthetic/test allowlist OTP、Session/风控合同、iOS 双模式、migration `0094` 和 production-postgres 部署均已验证；真实短信 Provider、签名、模板和非白名单测试号码仍为外部 Gate。实现提交：iOS `5aaf3543`，Backend `3ea80d1`、`994b3cc`；证据见 `artifacts/product-confirmed/20260818-pc-a0/PC-A0/` 和 `docs/superpowers/status/2026-08-18-pc-a0-password-otp-dual-authentication.md`。PC-A0 Session 合同已稳定，当前连续执行交接点为 `PC-A1`。

后端：

1. 在现有 OTP Challenge/Login 基础上增加密码设置、密码登录、修改、忘记/重置和敏感操作 OTP 再认证合同。
2. 密码使用经审计的单向哈希参数，记录 password revision、失败次数、锁定和重置回执；响应不泄露账号是否存在。
3. OTP 与密码登录生成同一 Access/Refresh Session 模型；密码修改/重置后按策略撤销旧 token family。
4. 两种登录分别执行限流、重放阻断、审计和稳定 reason code；真实短信 Provider 仍是 OTP 的外部 Gate。

iOS：登录页提供密码/验证码分段模式，补设置、修改、重置、加载、失败、锁定和再认证状态；不保留只有页面没有后端 readiness 的假入口。

验证：密码哈希/枚举负向、锁定、重置 token 单次使用、OTP 重放、Session 撤销、双模式 UIQA 和 generic iPhoneOS build。

完成定义：密码与 OTP 均可独立完成登录和恢复，且共享一致的账户与会话安全边界。

### PC-A1 测试账号角色与权限

关联：GAP-01、AUTH-003、FAM-001、OPS-001、SEC-001。

后端：

1. 为测试账号增加 `testRole`、`featureEntitlements`、`scenarioBindings`、`entitlementRevision` 和更新审计字段。
2. 管理接口支持角色和 Feature 显式分配；白名单记录默认无产品 entitlement。
3. Token 只携带最小 revision/snapshot 标识，请求仍校验当前 revision。
4. 权限修改后撤销旧 token family 和活动 Session。
5. superTest 只能访问自身 Vault 或有效 Grant，不允许任意 vaultId。

iOS/后台：

1. 内部管理页增加角色和 Feature 多选。
2. 普通 App 不展示 testRole 或 entitlement 管理。

验证：角色矩阵、旧 Session 失效、super 越权负向、Family/Visitor Grant 负向、审计脱敏。

完成定义：测试验证码资格与产品功能权限完全分离。

状态：`COMPLETE`（2026-08-18）。测试账号已具备显式角色、Feature entitlement、仅作场景引用的 scenario binding、revision/snapshot 和脱敏审计；默认白名单无产品 entitlement。权限更新会使旧 revision Session 失效并撤销该 Subject 的活动 Session，`superTest/familyTest` 仍受 Owner/Grant 权限边界约束。内部管理页已支持角色与 Feature 多选，普通 App 静态 Gate 证明不存在管理入口。Backend `d08c537`、迁移修复及部署 `aae0b04`，iOS QA Gate `9cc2196e`；production-postgres migration head `0095`，证据见 `artifacts/product-confirmed/20260818-pc-a1/PC-A1/` 和 `docs/superpowers/status/2026-08-18-pc-a1-test-account-authorization.md`。当前连续执行交接点为 `PC-A2`。

### PC-A2 Owner Truth V2 facets

关联：GAP-02、MEM-001、MEM-003、MEM-004。

后端：

1. 定义 `owner-truth-v2` JSON schema，支持 people/time/places/relationships/emotions/values/personality/confidence。
2. Candidate extraction、DeepSeek prompt、人工纠正和 MemoryVersion activation 支持 V2。
3. AI 推断强制 `evidenceMode=inferred`，关系 facet 不参与权限判断。
4. Projection/SearchDocument 将 facets 扁平化到 `structured_terms` 并建立索引。
5. V1 继续可读；未重新确认不自动补写 facets；未知 schema quarantine。

iOS：

1. 待确认详情、正式记忆详情和编辑页展示/编辑 facets。
2. 对未知字段前向兼容，不把缺失 facets 显示为分析成功。

验证：schema 正负样本、V1/V2 兼容、未知 schema、推断标识、索引和跨账号负向。

完成定义：V2 Candidate 经 Owner 确认后生成可检索、可追溯的 V2 MemoryVersion。

状态：`COMPLETE`（2026-08-19）。新写入使用 `owner-truth-v2`，支持七类 facets 和总体 confidence；AI 线索保留 `inferred` 证据标识，关系 facet 不进入权限判定。V1 保持只读兼容且不自动补写，未知 schema fail-closed quarantine。Candidate 提取、人工纠正、MemoryVersion 激活、Projection 和私有 SearchDocument 已贯通；结构化索引只接收 allowlist `value`，不索引 subject/grant 等扩展元数据。iOS 已支持待确认详情、纠正编辑和正式记忆历史展示，并明确区分 V1 缺失、非法和未知 schema。Backend `6965dd4`，部署 smoke 修复 `3a7f5ba`、`b964e0c`；iOS `4325fcd2`；production-postgres migration head `0096`，两个 Owner Truth Worker 均 ready/running。证据见 `artifacts/product-confirmed/20260819-pc-a2/PC-A2/` 和 `docs/superpowers/status/2026-08-19-pc-a2-owner-truth-v2-facets.md`。当前连续执行交接点为 `PC-A3`。

### PC-A3 Family/Visitor V4 权限路由

关联：GAP-05、ARCH-001、ECHO-001、FAM-001、PUB-002、SEC-001。

实现：

1. Family 身份禁止创建对方 OwnerTruthCommandContext。
2. Family 关系本身不得读取对方 Source、Candidate、MemoryVersion 或私人 Projection。
3. 有 ShareGrant 时建立 VisitorSession 并读取 PublicProjection。
4. 无 ShareGrant 时返回权限缺口或 FamilyContribution 引导。
5. 禁止回退 Legacy Archive/KBLite 读取家人私人事实。
6. 家庭贡献保持专项 Grant、Owner 审核和撤权后立即阻断。

验证：Owner A/B、Family、Visitor、撤权、过期、暂停、旧缓存和旧异步回调矩阵。

完成定义：只有本人账户能访问自己的私人 V4；查询他人只走发布域。

状态：`COMPLETE`（2026-08-19）。Backend 在私人 `/context/build` 和 `/echo/answers` 入口前执行 fail-closed 身份路由，Family 请求稳定返回 `familyPrivateContextDenied`，ShareGrant admission 将 Owner 主体绑定到 VisitorSession。iOS 仅本人进入私人 Context 和腾讯数字人；匹配 VisitorSession 读取 PublicProjection，无分享授权时转入 FamilyContribution，非本人路径不读取 Archive/KBLite。Backend `83240f6` 已部署，iOS `b4caa0b4` 已推送；证据见 `docs/superpowers/status/2026-08-19-pc-a3-family-visitor-v4-routing.md`。当前连续执行交接点为 `PC-A4`。

### PC-A4 音色独立授权与累计创建上限

关联：VOICE-001、SEC-001、PCQ-03。

1. 服务端以声音主体为维度原子维护 `creationCount` 和 `remainingCount`，累计最多创建 5 次。
2. 服务端成功受理并创建新 profile 时计数；参数校验失败和重复 commandId 不计数，后续训练失败、删除或撤销不返还次数。上限不限制已授权音色的 TTS 合成调用。
3. 本人创建、接受、撤销和家人用途授权继续使用独立回执；家庭关系不能代替声音主体授权。
4. iOS 在创建前展示剩余次数和授权范围，达到上限后隐藏提交动作并显示稳定原因，不暴露 Provider 凭据。

验证：并发创建、幂等重试、Provider 失败、撤销后计数、跨账号/家人越权和现有 Echo binding 回归。

完成定义：第 1 至 5 次创建按合同执行，第 6 次稳定失败；任何角色都不能绕过主体授权或创建上限。

状态：`COMPLETE_WITH_EXTERNAL_GATE`（2026-08-19）。Backend 新增 migration `0097`、主体级原子配额/幂等回执和部署态 Postgres 并发 smoke；iOS 新增 typed quota consumer、授权范围与剩余次数展示，并在上限时关闭新建。Backend `080e9b8` 已部署，iOS `e52267f9` 已推送；证据见 `docs/superpowers/status/2026-08-19-pc-a4-voice-profile-creation-quota.md`。强身份/活体和真实 Provider 生产回执仍按外部 Gate 管理；当前连续执行交接点为 `PC-A5`。

### PC-A5 家庭关系解除与数据处置

关联：FAM-001、FAM-003、SEC-001、PCQ-05。

1. 提供退出家庭/解除关系，不提供“删除对方账户”。
2. iOS 二次确认列明 ShareGrant、Contribution Grant、待审核贡献和角色切换影响。
3. 服务端原子撤销新访问和新贡献；未接受贡献隐藏并进入处置队列，已接受 Source 保留来源审计。
4. Publication Grant 不由关系解除隐式删除，由 Owner 单独确认是否撤销。

验证：双方发起权限、重复解除、并发贡献、旧 Session/缓存、已接受与未接受贡献、账户仍可登录和审计回执。

完成定义：关系解除立即阻断关系授权，但不删除任一账户或改写已形成的正式记忆来源。

状态：`COMPLETE`（2026-08-19）。Backend 新增 `family-relationship-termination-v1`、participant membership 查询、migration `0098`、事务级并发/幂等撤权和部署态 PostgreSQL smoke；iOS 新增 Owner 解除、Member 退出、二次确认、typed receipt 和账户切换防陈旧回调。Backend `b20e22c` 已部署，iOS `0bbf0df0` 已推送；线上 `/ready` 和关系解除并发 smoke 通过，迁移前后备份分别为 schema head `0097`/`0098`。证据见 `artifacts/product-confirmed/20260819-pc-a5/PC-A5/` 和 `docs/superpowers/status/2026-08-19-pc-a5-family-relationship-termination.md`。Gate A 的工程和部署态条件已关闭，当前连续执行交接点为 `PC-B1`。

### Gate A

- testRole 不能绕过 Vault/Grant。
- 密码/OTP 双登录共享一致 Session 与撤权边界。
- V2 facets 能从 Candidate 完整进入 MemoryVersion 和 Projection。
- Family/Visitor 跨域负向测试全部通过。
- 音色创建 5 次上限和家庭解除处置通过并发幂等回归。

## 5. Phase B：正式记忆与回响

### PC-B1 正式记忆总览与二次确认编辑

关联：GAP-03、MEM-003。

后端：

1. 实现 `GET /v2/vaults/{vaultId}/memories`，只返回 current MemoryVersion，支持 kind、query、facet、cursor、limit。
2. 提供正式记忆详情和 current + 3 个历史快照的稳定读取合同；历史快照无用户删除接口。
3. correction command 校验 commandId、expectedVersion、expectedContentHash、schema 和 `secondConfirmation=true`。
4. 原子创建新 MemoryVersion、correction link 和 DecisionReceipt；冲突返回 409；历史超过 3 个时系统滚动淘汰最旧历史快照，但不影响 PublicationVersion。

iOS：

1. 记忆档案新增“正式记忆”入口，只在自己 Owner 身份展示。
2. 支持列表、全文、kind/facets 筛选、关键词、版本历史。
3. 编辑只使用内存草稿；保存时展示差异和二次确认。
4. 未确认关闭、返回或崩溃时不调用写接口、不落盘。

验证：列表分页、筛选、全文、current + 3 历史、滚动淘汰、无手动删除路由、发布快照不受影响、并发 409、杀 App 前无写入、账户切换、VoiceOver 和模拟器 UIQA。

完成定义：Owner 可从统一入口查看和安全纠正 current 正式记忆。

状态：`COMPLETE`（2026-08-19）。Backend 新增 Owner-only 正式记忆聚合读取和二次确认 correction command，生产 PostgreSQL 已验证全文/线索筛选、current + 3、陈旧写冲突、幂等回放、内部版本账本与 PublicationVersion 不变；iOS 新增正式记忆入口、列表、筛选、详情、历史和内存草稿差异确认编辑，账户切换使用 AccountLease/generation fence。Backend `d0718b7` 已部署，iOS `a437c602` 已推送；证据见 `artifacts/product-confirmed/20260819-pc-b1/PC-B1/` 和 `docs/superpowers/status/2026-08-19-pc-b1-owner-formal-memory-library.md`。当前连续执行交接点为 `PC-B2`。

### PC-B2 query-ranked Owner 检索

关联：GAP-04、MEM-004、ECHO-001。

实现：

1. 生产 Owner Context 从 `projectionCitationOrder` 切换为 query-ranked SearchDocument。
2. 候选不超过 20、最终 Context 不超过 8、生成上下文不超过 4,096 字。
3. 每条结果复核 Authority Epoch、current version、content hash 和状态。
4. 无命中返回 `memoryGrounding=gap`，不新增或扩大 KBLite/Legacy Archive 回退；KBLite 现有后台读写行为在本 Work Item 外保持不变。
5. 保留 deterministic fallback 仅用于检索组件故障，并记录原因，不读取额外数据源。

验证：相关性 fixture、删除/纠正后旧版本不命中、撤权、跨账号、容量和延迟预算。

完成定义：Owner 回答使用与问题相关的 current 正式记忆。

状态：`COMPLETE`（2026-08-19）。Backend 将生产 Owner Context 切换到 `deterministicTextFallback` query-ranked SearchDocument，强制候选 20、最终 8 和 4,096 字边界；每条结果在进入上下文前复核 Authority Epoch、current MemoryVersion、content hash 与状态。无命中时直接返回 `memoryGrounding=gap` 且不调用生成 Provider；SearchDocument 缺失时只记录明确 deterministic fallback，不扩大 KBLite/Legacy 数据源。Backend `f093fd6` 完成功能实现，`cee7122/7bd935d` 固化 production-postgres smoke checkpoint，`7bd935d` 已部署，migration head 保持 `0098`。证据见 `artifacts/product-confirmed/20260819-pc-b2/PC-B2/` 和 `docs/superpowers/status/2026-08-19-pc-b2-query-ranked-owner-context.md`。当前连续执行交接点为 `PC-B3`。

### PC-B3 Citation 与 Grounding 收敛

关联：GAP-06、ECHO-004。

实现：

1. `ownerTruthMemoryProjection` 计入 grounded 来源。
2. Citation、contextTraceId、contentHash 继续写入后端审计和 QA 证据包。
3. 普通 iOS 回响不展示来源编号、卡片或原文入口。
4. 无命中 citations 为空；fallback、gap 和 grounded 互斥一致。

验证：grounded/gap/fallback 矩阵、公开 UI 静态检查、QA 导出脱敏。

完成定义：用户界面简洁，内部仍能证明每轮回答依据。

状态：`COMPLETE`（2026-08-19）。Backend 将 `ownerTruthMemoryProjection` 计入 grounded，固定 grounded/gap/fallback 互斥语义，并从服务端实际 Context materialization 自动生成绑定 answerId 的引用审计；`contentHash` 保留用于一致性验证，`contextTraceId` 仅以 SHA-256 写入审计。iOS Evidence Bundle 升级到 schema v4，仅在 QA Gate 下导出脱敏的 Grounding 摘要，公开 Echo 不展示来源编号、来源卡片或原文入口。Backend `559c412` 已部署，migration head `0099`；iOS `e72eca3b` 已推送。证据见 `artifacts/product-confirmed/20260819-pc-b3/PC-B3/` 和 `docs/superpowers/status/2026-08-19-pc-b3-echo-grounding-citation.md`。Gate B 的剩余项为 PC-B4，当前连续执行交接点为 `PC-B4`。

### PC-B4 统一消息中心与未读入口

关联：NOTI-001、PCQ-13、UI-08。

后端：

1. 统一 InAppMessage 列表、分页、未读计数、单条已读、批量已读和删除已读合同。
2. 批量命令使用幂等键；删除已读只能影响当前 Principal 已读消息，不能删除未读或其他账户消息。
3. Candidate、投影/导出、家庭邀请/贡献、授权撤销、账户安全和可重试任务继续聚合；时光信/延迟回复事件保持关闭。

iOS：

1. “我的”增加消息中心按钮。
2. 记忆档案和回响右上角增加系统铃铛；有未读时显示数字红标，三个入口共享同一状态源。
3. 支持列表、空态、失败重试、单条已读、一键已读和一键删除已读；点击消息重新鉴权后进入对应业务详情。

验证：多账户隔离、分页、并发新消息、批量幂等、删除已读负向、前后台刷新、Dynamic Type/VoiceOver 和多尺寸模拟器 UIQA。

完成定义：三页面未读数一致，用户能集中处理普通任务通知，关闭的时光信/延迟回复不会重新暴露。

状态：`COMPLETE`（2026-08-19）。Backend `fccbc28` 已部署并完成 PostgreSQL Owner 隔离、业务事件投影和幂等命令 smoke；iOS 新增 typed client、账户 lease 隔离的权威 Store、三入口共享未读状态、列表/空态/失败重试/分页/单条及批量操作，并在 App 前台恢复时刷新。Debug/UIQA 场景使用脱敏后端权威快照，不访问真实 Provider。标准字号、辅助功能大字号和紧凑机型 UIQA 均通过，证据见 `artifacts/product-confirmed/20260819-pc-b4-uiqa/`；实现说明见 `docs/superpowers/status/2026-08-19-pc-b4-authoritative-message-center.md`。真实 APNs 到达保留为外部真机 Gate，不影响应用内消息中心完成判定。

### Gate B

- 正式记忆列表、编辑、版本历史和 query-ranked Echo E2E 通过。
- Family 私人数据、旧版本和拒绝 Candidate 不进入 Owner Context；KBLite 不产生用户入口或跨权限回退，现有后台行为保持不变。
- Citation 不在普通 UI 暴露。
- 消息中心、铃铛、未读数字和批量操作形成统一闭环。

状态：`COMPLETE`（2026-08-19）。PC-B1 至 PC-B4 的代码、后端部署态 smoke、iOS Gate 和模拟器 UIQA 已通过；连续执行交接点进入 `PC-C1`。

## 6. Phase C：多媒体与导出

### PC-C1 首版图片/文档理解

关联：GAP-07、ARCH-004、MEM-001。

代码闭环：

1. TXT/PDF/DOCX/Markdown parser 统一输出版本化 ExtractionResult 和来源片段。
2. 图片 OCR/描述使用 Provider Adapter，生成带来源的人物、时间、地点候选。
3. 输入版本、处理器版本、输出 hash、时间片和 Source 引用必须持久化。
4. 失败只更新处理状态，不能生成空人物/地点/转写 Candidate。
5. 重试、删除竞争、重复任务、伪装 MIME、损坏文件和跨账号失败关闭。
6. 音频和视频的普通入口、upload intent 和 Worker task 失败关闭，不再列为首版待实现能力。

外部 Gate：真实私有对象存储、Worker、图片 OCR/视觉 Provider、数据地域和删除回执。

完成定义：每种已开放媒体都能生成有来源的 Candidate，或如实显示不可用/可重试。

状态：`WAITING_EXTERNAL_CONFIGURATION`（2026-08-20）。代码与默认关闭闭环已完成：后端和 iOS 统一支持 TXT/PDF/DOCX/Markdown，Markdown 使用 `text/markdown` 合同并在隔离子进程中解析；图片使用服务端 Provider Adapter，兼容旧 OCR 文本，并为结构化描述、OCR、人物、时间和地点定义严格 V1 合同。结构化线索只生成 `inferred`、单条人工确认 Candidate；Provider 不能直接写 Memory，合同异常、hash 篡改、空结果和失败均不生成 Candidate。媒体准入已进一步拆成 public/internal 两条独立路径：普通 authenticated Owner 必须同时满足非 filesystem Provider、`externalVerified=true` 和有效证据时间；filesystem 只可由 `closedPilotAdultSelf + 独立媒体 Feature entitlement` 使用；真实 OTP 只改变认证结果，不参与媒体授权。iOS 普通入口和每次请求均消费 `isPubliclyAvailable`，内部 entitlement 才允许 operational-only readiness。`run-backend-pc-c1-media-admission-gate.sh` 与 iOS runtime smoke 已覆盖该边界。真实腾讯 COS、内容安全扫描器、媒体 Worker、视觉 Provider 质量和删除回执仍为外部 Gate；不能把本项标记为生产完成。既有处理证据见 `docs/superpowers/status/2026-08-19-pc-c1-markdown-document-processing.md`、`docs/superpowers/status/2026-08-19-pc-c1-image-understanding-provider-adapter.md`，准入决策与实现记录见 `docs/superpowers/status/2026-08-20-product-confirmed-development-status-and-pc-c1-decision.md`。

### PC-C2 正式记忆 Markdown 导出

关联：GAP-08、DATA-001。

后端：

1. ExportJob 增加 `exportType=formalMemoryMarkdown`。
2. Renderer 只读取 current MemoryVersion，按 kind 输出正文、facets、时间和版本。
3. 下载使用 `text/markdown; charset=utf-8` 和确定性 `.md` 文件名。
4. Source、Candidate、历史正文、媒体、凭据和内部审计不得进入 Markdown。
5. 客户端不提供 fullAccountArchive；脱敏完整数据的联系、协议、运维权限、审批和审计能力标记 `DEFERRED`，本阶段不实现。

iOS：更新页面范围说明、下载、预览、系统分享、文件保护和分享后清理。

验证：空库、1,000 条、特殊字符、稳定排序、权限、hash、临时文件清理和取消恢复。

完成定义：用户得到可读 Markdown，客户端没有完整账户导出入口；延期的运维导出不被旧 ZIP Job 误标为完成。

状态：`COMPLETE`（2026-08-19）。Backend `a3051d3` 实现 ExportJob、Owner-only API、current-only Renderer 和 migration `0101`，`99bece9/6e21f30` 收敛部署态 MemoryVersion/DecisionReceipt smoke；`6e21f30` 已部署到 production-postgres。iOS `cc1b3174` 实现 typed client、个人页范围披露、状态恢复、取消/重试、文件保护、预览、分享和临时文件清理。后端 122 个定向合同测试、iOS 2 个定向 XCTest、静态 Gate、arm64 模拟器构建、线上 `/ready`、正式记忆导出 PostgreSQL smoke 和 232 条路由认证 smoke 均通过。完整记录见 `docs/superpowers/status/2026-08-19-pc-c2-formal-memory-markdown-export.md`。当前连续执行交接点为 `PC-D1`。

### Gate C

- 图片/文档解析和 Candidate handoff 至少完成非真机/部署态闭环，Markdown 可解析。
- Markdown 内容范围与 MIME、文件名和 iOS 分享一致。
- 外部图片/文档能力未配置时只阻断相应类型，不伪造成功；音频/视频普通流量保持关闭。

状态：`COMPLETE_WITH_EXTERNAL_GATES`（2026-08-19）。PC-C1 的可配置类型按 runtime fail-closed，PC-C2 的正式记忆 Markdown 已完成代码、部署和非真机验证；真实对象存储、内容安全扫描和视觉 Provider 质量仍作为 PC-C1 外部生产 Gate 单独保留，不阻断 PC-D1 代码开发。

## 7. Phase D：发布与 Visitor

### PC-D1 Publication Owner App 闭环

关联：GAP-09、PUB-001。

状态：`COMPLETE_WITH_EXTERNAL_GATES`（2026-08-19）。Backend `9a6d85b` 和 migration `0104`、iOS `0464e31a` 已完成有序多条 Draft/Version、普通 Owner 创建/撤回、不可变版本审计、“当前版本 -> 修订 Draft -> 二次确认 -> 新不可变版本”，以及已注册账户 ShareGrant 创建/查看/撤销管理。正式 Grant 请求只接收手机号或账户 ID；服务端验证接收账户状态并只持久化主体 hash 与脱敏标签，iOS 不展示安全调用余量，账户切换后的旧响应失败关闭。后端 154 项 Publication 测试和 19 项路由认证测试、iOS 12 项 Publication XCTest、静态 Gate、模拟器 UIQA、带 `2BTR77V3R8/com.yxj.dreamjourney.app` 覆盖的 generic iPhoneOS build、部署态 PostgreSQL smoke、236 条路由认证和迁移前后备份均通过。外部发布、法律、安全和数据地域审批仍单独保留，未因此开放真实用户流量。详细证据见 `docs/superpowers/status/2026-08-19-pc-d1-publication-owner-creation.md`。

后端：

1. PublicationDraft 支持有序 memoryVersionIds/items。
2. 每个 item 保存 private ID、publicTitle、publicBody、snapshotHash 和脱敏差异。
3. 二次确认生成不可变 PublicationVersion 和 PublicProjection。
4. 修改必须新建 Draft/Version；支持暂停、撤回和版本审计。
5. ShareGrant 首版只面向已注册账户的手机号或账户 ID，不开放匿名链接；Grant 绑定接收人、范围、版本、有效期和撤销状态。

iOS：正式记忆多选、公开正文编辑、隐私/AI 披露、预览、二次确认、版本和 Grant 管理。

验证：源版本陈旧、重复 item、敏感内容、确认不匹配、撤回、账户切换和并发。

完成定义：普通 Owner 可在 App 内完成创建到撤回，不依赖 QA 页面或预置后端数据。

### PC-D2 Visitor 正式产品闭环

关联：GAP-10、PUB-002。

状态：`COMPLETE_WITH_EXTERNAL_GATES`（2026-08-19）。Backend `836655d` 完成注册账户邀请列表、无原始凭证正式准入和最小产品响应，部署 smoke 修复 `6d44594` 已运行于 production-postgres；iOS `17396b9d` 完成普通用户“受邀回忆”入口、PublicProjection 页面、文字查询和普通实时语音播报。正式链路不返回 Owner 私有主体 ID、Grant credential 或安全调用余额，也不创建腾讯数字人 Session、读取私人域或使用复刻音色。后端 156 项 Publication 测试、iOS 24 项定向 XCTest、发布态静态 Gate、模拟器 UIQA、generic iPhoneOS build、部署态 Visitor PostgreSQL smoke、readiness 和 237 条路由认证均通过。真实用户开放仍保留法律、安全和数据地域审批 Gate；详细证据见 `docs/superpowers/status/2026-08-19-pc-d2-publication-visitor-product-closure.md`。当前连续执行交接点为 `PC-E1`。

实现：

1. 受邀用户查看有效 ShareGrant 并建立 VisitorSession。
2. 只读取 PublicProjection，支持文字和已开放的实时语音回答。
3. Grant 撤销、过期或发布暂停后立即失效；产品层面不设置查询次数，也不提供 Owner 次数设置。
4. 数字人保持关闭；Family 关系不自动创建 ShareGrant。
5. 去除 QA launch argument 和 Profile QA 入口依赖。
6. 服务端继续执行独立的防刷、成本保护、异常流量和 Provider 配额限流；安全限流不得展示成产品查询余额。

验证：授权/未授权、撤权、过期、暂停、无产品次数限制、安全限流、session 缓存、跨 Vault、最小返回和普通用户 UIQA。

完成定义：Visitor 可以使用正式入口查询共享副本，永远不能访问私人域。

### Gate D

- Owner 创建、确认、授权、Visitor 查询、撤权形成完整 E2E。
- Publication 不泄露 private ID、Source、Candidate 或内部审计字段。
- 数字人通道仍为关闭状态。

## 8. Phase E：去阶段化和最终回归

### PC-E1 稳定 Feature 命名与 Release Policy

关联：GAP-13、OPS-001。

实现：

1. 产品代码、页面、接口文档和类名逐步移除 M1-M4、QA-only、Closed Beta 语义。
2. 使用稳定 Feature：`publication`、`publicationGrantManagement`、`publicationVisitor` 等。
3. Release Policy 只负责资格、最低版本、紧急关闭、Provider/Worker readiness 和故障降级。
4. 旧客户端 Feature 名提供期限明确的兼容映射，不产生第二套权限规则。
5. iOS 服务端决策和本地开关不得互相矛盾或自行授予权限。

验证：旧/新客户端矩阵、策略过期、kill switch、capability mismatch、默认拒绝和文案扫描。

完成定义：产品范围不再依赖阶段标签，但所有安全和运行 Gate 仍失败关闭。

状态：`COMPLETE_WITH_COMPATIBILITY_WINDOW`（2026-08-19）。Backend 使用稳定 Feature 作为唯一授权键，发布、Grant 管理和 Visitor 分别决策；旧 `publication*Mx`/`visitorAccess` 只保留到 2026-11-30 的服务端兼容映射，`releaseStage` 不再控制授权。iOS 删除旧产品 Feature 枚举和产品态 M2 AccessGate 命名，只消费有效服务端策略，本地持久化/临时开关不能自行授权。Backend `0c05acf` 完成功能，`9b43a72` 固化并部署稳定 Feature smoke；iOS `6a49ae44` 已推送。完整证据见 `artifacts/product-confirmed/20260819-pc-e1/PC-E1/manifest.json` 和 `docs/superpowers/status/2026-08-19-pc-e1-stable-feature-release-policy.md`。当前连续执行交接点为 `PC-E2`。

### PC-E2 关闭能力零调用与全量回归

1. 数字人 Session 创建、续约和配额消耗为零。
2. 时光信/延迟回复新建和调度为零。
3. 普通任务通知、Echo、档案、正式记忆、家人、音色、发布和 Visitor 回归通过。
4. readiness 报告分别反映代码完成、外部配置和真机 Gate，不把缺失证据标为成功。

状态：`COMPLETE_WITH_EXTERNAL_AND_DEVICE_GATES`（2026-08-20）。Backend `06b6340` 已部署，migration head 为 `0104`，API `/ready` 通过；四个旧 Worker 镜像同步重建后均为 `ready/idle`。部署态 smoke 证明 6 个关闭命令全部被拒，数字人 Session 创建/续约、时光信/延迟回复创建与调度、Provider 投递均为零。iOS `8cd337f1` 完成证据类别分离 Gate，generic iPhoneOS build 通过。证据见 `artifacts/product-confirmed/20260820-pc-e2/PC-E2/` 和 `docs/superpowers/status/2026-08-20-pc-e2-product-confirmed-final-regression.md`。

## 9. 外部配置与真机项

以下不阻止非依赖代码开发，但阻止生产完成声明：

| 领域 | 缺失输入/证据 |
|---|---|
| 认证 | 真实短信 Provider、签名、模板、回执、测试号码；密码哈希参数与风控策略需安全评审 |
| Ownership | shadow 观察、受控 enforce、跨账号生产负向 |
| 媒体 | 私有对象存储、最小权限凭据、SSE、Worker、图片 OCR/视觉 Provider；音频/视频首版关闭 |
| 音色 | 成年本人强身份/活体、正式训练/删除回执、真机听感和音频路由 |
| APNs | Apple key/topic/environment、Provider 回执和真机到达 |
| 发布/Visitor | 成年身份、数据地域、投诉/撤权/删除、安全和法律审批 |
| 真机 | 麦克风、前后台、播放、打断、相册/文件、通知和截图日志 |

## 10. 提交、部署与停止条件

提交：

1. 每个 `PC-*` 独立提交；跨仓库分别提交。
2. 后端通过后推送、部署并跑对应线上 smoke。
3. iOS 通过后提交当前分支；除非明确要求，不自动推送。
4. 文档随功能状态更新，不批量修改无关历史 ledger。

只在以下情况暂停：

1. 需要真实密钥、Provider 账号、证书或不可从现有环境取得的配置。
2. 需要真机、生产数据删除、不可逆迁移或真实用户放量。
3. 产品确认版 PRD 与安全/法律硬约束发生无法兼容的冲突。
4. 当前工作区存在无法辨明归属且会被目标修改覆盖的变更。

## 11. 最终完成定义

1. GAP-01 至 GAP-10、GAP-13 均有完整产品闭环和验证证据。
2. GAP-11、GAP-12 形成 Policy、Runtime、API、UI 和零调用证据。
3. 35 项需求均标记为完成、明确关闭或仅剩外部/真机 Gate。
4. 当前实现证据矩阵、概要设计和 PRD 状态一致。
5. 两仓库 `git diff --check`、相关测试、smoke 和适用构建通过。
6. 生产 readiness 不因代码完成而错误提升；外部证据未齐时继续 no-go。
7. 所有被 Work Item 引用的 PCQ 均有产品 Owner、日期、最终结论和可访问确认凭证。
8. 所有新增或变更页面均引用 UI-01 至 UI-08 中的设计依据，并完成对应功能/UI Gate；没有新 Stitch/htmlCode 的页面不得声明最终视觉验收完成。
9. 每个已完成 Work Item 均有脱敏 `manifest.json`、可复现命令、运行态证据（如适用）和可执行回滚说明。

当前完成判定：功能代码队列已按上述定义收敛；第 6 项明确阻止生产完成声明，因此外部配置和真机证据关闭前，本计划只能标记为 `FUNCTIONAL_CODE_COMPLETE_WITH_EXTERNAL_AND_DEVICE_GATES`，不能标记 `PRODUCTION_COMPLETE`。

## 12. 产品确认后的连续开发队列

本节只规定执行顺序，不复制上方 Work Item 的需求。日常开发从当前批次的第一个未完成 Work Item 开始；完成验证和独立提交后自动进入下一项，不重新通读全部产品文档。

### 12.1 主执行顺序

| 批次 | 顺序 | Work Item | 本批主要交付 | 涉及仓库 | 相对工作量 | 进入条件 |
|---|---:|---|---|---|---|---|
| 0 文档基线 | 1 | 文档基线提交 | 提交确认版 PRD、概要设计、决策记录、证据矩阵、执行计划和静态守卫 | iOS/docs | S | 当前文档检查通过 |
| 1 首版边界 | 2 | PC-00-01 | 数字人普通流量统一关闭并证明零调用 | Backend + iOS | M | 文档基线已提交 |
| 1 首版边界 | 3 | PC-00-02 | 时光信、延迟回复关闭及零新建/零投递 | Backend + iOS | M | PC-00-01 完成 |
| 1 首版边界 | 4 | PC-00-03 | 音频/视频、KBLite 用户入口、完整账户导出边界收敛 | Backend + iOS | M | PC-00-02 完成 |
| 2 身份权限 | 5 | PC-A0 | 密码与 OTP 双登录、重置、锁定和 Session 撤销 | Backend + iOS | L | Gate P0 通过 |
| 2 身份权限 | 6 | PC-A1 | 测试账号角色、entitlement 和 revision | Backend + iOS/内部管理 | M | PC-A0 Session 合同稳定 |
| 2 身份权限 | 7 | PC-A3 | Family/Visitor 私人域与发布域强隔离 | Backend + iOS | L | PC-A1 权限主体稳定 |
| 2 身份权限 | 8 | PC-A5 | 家庭退出/解除、Grant 和贡献处置 | Backend + iOS | M | PC-A3 Grant 路由稳定 |
| 2 身份权限 | 9 | PC-A4 | 独立声音授权和每声音主体累计 5 次创建上限 | Backend + iOS | M | PC-A3 身份/Grant 稳定 |
| 3 记忆模型 | 10 | PC-A2 | Owner Truth V2 facets、兼容和索引 | Backend + iOS | L | 身份权限合同稳定，可与 PC-A5/PC-A4 的 UI 收尾并行 |
| 4 正式记忆与回响 | 11 | PC-B1 | 正式记忆总览、current + 3 历史、二次确认编辑 | Backend + iOS | L | Gate A 通过 |
| 4 正式记忆与回响 | 12 | PC-B2 | query-ranked Owner 检索和 gap 语义 | Backend + iOS | L | PC-B1 current Memory 合同稳定 |
| 4 正式记忆与回响 | 13 | PC-B3 | Grounding、Citation 审计和公开 UI 隐藏 | Backend + iOS | M | PC-B2 完成 |
| 4 正式记忆与回响 | 14 | PC-B4 | 消息中心、三入口铃铛、数字红标、已读/删除已读 | Backend + iOS | M | 消息合同稳定；不依赖 APNs 真机到达 |
| 5 媒体与导出 | 15 | PC-C1 | 图片和 TXT/PDF/DOCX/Markdown 处理及 Candidate handoff | Backend + iOS | L | Gate B 通过；真实 Provider 可后补部署 Gate |
| 5 媒体与导出 | 16 | PC-C2 | current 正式记忆 Markdown 导出、分享和清理 | Backend + iOS | M | PC-B1 current Memory 合同稳定 |
| 6 发布与 Visitor | 17 | PC-D1 | Publication Draft/Version/PublicProjection Owner 闭环 | Backend + iOS | L | Gate C 和 PC-A3 通过 |
| 6 发布与 Visitor | 18 | PC-D2 | 注册账户邀请、VisitorSession、撤权和安全限流 | Backend + iOS | L | PC-D1 完成 |
| 7 发布收敛 | 19 | PC-E1 | 稳定 Feature 命名、旧 alias 和 Release Policy | Backend + iOS | M | Gate D 通过 |
| 7 发布收敛 | 20 | PC-E2 | 关闭能力零调用、全量 regression 和 readiness | Backend + iOS | M | PC-E1 完成 |

每个批次结束必须关闭对应 Gate；某项只因外部配置阻断时，状态记为 `WAITING_EXTERNAL_CONFIGURATION`，保留生产完成缺口并继续不依赖该配置的下一项，不能用 mock 结果标记生产完成。

### 12.2 可并行范围

1. 同一 Work Item 的后端合同、iOS typed model 和 QA 脚本可由不同执行人并行，但必须先冻结 schema/reason code，由一个 Owner 统一验收和提交边界。
2. PC-A2 的 schema/索引开发可在 PC-A5、PC-A4 的 iOS 收尾期间并行；不能在 PC-A3 权限模型未稳定前开放 V2 数据给 Family/Visitor。
3. PC-B4 的 UI 组件可在 PC-B1 后端开发期间并行，但消息深链在目标资源重新鉴权合同完成前不得开放。
4. PC-C1 的 parser、Worker 和 Provider Adapter 可并行；对象存储、扫描器或图片 Provider 未就绪时保持对应 runtime fail-closed。
5. PC-D1、PC-D2 不得在 PC-A3、PC-B1 和 Gate C 之前并行开放，以免把私人 Projection 或未确认记忆发布给 Visitor。

### 12.3 外部输入与代码开发边界

| 外部输入 | 影响 Work Item | 未提供时仍可完成 | 未提供时不能宣称 |
|---|---|---|---|
| 真实短信 Provider、签名、模板和测试号码 | PC-A0 | 密码全链路、OTP adapter、synthetic smoke、Session/风控合同 | 生产 OTP 可用 |
| 私有对象存储、SSE、ClamAV/内容安全扫描 | PC-C1 | parser、Worker、状态机、fake/local adapter、失败关闭 | 真实媒体上传和部署态 E2E |
| 图片 OCR/视觉 Provider | PC-C1 | Provider adapter、mock contract、失败/重试 UI | 真实人物/地点/场景分析质量 |
| 强身份/活体与声音 Provider 正式回执 | PC-A4 | 授权、累计次数、状态机、fake provider smoke | 普通用户生产训练/删除完成 |
| APNs key/topic/environment | PC-B4 | 应用内消息列表、未读、红标、已读和删除已读 | 远程通知真机到达 |
| 发布/Visitor 法律、安全和数据地域审批 | PC-D1、PC-D2 | 完整代码、权限矩阵、synthetic E2E、closed-pilot Gate | 真实用户公开放量 |

### 12.4 本轮明确延期，不进入开发队列

1. 音频档案和视频档案的公开入口、真实上传、解析和发布。
2. 腾讯数字人公开功能及其 Session、配额和音频驱动链路。
3. 时光信和延迟回复的创建、调度、补发与消息事件。
4. 客户端完整账户 ZIP/数据导出，以及运维脱敏完整导出的审批系统。
5. KBLite 只读化、停写、迁移、退出 Echo 或退役；本轮只保证用户不可见且权限不扩大。

以上项目只有形成新的产品确认、独立迁移计划和验收 Gate 后才能重新进入主队列，不得占用当前确认版功能闭环的开发资源。
