# DreamJourney V4 剩余功能闭环执行计划

日期：2026-08-02
状态：`IN_PROGRESS / WAVE_0_BASELINE`
目标：基于当前真实代码复用既有能力，优先完成可部署、可模拟器验收的 M0 功能闭环，再集中执行必要真机验收；不以 shadow、mock、静态检查或文档覆盖冒充产品完成。

## 1. 当前基线与计划口径

当前终版需求包含 36 条 FR、115 个 Work Item。权威证据显示：

- `IMPLEMENTED`：1 条 FR；
- `PARTIAL`：20 条 FR；
- `CONTRACT_ONLY`：4 条 FR；
- `MOCK_ONLY`：1 条 FR；
- `MISSING`：10 条 FR；
- `PROD_VERIFIED`：0 条 FR。

当前活动 Work Item 为 `WI-S1-01-06`。已有代码已经覆盖 Source/Candidate/Confirmation/Projection/Context、Echo、Voice/Digital Human、Family、TimeLetter、Rights 等大量局部合同，因此本计划不从头重建，而是收敛真实调用路径、公开边界和端到端证据。

执行已于 2026-08-02 启动。当前执行基线、提交隔离规则与每个 Wave 的真实完成状态记录在：
`docs/superpowers/status/2026-08-02-v4-functional-closure-baseline.md`。该文件只记录本计划的功能闭环状态；历史 ledger 不作为产品完成证明。

本计划把 115 个 Work Item 保留为追踪索引，但日常只按下述 8 个 Wave 执行。每个 Wave 必须形成用户可感知或生产权威可验证的闭环，不能仅增加一条新的 shadow、launch arg 或静态脚本。

## 2. 本轮目标与明确后置范围

### 2.1 本轮必须完成

1. M0 Owner 私人文字核心：`Source -> Candidate -> DecisionReceipt -> MemoryVersion -> Projection -> QA/Citation -> Correction`。
2. 一个自然输入入口的引导式访谈：持续会话、用户边界、总结、批量确认。
3. 最多两条动态推荐：连续性与知识完整性。
4. 本人查看、复制、可读导出、机器可读清单和删除状态闭环。
5. Family 仅作为静态材料贡献者，不产生私人查询或 Persona 授权。
6. 强身份、owner-bound、跨账号拒绝、ReleasePolicy 和安全降级。
7. 三 Tab 现有 IA 与 Stitch 视觉不被重构；新增功能嵌入现有档案、回响、我的页面。
8. 真实后端、Postgres、模拟器 release-like 回归完成后，再进入真机验收。

### 2.2 本轮继续隐藏或后置

- TimeLetter、Care、真实视频理解不阻塞 M0。
- M1 声音复刻只在 M0 非真机闭环完成后进入专项真机验收。
- M2 Publication/Visitor/Digital Human 公开互动继续关闭，等待身份、监管、安全评估和产品 Gate。
- M3/M4 不进入自动开发，只保留 hard deny、schema/contract 和安全边界。
- 对象存储、OCR、ASR、PDF/DOCX 作为独立媒体 Wave，不阻塞文字 M0。

## 3. 连续执行顺序

### Wave 0：开发基线隔离与完成口径校准

目标：半天内建立可持续提交边界，不清理或误提交其他人的工作区改动。

任务：

1. 记录 iOS、Backend 当前提交、部署版本和未提交文件白名单。
2. 后续每个 Slice 只精确 stage 本 Slice 文件；过程 ledger、临时截图和无关脚本不进入功能提交。
3. 为下述 Wave 建立一个精简状态表，只记录 `NOT_STARTED / IN_PROGRESS / FUNCTIONAL_VERIFIED / DEVICE_REQUIRED / EXTERNAL_BLOCKED`。
4. 旧 `INTERNAL_READY` 只作为已有资产提示，不自动计入完成。

退出条件：可以从提交和测试报告准确回答“本轮增加了哪个真实能力、是否部署、是否可被普通用户或 closed-pilot 用户使用”。

### Wave 1：Owner Truth 主链真实闭环

关联：`FR-SRC-003`、`FR-CHAT-002/003`、`FR-MEM-001/002`、`FR-QA-001/002`，主 Work Item `WI-S1-01-06`。

目标：把当前分散、default-off 的 Owner Truth 组件串成 closed-pilot 可用链路。

任务：

1. 文字输入创建持久化 Source，使用稳定 command ID、AccountLease、owner/vault/authority epoch。
2. Extraction worker 从 Source 生成 pending Candidate；失败、重试、失效和隔离均有持久状态。
3. iOS 待确认页支持批量接受、部分接受、逐条纠正/拒绝，并处理重启、409、source inactive 和 response mismatch。
4. DecisionReceipt 与 immutable MemoryVersion 同一事务提交；每个 MemoryRecord 只有一个 current version。
5. Projection worker 仅消费已确认 MemoryVersion；KBLite 保留 compatibility read，不再成为事实写入权威。
6. `/context/build` 只读 active confirmed Projection，返回 typed citation；Correction 创建新的 Candidate，不原地改事实。
7. closed-pilot ReleasePolicy 由服务端授予；普通 release 默认关闭，客户端 flag 不能自行授权。

必须验证：

- 后端单元、API、Postgres 并发/重放 smoke；
- iOS typed contract、XCTest、候选确认模拟器 UIQA；
- App 强杀重开后 Candidate、确认结果和 current MemoryVersion 一致；
- owner A 的 Source/Candidate/Memory/Context 对 owner B 始终 404/deny；
- 真实部署后执行 `Source -> Candidate -> Confirm -> Projection -> Context -> Correction` smoke。

退出条件：上述链路不依赖 QA header、in-memory fixture 或本地假数据即可在 closed-pilot 账号运行。

预计：3-5 个集中工程日。

### Wave 2：最小引导式访谈闭环

关联：`FR-CHAT-001/002/003`、`FR-MEM-001`。

目标：把 Echo 从普通问答升级为 V4 确认的自然输入访谈，不改变全屏视觉框架。

任务：

1. 后端持久化 ConversationThread、InterviewSession、当前话题、deepening count、summary count、candidate batch count 和用户边界状态。
2. Orchestrator 只输出 `LISTEN / DEEPEN / CLARIFY / SUMMARIZE / PAUSE`，每轮最多一个主要问题。
3. 同一线索通常 2-4 轮后总结；退出或 5-10 轮后形成 review batch，不直接写 MemoryVersion。
4. `skipOnce / cooldown / doNotAsk / explicit reopen` 走现有 typed command，并在真实会话中生效。
5. 用户主动换话题后一轮内切换或暂停旧 Thread；旧异步回调不得污染新话题。
6. 高风险表达优先退出 Persona/延迟链路，回到中性安全响应；不写入访谈事实。
7. iOS 在现有 Echo 中展示自然总结、待确认结果和可续线索；内部 thread/fatigue 分数不公开。

必须验证：连续 10 轮模拟会话、换题、暂停、禁问、重开、断网重试、强杀恢复、敏感阻断、跨账号隔离。

退出条件：一个用户可以从自然输入开始，持续访谈，结束后看到待确认 Candidate，并在确认后进入正式记忆。

预计：3-5 个集中工程日。

### Wave 3：双推荐与知识地图

关联：`FR-MEM-002/004`、`FR-QA-001`。

目标：提供一条“接着聊”和一条“换个角度”，不增加主题目录管理负担。

任务：

1. 从 confirmed MemoryVersion 派生六维 DimensionCoverage 与 KnowledgeGap；Candidate 不计确认覆盖。
2. 连续性推荐来自最近未完成 Thread；完整性推荐来自安全知识缺口。
3. 同时最多两条，允许 0-1 条；同义、同缺口、doNotAsk、敏感、跨 Vault、AI-only 候选全部过滤。
4. 每条保存 reason code、policy version、evidence reference 和过期时间。
5. 在 Echo 现有入口以轻量按钮呈现；人生地图只读展示确认后的 Projection。

必须验证：离线推荐语料、重复过滤、敏感负向集、跨账号、过期、0/1/2 条布局和模拟器截图。

退出条件：推荐可解释、可关闭、不会使用未确认内容，也不会改变当前 Stitch 整体视觉。

预计：2-4 个集中工程日。

### Wave 4：M0 数据权利、家庭贡献与安全边界

关联：`FR-ACC-001/002`、`FR-PRIV-001..005`、`FR-SAFE-001`、`FR-OPS-001..003`。

目标：补齐 M0 发布前真正会阻断验收的账号、权利和安全功能。

任务：

1. 普通客户端彻底移除 system/shared token 能力；访问/刷新/撤销和账号切换使用 owner-bound session。
2. 所有 M0 路由启用 ownership enforce；system/operator/data-rights principal 分离。
3. 本人数据提供：页面查看、复制、可读导出包、机器可读 manifest、第三方内容裁剪说明。
4. 删除状态统一为 `accessRevoked / pending / partial / unsupported / completed`；Source 删除传播到 Projection/Context，账号删除传播到本地、后端、对象/provider 待办。
5. Family Contributor 通过明确邀请和授权提交带来源材料；不能读取 Owner 私人 Context，不能自动获得 Voice/DH/Persona。
6. 统一 AI 身份披露、失败降级、退出入口和高风险即时阻断；M2/M3 route 继续服务端 hard deny。
7. 关键操作写 operation/rights/incident receipt，并有失败、取消、重试和 unknown 分母。

必须验证：A/B 账号全路由矩阵、session replay、导出内容检查、删除重试/部分完成、Family 越权负向、release scope regression、部署 Postgres smoke。

退出条件：M0 核心功能不依赖共享 token；用户可以查看、导出、纠正、删除自己的数据；家庭关系不会扩大私人查询权限。

预计：4-6 个集中工程日。真实 OTP、Provider 删除和异地备份回执若缺外部条件，明确标为 `EXTERNAL_BLOCKED`，但对应能力保持 fail-closed。

### Wave 5：公开 M0 UI 与 release-like 集成

目标：把前四个 Wave 从 QA 页面收敛为 closed-pilot 产品体验。

任务：

1. 保留“记忆档案 / 回响 / 我的”三 Tab 与现有全屏 Echo；不做整体 IA 重构。
2. 档案页承载 Source 创建、待确认、正式记忆、导出/删除；回响页承载访谈、推荐、引用和纠正；我的页承载账号、家庭邀请和隐私状态。
3. 删除 QA 技术文案和内部状态字段，只保留用户可行动的状态、失败原因和重试入口。
4. M1-M4 全关时 M0 仍完整可用；隐藏能力不得通过路由、文案、深链或旧缓存误暴露。
5. 以当前 Stitch 画布/htmlCode 为视觉主依据，完成模拟器多尺寸 visual QA。

必须验证：公开 release regression、三条核心 UIQA、Dynamic Type/暗色/离线/空态/失败态、iPhoneOS generic build。

退出条件：closed-pilot 用户无需 QA launch arg 即可完成 M0 主流程，普通 release 仍由服务端 cohort 控制。

预计：2-3 个集中工程日。

### Wave 6：非真机发布门与部署验收

目标：在进入真机前一次性关闭所有可自动完成的 Gate。

统一 Gate：

1. 后端全套测试和 lint/compile；
2. 所有新增 migration 在隔离 Postgres 执行 upgrade、rollback、replay；
3. 部署服务器，验证 `/ready`、schema head、auth、Owner Truth、Context、Rights；
4. 模拟器跑 M0 E2E：登录 -> 访谈 -> Candidate -> 确认 -> MemoryVersion -> QA/Citation -> Correction -> Export/Delete；
5. A/B owner isolation、release hidden-feature、断网/重启/重复回调回归；
6. `git diff --check`、iOS XCTest、generic iPhoneOS build；
7. 生成单一 release evidence bundle，记录 commit、部署版本、测试、截图和剩余 `DEVICE_REQUIRED / EXTERNAL_BLOCKED`。

退出条件：非真机缺口为 0；剩余问题必须只能由真实麦克风、相册、通知、Provider、设备性能或签名环境证明。

预计：2-3 个集中工程日。

### Wave 7：集中真机验收与 M1 Voice 专项

目标：只在非真机 Gate 全绿后进行一次有明确清单的真机验收。

M0 真机项：登录/刷新、相册权限与照片本地保存、前后台切换、通知跳转、截图/日志、低网与重启恢复。

M1 Voice 项：

1. 只允许在世成年人本人训练；随机授权语句、本人确认、活体/质量/SNR Gate；
2. 试听音色与 Echo 实际音色一致；
3. 后端复刻 TTS -> Tencent audio-drive 单一音频 owner；
4. 有声、口型动、可打断、停止后恢复麦克风、连续五轮无旧音频尾段；
5. provider 失败不静默换默认音色；删除/禁用进入可追踪状态；
6. Family 不能代录，逝者和未成年人路径 hard deny。

退出条件：M0 真机验收包完成；M1 若 Provider/G3/G4 未通过则保持隐藏，不阻塞 M0 closed pilot。

预计：2-4 个设备验收日，另加 Provider/账号/配额等待时间。

## 4. 暂不进入主线的后续 Wave

### M2 Publication/Visitor/Digital Human

只有在成年身份、独立 PublicationVersion、ShareGrant、Visitor principal、撤回传播、持续 AI 标识、2 小时提醒、危机/退出、安全评估和算法备案 Gate 明确后启动。当前已有数字人 runtime 只能作为技术资产，不能替代 M2 权限域。

### M3/M4

老人健康、成人纪念互动、知识许可和收益继续 `OFF`。在专项产品、法律、隐私、Provider 和运营授权前不实现公开功能。

## 5. 时间与完成度预期

在复用当前代码且不等待外部审批的前提下：

| 目标 | 预计工程量 | 完成后的可声明状态 |
| --- | --- | --- |
| Wave 0-1 | 3.5-5.5 人日 | Owner Truth 主链可在 closed-pilot 真实后端运行 |
| Wave 2-3 | 5-9 人日 | 引导式访谈、批量确认、双推荐和知识地图可用 |
| Wave 4-5 | 6-9 人日 | M0 数据权利、安全、家庭贡献与公开体验闭环 |
| Wave 6 | 2-3 人日 | 所有非真机 Gate 收敛，具备真机验收条件 |
| Wave 7 | 2-4 人日 | M0 真机验收；M1 Voice 形成独立结论 |

非真机 M0 功能闭环的现实量级为约 17-27 个集中工程日。若并行协作，只允许后端合同、iOS UIQA 和独立验证在不共享 writer/Authority 的前提下并行；Owner Truth writer、Account AuthZ 和 AudioSession 各自始终只有一个主控。

## 6. 每个 Slice 的固定完成定义

一个 Slice 只有同时满足以下条件才算完成：

1. 用户流程或生产 Authority 行为真实改变，不只是新增设计/flag/mock；
2. 正向、失败、重试、重启、重复请求和跨账号负向均有自动化；
3. iOS 相关检查、XCTest、模拟器 UIQA、generic iPhoneOS build 通过；
4. 后端相关测试、Postgres smoke、部署后线上 smoke 通过；
5. `git diff --check` 通过，iOS 与 Backend 分仓独立提交；
6. handoff 记录真实 commit、部署版本、测试证据和未关闭 Gate；
7. default-off、shadow 或外部未验收能力不得被标记为产品完成。

## 7. 恢复执行时的唯一下一步

从 `WI-S1-01-06` 继续，不再新增零散证据分支：先完成 Wave 0 的精简状态基线，然后直接推进 Wave 1 的真实 `Source -> Candidate -> Confirmation -> MemoryVersion -> Projection -> Context -> Correction` closed-pilot E2E。该 E2E 未跑通前，不进入推荐、媒体、Voice 或 Publication 新功能。
