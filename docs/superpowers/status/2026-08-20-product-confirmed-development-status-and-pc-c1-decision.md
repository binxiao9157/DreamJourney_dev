# 寻梦环游产品确认版开发完成情况与 PC-C1 已确认决策

日期：2026-08-20
文档性质：当前实现盘点与已确认开发决策
发布结论：`NO-GO`

## 1. 审计基线

| 工程 | 分支 | 当前 HEAD | 状态 |
|---|---|---|---|
| iOS | `feature/prd-stitch-ui-adaptation` | `7736a7c0` | 已推送基线；本轮 PC-C1 代码和本状态文档待独立提交，其他既有未跟踪文件不纳入 |
| Backend | `main` | `06b6340` | 已推送并部署基线；本轮 PC-C1 准入修改待独立提交和部署，migration head 不变 |

日常执行依据：

- `docs/superpowers/plans/2026-08-18-dreamjourney-product-confirmed-gap-01-13-execution-plan.md`
- `docs/product/寻梦环游_产品确认版当前实现证据矩阵_2026-08-18.md`
- `artifacts/product-confirmed/20260820-pc-e2/PC-E2/readiness-report.json`

计划执行表共有 20 个顺序项，其中第 1 项是文档基线，实际 PC Work Item 为 19 个。当前准确口径为：

- 17 个 Work Item 已完成代码闭环或以明确外部/真机 Gate 完成。
- 2 个 Work Item 为 `WAITING_EXTERNAL_CONFIGURATION`：PC-A0、PC-C1。
- 不能将“20 个执行单元”表述为“20 个 Work Item”。

## 2. 当前阶段完成情况

| 阶段 | 当前状态 | 已完成内容 | 尚未关闭内容 |
|---|---|---|---|
| Phase 0 产品关闭边界 | 完成 | 数字人、时光信、延迟回复四层关闭；部署 smoke 证明零创建、零续约、零调度和零 Provider 投递 | 无功能开发余项 |
| Phase A 权限与数据基础 | 代码基本完成 | Access/Refresh、密码链路、测试账号权限、Owner Truth V2、Family/Visitor 私人域隔离、家庭解除、声音创建 5 次上限 | PC-A0 真实短信 Provider；Ownership 仍为 `shadow`；声音强身份/活体仍未接入 |
| Phase B 正式记忆与回响 | 完成 | 正式记忆总览、current + 3 历史、二次确认编辑、query-ranked 检索、Grounding/Citation 审计、统一消息中心 | APNs Provider 和真机通知到达；无新增 Stitch 页面时不能声明最终视觉验收完成 |
| Phase C 多媒体与导出 | 部分完成 | TXT/PDF/DOCX/Markdown parser、图片 Provider Adapter、Candidate handoff、失败重试、正式记忆 Markdown 导出；PC-C1 public/internal 准入和 OTP 解耦已实现 | 真实私有对象存储、内容安全扫描器、媒体处理 Worker、视觉 Provider 和删除回执待完成 |
| Phase D Publication/Visitor | 代码完成、外部阻断 | Draft/Version/PublicProjection、修订、撤回、Grant、VisitorSession、PublicProjection 查询和普通语音 | 法律、安全、隐私、数据地域和真实放量审批；普通流量保持关闭 |
| Phase E 发布收敛 | 完成 | 稳定 Feature、旧 alias 兼容窗口、关闭能力零调用和最终 regression | 旧 alias 在 2026-11-30 前完成退役回归 |

## 3. 当前 Readiness

| 类别 | 当前结果 | 结论 |
|---|---:|---|
| 代码 Gate | `3/3 ready` | Backend、iOS 和 generic iPhoneOS build 已验证 |
| 外部配置 Gate | `0/8 ready` | 仍阻止生产发布 |
| 真机 Gate | `0/6 ready` | 尚未开始本轮最终真机验收 |

当前 8 项外部阻断：

1. OTP 仍为 `testAllowlist`。
2. Ownership 仍为 `shadow`。
3. 私有对象存储没有生产外部验证。
4. 媒体处理 Worker 未启用。
5. 图片 Provider 不支持真实视觉输入。
6. 声音强身份/活体与生产证据未完成。
7. APNs 未启用。
8. Publication/Visitor 仍为 `externalBlocked`。

当前 6 项真机余项：麦克风、前后台恢复、音频播放/中断、照片与文件导入、APNs 到达、截图与日志证据。

## 4. 关键实现边界

### 4.1 与计划一致的关闭能力

- `digitalHumanLivePanel=false`，普通流量不能创建或续约腾讯数字人 Session。
- `timeLetters=false`、`echoDelayedReplies=false`，不能新建或调度。
- 音频和视频档案普通入口保持关闭。
- KBLite 用户界面关闭，但后台现有读写和权限行为保持不变。
- 完整账户数据导出在客户端无入口；只开放正式记忆 Markdown 导出。

### 4.2 已实现但尚未生产开放

- Publication/Visitor 已具备代码闭环，但 Release Policy 明确拒绝普通流量。
- 声音复刻查询、试听、接受、合成等合同存在；新训练因强身份/活体 Provider 缺失而关闭。
- 图片/文档媒体代码存在，但生产存储、处理和视觉能力没有完成外部验收。

## 5. PC-C1 媒体准入已确认决策

状态：`CODE_COMPLETE_WITH_EXTERNAL_CONFIGURATION_PENDING`

### 5.1 当前事实

1. 当前开放候选媒体类型为图片、TXT、PDF、DOCX 和 Markdown；音频、视频保持关闭。
2. 线上 `ownerTruthMediaStorage` 使用服务器本地 `filesystem`，不是腾讯 COS。
3. Runtime 当前返回：
   - `enabled=true`
   - `providerReady=true`
   - `releaseVisible=true`
   - `externalVerified=false`
   - `provider=filesystem`
   - `region=serverLocal`
4. 文档处理能力当前 `enabled=false`，原因是 `workerDisabled`。
5. 图片分析 Provider 为 `deepseek/text-only`，`supportsVision=false`。
6. 修复前 iOS `canOpenCapture` 只检查 Provider 可运行和 `releaseVisible`；当前已要求 `externalVerified=true`，并对 public 路径额外拒绝 filesystem。
7. 修复前后端 authenticated Owner 在 capability operational 时即可放行；当前 ordinary Owner 使用 public readiness，closed pilot 只有独立媒体 entitlement 才可使用 operational readiness。

因此，在当前测试白名单账号范围内，图片/文档入口可能使用服务器本地 filesystem；一旦直接启用真实 OTP，又不调整媒体 Gate，普通注册账号可能被连带开放到尚未完成生产验收的存储链路。

### 5.2 已确认的产品与工程决策

| 编号 | 待确认问题 | 推荐结论 | 最终结论 |
|---|---|---|---|
| PC-C1-D1 | 服务器本地 filesystem 是否允许作为普通用户生产存储 | 不允许；仅限内部测试/受控试点 | 同意推荐结论 |
| PC-C1-D2 | 普通用户媒体入口是否必须等待 `externalVerified=true` | 必须；普通用户使用 public readiness，不使用 closed-pilot readiness | 同意推荐结论 |
| PC-C1-D3 | 内部测试账号是否继续允许使用 filesystem | 允许，但必须由独立 internal entitlement 明确授权，不能复用普通 authenticated Owner | 同意推荐结论 |
| PC-C1-D4 | 存储可用但 Worker 关闭时是否允许普通用户上传 | 不允许公开；内部测试可上传，但必须显示“已保存，等待处理”，不得显示“已分析” | 同意推荐结论 |
| PC-C1-D5 | 文档处理与图片视觉是否必须一起开放 | 不需要；按媒体类型分别 Gate。文档处理完成后可独立开放，图片等待视觉 Provider | 同意推荐结论 |
| PC-C1-D6 | 启用真实 OTP 是否可以自动开放媒体 | 不可以；认证开放与媒体能力开放必须解耦 | 同意推荐结论 |

### 5.3 已确认实施边界

1. 后端普通用户策略要求 `externalVerified=true` 才允许媒体 Feature。
2. iOS 普通用户入口改用 `RuntimeCapabilitySnapshot.isPubliclyAvailable`。
3. 内部 entitlement 才能使用 `isClosedPilotAvailable` 和 filesystem。
4. 生产存储切换为私有 COS，并完成最小权限、HTTPS、SSE、内容扫描和删除回执。
5. 文档 Worker 与图片视觉 Provider 使用独立 capability，按类型分别启用。
6. 增加回归，证明启用真实 OTP 不会自动开放媒体。
7. 音频、视频继续保持 `productClosed`，不受本决策影响。

### 5.4 代码实施结果

1. Backend `ReleasePolicyService` 新增独立 `public_capability_resolver`，媒体普通用户在 operational ready 但外部证据缺失时稳定返回 `externalVerificationRequired`。
2. 新增 `media_release_admission.py`，filesystem 永远返回 `internalProviderOnly`；COS/S3 必须配置独立验证开关和 30 天内有效的证据时间。
3. 存储和处理使用两份独立外部证据，存储通过不会自动开放处理 Worker。
4. 处理能力同时依赖存储运行控制；即使 Worker 自身健康，只要存储被 kill switch、健康检查或删除对账阻断，处理快照也会 fail-closed。
5. closed-pilot 媒体必须同时满足服务器 owner allowlist、`RELEASE_POLICY_CLOSED_PILOT_FEATURES` 媒体项及测试账号显式 Feature entitlement；普通 authenticated Owner 和真实 OTP 都不能复用该路径。
6. iOS `OwnerTruthMediaRuntimeCapability` 已把 public 与 internal readiness 分离；记忆档案入口、上传、读取、重试和删除请求均再次校验 typed runtime snapshot。
7. 新增后端 `scripts/run-backend-pc-c1-media-admission-gate.sh`，并扩展 iOS `run-owner-truth-media-runtime-capability-smoke.sh`，覆盖 filesystem、外部证据、独立处理 Gate、内部 entitlement 和 OTP 解耦。

### 5.5 本轮验证证据

Backend：

- `scripts/run-backend-pc-c1-media-admission-gate.sh`：8 项通过，包含证据超过 30 天自动关闭。
- `scripts/run-backend-owner-truth-media-provider-matrix-gate.sh`：50 项通过；脚本已固定使用仓库 Python 与临时 module cache。
- `tests.test_release_policy`、`tests.test_runtime_capabilities`、媒体 API、测试账号授权关联回归：106 项通过。
- `git diff --check`：通过。

iOS：

- `Scripts/QA/product-v4/run-owner-truth-media-runtime-capability-smoke.sh`：runtime smoke 与 public admission 静态检查通过。
- `Scripts/QA/product-v4/run-product-confirmed-final-closure-gate.sh`：通过；历史严格证据组仍按既有规则因报告缺失而跳过，未将其误记为新证据。
- iPhoneOS Generic Debug 构建通过，使用本机固化覆盖 `PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app`、`DEVELOPMENT_TEAM=2BTR77V3R8`；报告位于 `tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260820-pc-c1-media-admission-escalated/report.md`。
- `git diff --check`：通过。

本轮未推送、未部署。线上仍运行 Backend `06b6340` 的旧准入口径；必须从本轮正式提交部署后再跑线上 smoke，才能确认服务器生效。

### 5.6 实施完成前的约束

- 不把 PC-C1 标记为生产完成。
- 不将 filesystem 描述为已完成私有对象存储部署。
- 不向普通用户展示“分析完成”或伪造人物、地点、场景线索。
- 不因为真实 OTP 上线而自动扩大媒体入口范围。

## 6. 证据与文档缺口

1. 19 个 PC Work Item 均有 manifest，但其中 8 个目录只有 `manifest.json`，没有计划模板列出的完整原始证据文件。
2. PC-B4 UIQA 截图目录 `artifacts/product-confirmed/20260819-pc-b4-uiqa/` 当前未纳入 Git，但正式状态文档引用了该目录。
3. 最终 iOS Gate 通过，但 Release QA package 输出中仍有 8 组历史严格证据检查因报告或 build log 缺失而跳过。
4. 正式记忆、Publication/Visitor 和消息中心没有新增 Stitch/htmlCode，只能认定功能 UI 完成，不能认定最终视觉验收完成。

以上不推翻代码闭环结论，但需要在发布验收前补齐或明确证据存储策略。

## 7. 后续推荐顺序

1. 提交并部署 PC-C1 准入修改，线上确认当前 filesystem 返回 `externalVerified=false`、普通 Owner 返回 `externalVerificationRequired`。
2. 接入真实 OTP Provider，但在 Ownership 进入受控 `enforce` 前不放量；上线 smoke 必须证明媒体仍保持关闭。
3. 完成 COS、内容扫描、文档 Worker、视觉 Provider 和删除回执；外部 smoke 通过后才写入验证时间并开放对应 public capability。
4. 补齐 Work Item 证据包和 PC-B4 UIQA 证据归档。
5. 完成 APNs、Publication/Visitor 审批和最终真机验收。

在上述外部与真机 Gate 关闭前，正确状态仍是：

`FUNCTIONAL_CODE_COMPLETE_WITH_EXTERNAL_AND_DEVICE_GATES`，不是 `PRODUCTION_COMPLETE`。
