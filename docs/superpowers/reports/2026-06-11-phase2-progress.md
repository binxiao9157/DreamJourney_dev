# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 82% | 合约和 iOS client 已固化；DeepSeek chat/knowledge/image、Memoir、TTS 入口默认 fail-closed，支持显式 mock allow 演示开关，并已接入真实 `/v1/safety/evaluate` HTTP transport 最小闭环。 |
| Privacy Scope 模型 | 92% | `ConversationTurn`、`Stage1MailboxMemoryInput`、`DialogMessage`、MemoryArchive、TimeMailbox、KBLite v2 实体已携带 `privacyMetadata`；`FamilyMemberVisibility` 已区分 all-family 与 selected-members，空成员选择不再误开放为全体可见，旧数据继续兼容迁移。 |
| KBLite/Export/Widget 过滤 | 78% | KBLite remote extraction、prompt context、JSON export、Widget App Group、PDF 输入图谱、backend sync 已按 scope 过滤；familySync/careDashboard graph 支持按目标家庭成员二次裁剪。 |
| CareDashboard/Family Sync 阶段2 | 72% | Family share package、FamilyRepository 已改用 familyCircle sanitized graph；CareDashboard transcript 入口按 `.careDashboard` 和目标成员可见性过滤；亲友成员行可进入成员视角看板，KBSync 导出可显式选择全体或单个成员目标；看板新增用户观测窗口、数据覆盖说明、脱敏观察报告和风险信号解释。 |
| Roadshow Demo Cut 闭环 | 78% | 已补路演 seed、reset、offline launch 参数，App 启动自动注入演示家庭成员/信箱/档案/照片 mock analysis/KBLite graph/关怀转录；offline 参数已驱动 mock dialog 和 mock safety；完成 12 步路演脚本、真机 smoke checklist、失败兜底矩阵、产品边界文案和真机 preflight 脚本；下一步是接入物理 iPhone 后逐屏 smoke、导出分享包 JSON 抽查和现场计时演练。 |

## 已完成

- 抽出 `DialogEndReason` 和 `DialogEngineDelegate` 到 `DialogEngineModels.swift`，解除 mock 验证对火山 SDK manager 的依赖。
- 新增 `MockDialogEngine`，支持 setup/start/stop/destroy、确定性回复、高风险触发危机结束。
- `DialogEngineFactory` 新增 `.mock` 和 `makeDefault(arguments:environment:)`。
- `AIRecordingViewController` 改用 `DialogEngineFactory.makeDefault()`。
- 新增 `Scripts/MockDialogEngineVerify/main.swift` 和 `Scripts/verify_phase2.sh`。
- 在新阶段2 worktree 执行 `pod install`，建立可构建依赖基线。
- 新增 `SafetyGuardRequest/Response/Audit` 与 `SafetyGuardClient`，建立服务端 guard 接入骨架。
- 新增 `MemoryPrivacyScope`、`MemoryUseSurface`、`PrivacyScopePolicy` 和 migration helper。
- 新增 `Scripts/SafetyGuardVerify/main.swift`、`Scripts/PrivacyScopeVerify/main.swift`，并接入阶段2统一验证脚本。
- 新增 `ConversationTurn.privacyMetadata` 与 `Stage1MailboxMemoryInput.privacyMetadata`，旧数据缺字段时默认 `.localOnly`。
- `KBLiteGraph.version` 升至 2，`KBPerson/KBPlace/KBEvent/KBFact` 增加 privacy metadata。
- 新增 `KBLitePrivacyScopePolicy`，KBLite 远端提取只允许 `.generationAllowed` transcript，prompt context 过滤不可用实体。
- 新增 `DeepSeekSafetyGuarding`，DeepSeek chat/knowledge/image、Memoir 生成、Memoir TTS 发起前执行 guard。
- 新增 SafetyGuard mock allow 选择器：默认仍 fail-closed，使用 `--use-mock-safety-guard` 或 `DREAMJOURNEY_SAFETY_GUARD=mock_allow` 时才允许阶段2远端演示。
- 新增 `SafetyGuardHTTPTransport` 和可注入 `SafetyGuardHTTPClient`，配置 `DREAMJOURNEY_SAFETY_GUARD_BASE_URL` 或 `SafetyGuardBaseURL` 后 POST 到 `/v1/safety/evaluate`；支持可选 `DREAMJOURNEY_SAFETY_GUARD_API_KEY` / `SafetyGuardAPIKey` Bearer token。
- `DeepSeekSafetyGuarding.makeDefaultClient` 增加真实 guard endpoint 配置入口；显式 mock allow 优先，未配置 endpoint 时仍使用 unavailable transport fail-closed。
- 新增 `KBLitePrivacyScopePolicy.sanitizedGraph`，按 `MemoryUseSurface` 裁剪 KBLite graph 并清理人物、地点、事件、事实之间的悬挂引用。
- `KBLiteManager.exportJSON(surface:)`、Widget App Group 输出、OpenAvatar backend sync、KBLite PDF 输入图谱已统一走 sanitized graph；当前 `.export`、`.widget`、`.backendSync` 在未显式授权前保持空输出。
- Family share package 和 `FamilyRepository` 改用 `.familySync` sanitized graph，只允许 `familyCircle` 进入家庭同步/亲属圈自动同步。
- 新增 `FamilyMemberVisibility`，`MemoryPrivacyMetadata` 可表达 all-family 或 selected-members；旧数据缺字段默认 all-family，指定成员内容在未传目标成员时不外发。
- `PrivacyScopePolicy`、`KBLitePrivacyScopePolicy.sanitizedGraph`、`KBLiteManager.exportJSON` 和 `KBLiteMultiUser.generateSharePackage` 支持 `familyMemberID`，familySync/careDashboard 可按成员裁剪实体和关系引用。
- `FamilyMemberVisibility` 增加 `includesAllMembers` 显式标记，`.selectedMembers([])` 不再等价于 all-family；旧版 `allowedMemberIDs` JSON 仍可解码为选定成员范围。
- 新增 `CareDashboardInputPolicy`，CareDashboard transcript 过滤从 VC 中抽出，按 scope、目标成员和信箱/档案馆前缀排除后再交给 `CareSignalAnalyzer`。
- MemoryArchive 和 TimeMailbox 模型新增 `privacyMetadata`，旧数据迁移为保守 scope；MemoryArchive 文本/照片、TimeMailbox 写信 UI 已支持显式选择私密/本机/可生成/亲友范围。
- MemoryArchive 保存到 Stage1 对话记忆和图片分析入 KBLite 时保留用户选择的 scope；照片只有 `.generationAllowed` 才触发远端图片分析。
- CareDashboard 读取当前 transcript 前按 `.careDashboard` 过滤，默认 localOnly 对话不进入家庭关怀看板统计。
- 普通对话首页新增会话级使用范围选择：默认本机，可显式选择可生成或亲友；ASR/TTS/chat 兜底消息写入 Stage1 时保留当前会话 scope。
- 普通对话照片上传沿用会话 scope；只有 `.generationAllowed` 才触发 DeepSeek Vision 与 KBLite 图片分析入库。
- `DialogMessage` 新增 `privacyMetadata`，回忆录生成入口和 `MemoirService` 服务层均按 `.memoirGeneration` 过滤，未授权内容不进入 DeepSeek 生成。
- `ConversationMemory.lastSummaryPrivacyMetadata` 记录会话摘要 scope，SDK prompt context 和历史开场白只使用 `.prompt` 允许的 generation 摘要；旧 summary 默认 `.localOnly`。
- KBLite 派生实体遇到 mixed-scope transcript 时降级为 `.localOnly`，避免 local 内容被 generation 片段共同提升为远端可用实体。
- KBLite 同名实体/事实只允许同 scope 合并；LLM merge、quickExtract fallback、图片分析入库和 JSON import 均使用同 scope matcher，跨 scope 同名内容保留为独立实体，避免 generation/family/local 字段互相污染或丢失。
- KBLite prompt query 关联事实、开场白 hint、知识缺口上下文均按 `.prompt` 过滤；local summary 不再阻断已有 generation KBLite prompt context。
- Family 亲友列表成员行接入 `CareDashboardViewController(viewerFamilyMemberID:)`，成员级可见性从 UI 入口传到看板输入过滤；行内文案同步调整为“关怀看板”。
- KBSync 导出入口新增目标对象 action sheet：用户需显式选择“全体亲友”或具体成员，成员导出会调用 `generateSharePackage(forFamilyMemberID:)`，取消不会生成分享包。
- CareDashboard snapshot 增加基于用户发言的观测窗口、观测天数、数据覆盖摘要、脱敏观察报告和需关注信号说明；这些字段只输出聚合/解释性文本，不展示原始对话句子。
- CareDashboard UI 在 header 展示数据覆盖和观测窗口，在指标区展示观测天数，并新增“脱敏观察报告”卡片，作为阶段1“脱敏健康周报/趋势提示”的本机雏形。
- 新增 `RoadshowDemoSeed`，支持 `--seed-roadshow-demo` / `DREAMJOURNEY_SEED=roadshow_demo`、`--reset-roadshow-demo` / `DREAMJOURNEY_RESET_DEMO=1`、`--roadshow-offline-mode` / `DREAMJOURNEY_ROADSHOW_OFFLINE=1`。
- App 启动时接入路演 seed：自动登录路演测试账号，写入路演家庭成员、时空信箱 delivered 信件、记忆档案馆文本/照片 mock analysis、KBLite graph 和 CareDashboard 可用的 familyCircle 对话转录。
- Roadshow offline mode 接入默认兜底：`DialogEngineFactory` 在 offline 参数/env 下返回 `MockDialogEngine`；`DeepSeekSafetyGuarding` 在 offline 参数/env 下优先使用 mock allow guard，不调用已配置的真实 guard endpoint。
- 新增 `Scripts/RoadshowDemoVerify/main.swift`，覆盖 seed 包完整性、launch 参数/env 解析、成员级可见性、CareDashboard 非空信号、五段路演步骤、KBLite/分享包文案和边界文案。
- 新增 `docs/superpowers/reports/2026-06-11-roadshow-demo-cut.md`，沉淀真机前置条件、启动参数、demo seed 规格、12 步路演脚本、手动验收 checklist、失败兜底矩阵和产品边界文案。
- 新增 `Scripts/roadshow_device_smoke_preflight.sh` 和 `docs/superpowers/reports/2026-06-11-roadshow-device-smoke-preflight.md`，自动检查物理 iOS 设备、关键 build settings、iPhoneOS build gate 和真机手动 smoke 步骤；当前机器未连接真机，脚本以 `PASS_WITH_CONCERNS` 记录。

## 最新验证

执行：

```bash
bash Scripts/verify_phase2.sh
```

结果：

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`，覆盖 mailbox scope 持久化和旧信件默认 localOnly 迁移。
- `MemoryArchive verification passed`，覆盖 archive scope 持久化、旧数据迁移、generation photo pending、family photo 不远端分析。
- `CareDashboard verification passed`，覆盖成员级可见性输入过滤：目标成员只能看到 all-family 和显式授权给自己的 familyCircle turns；同时覆盖基于用户发言的观测窗口、数据覆盖摘要、脱敏观察报告、风险信号说明和不泄露完整原文。
- `KBLite 验收结果: 32/32 通过`
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `RoadshowDemoSeed verification passed`，覆盖 roadshow seed 包、launch args/env、成员级可见性、CareDashboard 输入和边界文案。
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 14/14 passed`，覆盖真实 HTTP POST `/v1/safety/evaluate`、完整 evaluate URL 与尾斜杠归一化、JSON/Bearer/no_store_raw/no-store 请求边界、无 key 时不发 Authorization、非 2xx/网络错误/解码失败 fail-closed、环境变量和 Info.plist 配置默认 client 走 HTTP transport、mock allow 优先级。
- `PrivacyScope verification passed`，覆盖 `.selectedMembers([])` 不误开放、旧版 `allowedMemberIDs` JSON 可兼容解码为成员限定范围。
- `MemoryPrivacyIntegration verification passed`，覆盖 graph-level sanitized 输出、family/export/widget/backend/care surface 过滤、CareDashboard family-only transcript、成员级 family visibility、selected-member graph 裁剪、DialogMessage memoirGeneration 过滤、summary prompt scope 迁移、mixed-scope 派生降级、跨 scope 禁止合并和 prompt 相关事实过滤。
- `RemoteSafetyGuard verification passed`，覆盖 default fail-closed、env/launch arg mock allow、roadshow offline mock allow、本地 high 阻断。
- `MockDialogEngine simulator typecheck` 通过
- `Scripts/roadshow_device_smoke_preflight.sh --allow-no-device` 通过脚本/build gate 验证；当前无物理 iOS 设备，未执行逐屏 smoke。
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 与服务端联调真实 `/v1/safety/evaluate`：确认响应字段、状态码、鉴权、超时和审计 HMAC 策略，并补充失败注入/端到端 smoke。
2. 决定 export/widget/backend 是否需要新的显式授权 scope，或保持当前默认空输出策略。
3. 接入物理 iPhone 后执行 `Scripts/roadshow_device_smoke_preflight.sh`，再用 reset+seed+offline 参数 Xcode Run，逐屏确认信箱、档案、回忆 mock、关怀看板、分享包，并保存截图/日志。
4. 抽查分享包 JSON：自动断言不含 `localOnly`、信件正文、完整对话原文。
5. 补 Family/CareDashboard 的授权 UI：为记忆/对话选择具体可见成员，并把当前访问者身份接到真实登录亲友身份；现阶段已完成亲友成员行、分享包导出的目标成员入口，以及本机脱敏周报展示。
6. 处理完整 Simulator app build 的 `SpeechEngineToB` slice 阻断，并补普通对话 scope 按钮的 UI 自动化 smoke。
