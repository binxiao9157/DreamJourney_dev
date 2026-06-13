# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 82% | 合约和 iOS client 已固化；DeepSeek chat/knowledge/image、Memoir、TTS 入口默认 fail-closed，支持显式 mock allow 演示开关，并已接入真实 `/v1/safety/evaluate` HTTP transport 最小闭环。 |
| Privacy Scope 模型 | 95% | `ConversationTurn`、`Stage1MailboxMemoryInput`、`DialogMessage`、MemoryArchive、TimeMailbox、KBLite v2 实体已携带 `privacyMetadata`；`FamilyMemberVisibility` 已区分 all-family 与 selected-members，普通对话/档案/信箱采集 UI 已能选择全体亲友或具体成员，旧数据继续兼容迁移。 |
| KBLite/Export/Widget 过滤 | 78% | KBLite remote extraction、prompt context、JSON export、Widget App Group、PDF 输入图谱、backend sync 已按 scope 过滤；familySync/careDashboard graph 支持按目标家庭成员二次裁剪。 |
| CareDashboard/Family Sync 阶段2 | 87% | Family share package、FamilyRepository 已改用 familyCircle sanitized graph；CareDashboard transcript 入口按 `.careDashboard` 和目标成员可见性过滤；亲友成员行可进入成员视角看板，KBSync 导出和普通对话/档案/信箱采集均可显式选择全体或单个成员目标；新增本机登录用户到家庭成员身份解析层，看板默认可按当前访问者过滤；邀请手机号接受和成员访问撤回已接入本机演示 UI；关怀看板新增 7 天脱敏趋势条和可分享的脱敏周报，只输出聚合指标、观察摘要、趋势、建议和边界声明，不导出原始对话。真实云端账号/持久化/同步仍待接入。 |
| Roadshow Demo Cut 闭环 | 99% | 已补路演 seed、reset、offline launch 参数，App 启动自动注入演示家庭成员/信箱/档案/照片 mock analysis/KBLite graph/多日关怀转录；offline 参数已驱动 mock dialog 和 mock safety；首页路演入口已改为用户可理解的“演示向导”，显示 6 步进度、下一步名称、“下一步/清单”入口和边界说明，不再在首屏暴露“路演模式/兜底”等工程词；AppIcon 已替换为全新家族树/记忆盒图标，mock 亲友已统一为陈氏家族线；路演路线页每段可直达对应演示面，支持复制验收清单、清空验收状态、App 内证据中心执行卡和复制证据清单，并将每段绑定到固定截图证据文件；证据中心已按现场采集、诊断复制、导出样本、隐私抽查、脚本生成分类，并解释 `needs_preflight`、`needs_privacy_review`、`needs_manual_evidence`、`complete` 状态，同时展示检查命令、最终 `--archive` 归档命令和 `archive_inventory.json` 校验清单说明；分享包步骤可直接进入导出对象选择；足迹页在路演/无 AMap key/地图加载失败时会显示“家族足迹点亮预览”，海报新增点亮区域、到过城市、迁徙路线图例；路演真机 preflight 已能生成 evidence manifest、截图/录屏/分享包/数字人播放日志/状态键/路线验收模板脚手架，自动抽取 6 段 route completion preferences，并自动生成 `evidence_status.json/md` 缺失项报告、Roadshow Readiness、按优先级排序的 `nextActions`、按阶段归组的 `Stage Evidence`、截图/录屏格式、路线完成/路线复制验收/播放日志/分享包 `Quality Review`、从完整 console 提取数字人播放日志和执行三链路严格审计的命令，以及 `Archive Package` 一键归档入口；路线验收清单必须粘贴 App 内真实 6/6 结果，不能保留模板占位；evidence 文本证据隐私扫描命中 token/key/secret 时进入 `needs_privacy_review` 且不回显原值；真机 iPhone 17 已完成签名、安装、roadshow 参数启动和容器数据抽查，且已自动同步数字人 readiness txt/json；下一步是触发数字人真实播放、逐屏 UI smoke、截图留档和现场计时演练。 |
| 数字人对话稳态 | 92% | 已接入 DHLiveMini 本地资源、manifest 校验、Chat final 触发数字人 WAV TTS、WebView 音频健康事件；已补系统 TTS 兜底、WebView 失败处理、播放 watchdog、错误/后台/安全事件统一清理和结构化日志；本轮新增数字人故障友好提示卡、重试数字人、继续语音动作、App 内“数字人真机诊断”、逐项修复建议、音频链路验收卡和诊断 JSON 证据，避免真机路演时暴露底层错误或密钥；timeout 自动收尾后会保留本轮回答文本，点击“重试数字人”可重新合成当前回答；诊断文本/JSON 已包含 `web_audio`、`system_tts`、`timeout` 三种日志收口口径并自动写入 `Documents/diagnostics/digital_human_readiness.txt/json`；数字人播放事件会自动写入 `Documents/diagnostics/digital_human_playback.log`，preflight 可直接拷贝，控制台 grep 仅作为兜底；新增严格播放审计脚本，要求三类收口样本齐全并对 credential-shaped 日志内容做脱敏失败；数字人资源 manifest/sha256、播放状态 policy、fallback UI、readiness、runtime log、自动落盘证据和 diagnostics UI 已进入阶段2总验证。下一步需要真机确认 WAV 真实出声、口型同步、断网/错音色降级不双播不卡住。 |
| 配置与密钥治理 | 91% | `Info.plist` 已回退为占位符，真实 key 改走 Scheme env 或 ignored `LocalConfig.plist`；AppConfiguration 统一读取 env/LocalConfig/Info.plist，AMap、DeepSeek、VolcEngine、Realtime、Safety Guard 和 OpenAvatar 配置已接入；SecretConfig gate、数字人脱敏诊断 gate 与路演 evidence 隐私扫描 gate 已加入阶段2验证，防止真实 secret 入库、被 UI/复制文本回显，或混入真机日志/诊断 JSON/分享包证据。 |
| 分享包隐私验收 | 96% | 新增独立 `SharePackagePrivacyVerify`、`RoadshowSharePackageVerify`、`RoadshowShareExportUIVerify`、`RoadshowSharePackageSampleVerify` 和 evidence report 分享包质量 gate，用 private/local/generation/family/selected-member sentinel 及真实路演 seed 验证 familySync 分享包：只包含授权 familyCircle 内容、目标成员裁剪正确、跨实体引用被清理、完整包 JSON 不含未授权原文；路演导出 UI 已增加对象选择、隐私收据和系统分享确认；真机导出两个 JSON 后可用 `Scripts/roadshow_share_package_privacy_check.py` 生成 `privacy_check.log`，证据报告会挡住无效 JSON、外层 schema/内层 graphJSON 无效、sentinel 泄漏或未明确 PASS 的真机导出样本。 |

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
- 新增 `FamilyVisibilityPickerViewController`，MemoryArchive 文本/照片和 TimeMailbox 写信在选择“亲友”时可进一步选择“全体亲友”或具体家庭成员；保存后的 `MemoryPrivacyMetadata.familyVisibility` 会进入后续 familySync、CareDashboard 和分享包裁剪链路。
- 普通语音对话首页复用成员选择器：选择“亲友”时可指定全体或具体成员，本轮新增 `HomeDialogPrivacyMetadataFactory` 和 `HomeDialogPrivacyVerify`，保证切回本机/可生成时不会遗留上一次的成员授权。
- 新增 `FamilyAccessIdentityResolver`，可通过本机 override 或当前登录手机号匹配 `FamilyMember.phone` 解析当前访问者身份；CareDashboard 未显式传成员时默认使用该身份过滤。
- 新增 `FamilyAccessControlService`，覆盖邀请手机号接受、已撤回/手机号不匹配拒绝，以及成员权限撤回时将全体亲友授权转换为剩余成员白名单。
- Family 页面新增本机演示级邀请接受和撤回访问入口：手机号匹配后绑定当前访问者身份；成员行支持长按/左滑撤回，已撤回成员不可进入成员视角关怀看板；接受/撤回状态已本机持久化，roadshow reset 会清理演示权限状态。
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
- 新增 `CareDashboardShareReportDescriptor` 和关怀看板分享入口，基于 `CareSignalSnapshot` 生成一页可带走的脱敏关怀周报，包含风险等级、观测窗口、数据覆盖、聚合指标、观察摘要、需关注信号、关怀建议和“不包含原始聊天内容/不是医疗诊断”边界声明。
- `CareSignalSnapshot` 新增 `dailyTrend` 和 `trendSummary`，按最近 7 天活跃日期聚合情绪/睡眠/身体/重复信号；CareDashboard UI 新增“7天趋势”条形摘要，分享周报同步输出“趋势观察”，仍不携带任何原始句子。
- 新增 `RoadshowDemoSeed`，支持 `--seed-roadshow-demo` / `DREAMJOURNEY_SEED=roadshow_demo`、`--reset-roadshow-demo` / `DREAMJOURNEY_RESET_DEMO=1`、`--roadshow-offline-mode` / `DREAMJOURNEY_ROADSHOW_OFFLINE=1`。
- App 启动时接入路演 seed：自动登录路演测试账号，写入路演家庭成员、时空信箱 delivered 信件、记忆档案馆文本/照片 mock analysis、KBLite graph 和 CareDashboard 可用的多日 familyCircle 对话转录，确保关怀看板可展示 7 天趋势与脱敏周报。
- Roadshow offline mode 接入默认兜底：`DialogEngineFactory` 在 offline 参数/env 下返回 `MockDialogEngine`；`DeepSeekSafetyGuarding` 在 offline 参数/env 下优先使用 mock allow guard，不调用已配置的真实 guard endpoint。
- 新增 `Scripts/RoadshowDemoVerify/main.swift`，覆盖 seed 包完整性、launch 参数/env 解析、成员级可见性、CareDashboard 非空信号、五段路演步骤、KBLite/分享包文案和边界文案。
- 新增 `docs/superpowers/reports/2026-06-11-roadshow-demo-cut.md`，沉淀真机前置条件、启动参数、demo seed 规格、12 步路演脚本、手动验收 checklist、失败兜底矩阵和产品边界文案。
- 新增 `Scripts/roadshow_device_smoke_preflight.sh` 和 `docs/superpowers/reports/2026-06-11-roadshow-device-smoke-preflight.md`，自动检查物理 iOS 设备、关键 build settings、iPhoneOS build gate 和真机手动 smoke 步骤；当前机器未连接真机，脚本以 `PASS_WITH_CONCERNS` 记录。
- 新增 `RoadshowModeBannerView`，首页在 seed/reset/offline/已 seed 状态下显示路演模式 Banner，明确本机演示、mock 对话、mock 安全兜底和“不复活/不诊断/不展示私密原文”的边界。
- `RoadshowDemoSeed` 新增 `RuntimeStatus` 与 `runtimeStatus(...)`，统一 launch args、env 和 UserDefaults seeded/offline 标记，供 UI 和脚本验证复用。
- 新增 `docs/superpowers/reports/2026-06-11-product-design-ios-optimization.md`，记录 Product Design 审计、Build iOS 插件检查、本轮设计优化、验证证据和真机/路演剩余缺口。
- 替换全部 AppIcon PNG，不再沿用旧圆环图标；新图标为家族树/记忆盒方向，全部尺寸匹配且无 alpha 通道。
- Roadshow mock 亲友统一为陈氏家族线：`陈岚`、`陈浩`、`陈予`，并同步信箱、档案、KBLite 人物、亲友 mock 与路演文档。
- 新增 `AppConfiguration`，统一配置读取顺序为 Scheme env、ignored `LocalConfig.plist`、`Info.plist` placeholder fallback；AMap、DeepSeek、VolcEngine、Realtime Dialog、Safety Guard、OpenAvatar 均已迁移。
- 新增 `Scripts/SecretConfigVerify/main.py`，检查敏感 key 不以真实值进入 `Info.plist`，并确认 `LocalConfig.plist` 被 git ignore 且未被跟踪。
- 首页路演入口改为“演示向导”卡片，采用上下布局防止按钮压住文案，展示 6 步完成进度、下一步名称和本机素材/隐私边界；主按钮改为“下一步”，辅助按钮改为“清单”。`RoadshowDemoRouteViewController` 提供 6 段主持清单、口播提示、验收点、边界说明、复制启动参数、复制验收清单和清空验收状态；`RoadshowDemoSeed` 新增家族足迹步骤，验证脚本覆盖 6 阶段完整性。
- 数字人对话新增路演稳态保护：WAV TTS 失败或 WebView 音频失败时走系统 TTS 兜底，播放 watchdog 防止卡“正在讲述”，错误/后台/登出/安全事件会统一停止并行录音和清理数字人音频状态。
- `DigitalHumanAssetVerify` 接入 `Scripts/verify_phase2.sh`，自动校验 avatar manifest、资源 sha256、gzip combined data 结构和 DHLiveMini 资源完整性。
- 新增 `DigitalHumanSpeechPlaybackPolicy` 和 `DigitalHumanPlaybackPolicyVerify`，把 WebView health 事件分类、SDK TTS 忽略规则、watchdog 超时和系统 TTS request id 防串音纳入纯 Swift 回归。
- 首页数字人新增故障恢复卡：WAV 合成失败、WebAudio 解码/播放失败、watchdog timeout 或语音服务异常时展示非技术化说明，提供“重试数字人”和“继续语音”；timeout 自动收尾后仍保留当前回答给重试动作使用，并避免把底层错误原文直接 toast 给用户；新增 `DigitalHumanFallbackUIVerify` 静态 gate。
- 首页新增“数字人真机诊断”入口：可查看当前对话引擎、数字人口型 TTS、实时语音凭证和 OpenAvatar 后端的脱敏状态；复制文本和 JSON 只包含配置状态、认证模式、资源 ID、修复建议和音频链路验收口径，不包含 API Key、Token 或 Secret。新增 `DigitalHumanReadinessVerify` 与 `DigitalHumanDiagnosticsUIVerify`。
- 路演证据中心和 preflight manifest 新增 `diagnostics/digital_human_readiness.txt`、`diagnostics/digital_human_readiness.json`、`diagnostics/digital_human_playback.log`，`evidence_status` 会自动检查诊断证据和播放日志是否补齐；App 内新增数字人诊断与播放证据落盘，自动写入 `Documents/diagnostics/digital_human_readiness.txt/json` 和 `Documents/diagnostics/digital_human_playback.log`，preflight 会尝试直接拷贝，控制台 grep 作为兜底；新增 `Scripts/roadshow_digital_human_playback_audit.py`，可对 evidence 目录严格审计三类数字人播放收口样本，并在日志疑似带出 key/token/secret 时只输出行号和模式。
- 工程 warning 收口：`TGToast` 改用 `connectedScenes` / `UIWindowScene` 获取 key window；`Copy LocalConfig.plist` build phase 增加 output marker；新增 `BuildWarningCleanupVerify` 锁住这两项。
- 新增 `Scripts/SharePackagePrivacyVerify/main.swift` 并接入 `Scripts/verify_phase2.sh`，把全体亲友/单个成员分享包 JSON 的隐私过滤变成自动回归 gate。
- 新增 `Scripts/RoadshowSharePackageVerify/main.swift`，复用路演 seed 成员和家庭同步 sanitizer，验证路演分享包不泄漏私密/本机/生成内容、完整信箱正文和完整对话原文，并覆盖 selected-member 裁剪。
- 路演路线页新增每段“进入”按钮：语音/足迹/亲友/信箱/档案可直达对应 Tab，分享包步骤直达 `KBSyncViewController(autoPresentExportPicker:)`。
- 首页“演示向导”新增“一键下一步”：从 `RoadshowDemoRoute.nextIncompleteStep()` 计算下一阶段并直达对应 Tab；六步全部完成后自动打开路线页复盘/复制验收。
- 路演路线页新增 App 内“证据中心”卡片，展示关键截图/录屏/分享包文件、evidence report 收口命令，并支持复制完整证据清单。
- `KBSyncViewController` 新增路演自动导出对象选择；导出后先展示“分享包隐私收据”，列出导出对象、来源、实体统计、已过滤范围和“不是复活/不是医疗诊断”边界，用户确认后再打开系统分享 JSON。
- 分享包隐私收据从系统 Alert 升级为可滚动自定义页面，小屏下长文案、边界说明和确认按钮保持可读；取消不会继续触发分享。
- 新增 `Scripts/RoadshowHostRouteUIContractVerify/main.py` 并接入 `Scripts/verify_phase2.sh`，锁住首页“演示向导”、下一步/清单入口、无工程词首屏文案、小屏文字缩放、6 段路线 UI、完成状态 key、进度文案和直达按钮。
- 新增 `Scripts/RoadshowShareExportUIVerify/main.py` 并接入 `Scripts/verify_phase2.sh`，静态锁住分享包路演直达、对象选择、隐私收据、sanitized share package API 和系统分享出口。
- 新增 `Scripts/roadshow_share_package_privacy_check.py` 和 `RoadshowSharePackageSampleVerify`：真机导出 `share_packages/all_family.json` 与 `share_packages/selected_member.json` 后，可直接校验外层 schema、内层 `graphJSON`、forbidden sentinel，并生成符合 evidence report 要求的 `share_packages/privacy_check.log`。
- 足迹页新增“家族足迹点亮预览”卡片：路演状态、AMap key 缺失、地图创建失败或地图加载失败时仍能一键预览当前点亮海报；无 `AMapAPIKey` 时跳过 `MAMapView` 创建，海报继续使用当前 scope、代际筛选和 `footprintPoints`，不依赖 AMap 截图、照片库或网络。
- 足迹页新增迁徙故事线：`FamilyFootprintJourneySummary` 会按代际生成路线、年份、城市/国家和“更大的世界”摘要；地图顶部故事卡和足迹海报复用同一摘要，海报地图按时间顺序连线足迹点，并与点亮区域共用同一坐标 bounds；bounds 已纳入 region center 和 overlay coordinates，避免世界/全国视角下点线与区域错位。
- 新增 `Scripts/FamilyFootprintFallbackVerify/main.py` 并接入 `Scripts/verify_phase2.sh`，锁住离线/无 key/加载失败触发条件、地图加载成功后清除失败态、兜底文案和本地 poster renderer 复用。
- 更新 `Scripts/roadshow_device_smoke_preflight.sh` 和 `docs/superpowers/reports/2026-06-11-roadshow-device-smoke-preflight.md`，将真机手动验收收敛成 6 阶段、20 条可执行 checklist。
- `roadshow_device_smoke_preflight.sh` 新增 evidence 目录，保存设备探测、build settings、build log、真机安装/启动/容器抽样结果；无真机时仍以 `PASS_WITH_CONCERNS` 输出下一步 checklist。
- preflight evidence 目录新增 `screens/`、`recordings/`、`share_packages/`、`route_completion/` 脚手架，以及 `evidence_manifest.json`、`expected_screens.txt`、`expected_state_keys.txt`、`route_screen_checklist.md`、`route_completion/route_acceptance_checklist.md`；有真机容器 plist 时会自动导出 `route_completion/route_completion_preferences.txt`，记录 6 段 route completion key；新增 `RoadshowEvidenceScaffoldVerify` 防止 route completion key、路线 step 证据文件和脚手架漂移，并新增 `RoadshowDeviceSmokePreflightVerify` 用 fake `xcrun/xcodebuild` 锁住无设备 blocked、无设备 allowed 和假真机 PASS 三条 preflight dry-run 路径，且确认 console next steps 包含严格播放审计命令。
- 新增 `Scripts/roadshow_evidence_report.py` 和 `RoadshowEvidencePackageVerify`：preflight 结束时生成 `evidence_status.json` / `evidence_status.md`，区分 `needs_preflight`、`needs_privacy_review`、`needs_manual_evidence`、`complete`，并列出缺失截图、录屏、分享包、自动上下文、质量/隐私问题、按路演顺序排序的 `Next Actions` 和可执行归档入口；`Next Actions` 会直接给出数字人严格播放审计和分享包样本隐私检查 CLI；归档前会挡住路线完成状态未全 true、路线复制验收清单仍是模板或缺项、数字人 readiness JSON 无效或缺项、播放日志不闭环、分享包 JSON 无效、外层 schema/内层 graphJSON 无效、sentinel 泄漏或分享包隐私抽查日志未明确 PASS；归档 zip 内置 `archive_inventory.json`，为每个证据文件记录 `sizeBytes` 和 `sha256`。
- 新增 `Scripts/CareDashboardShareReportUIVerify/main.py` 并接入 `Scripts/verify_phase2.sh`，静态锁住关怀周报分享入口、`UIActivityViewController` 分享出口、descriptor 聚合字段来源和原始对话防泄露边界。

## 最新验证

执行：

```bash
bash Scripts/verify_phase2.sh
```

结果：

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`，覆盖 mailbox scope 持久化和旧信件默认 localOnly 迁移；iPhoneOS build 覆盖写信 UI 的成员级亲友范围选择器编译。
- `MemoryArchive verification passed`，覆盖 archive scope 持久化、旧数据迁移、generation photo pending、family photo 不远端分析；iPhoneOS build 覆盖文本/照片采集的成员级亲友范围选择器编译。
- `CareDashboard verification passed`，覆盖成员级可见性输入过滤：目标成员只能看到 all-family 和显式授权给自己的 familyCircle turns；同时覆盖基于用户发言的观测窗口、数据覆盖摘要、7 天脱敏趋势、脱敏观察报告、风险信号说明、脱敏周报生成和不泄露完整原文。
- `CareDashboardShareReportUI verification passed`，覆盖关怀看板右上角分享入口、descriptor plainText 分享、7 天趋势 UI、聚合字段来源和“不包含原始聊天内容/不是医疗诊断”边界。
- `KBLite 验收结果: 32/32 通过`
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `RoadshowDemoSeed verification passed`，覆盖 roadshow seed 包、launch args/env、runtime status、陈氏家族线成员、旧 mock 姓名回归防护、成员级可见性、CareDashboard 输入和边界文案。
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 14/14 passed`，覆盖真实 HTTP POST `/v1/safety/evaluate`、完整 evaluate URL 与尾斜杠归一化、JSON/Bearer/no_store_raw/no-store 请求边界、无 key 时不发 Authorization、非 2xx/网络错误/解码失败 fail-closed、环境变量和 Info.plist 配置默认 client 走 HTTP transport、mock allow 优先级。
- `PrivacyScope verification passed`，覆盖 `.selectedMembers([])` 不误开放、旧版 `allowedMemberIDs` JSON 可兼容解码为成员限定范围。
- `MemoryPrivacyIntegration verification passed`，覆盖 graph-level sanitized 输出、family/export/widget/backend/care surface 过滤、CareDashboard family-only transcript、成员级 family visibility、selected-member graph 裁剪、DialogMessage memoirGeneration 过滤、summary prompt scope 迁移、mixed-scope 派生降级、跨 scope 禁止合并和 prompt 相关事实过滤。
- `RemoteSafetyGuard verification passed`，覆盖 default fail-closed、env/launch arg mock allow、roadshow offline mock allow、本地 high 阻断。
- `MockDialogEngine simulator typecheck` 通过
- `SecretConfig verification passed`，覆盖 `Info.plist` 敏感 key 占位、`LocalConfig.plist` ignored/untracked、仓库 token 形态扫描。
- `RoadshowRoute verification passed`，覆盖 6 段主持清单、家族足迹步骤、边界文案、启动参数、完成状态 key、每段截图证据文件、证据中心 artifact、证据分类摘要、`needs_privacy_review` 状态说明、下一步计算、完成百分比、验收摘要、验收清单文本和重置验收状态。
- `RoadshowHostRouteUIContract verification passed`，覆盖首页“演示向导”下一步/清单入口、无工程词首屏文案、小屏文字缩放、路线页完成按钮、进度换行、证据中心执行卡、收口状态解释、复制验收/证据清单、清空验收状态和直达演示入口。
- `VolcEngineConfig verification passed`、`VolcEngineTTSRequest verification passed`、`VolcEngineRealtimeConfig verification passed`，覆盖新版 API Key、旧式实时三件套、voice type、WAV TTS request 和占位符过滤。
- `SharePackagePrivacy verification passed`，覆盖 familySync 分享包对 private/local/generation 内容的排除、selected-member 目标裁剪、跨引用清理和完整包 JSON sentinel 防泄露。
- `RoadshowSharePackage verification passed`，覆盖真实路演 seed 分享包形态、不泄漏完整信件正文/完整对话原文，以及女儿/儿子 selected-member 裁剪。
- `RoadshowSharePackageSample verification passed`，覆盖真机导出分享包样本 CLI 的 PASS 日志生成、无效 JSON、forbidden sentinel 和 graphJSON 缺字段失败路径。
- `RoadshowShareExportUI verification passed`，覆盖路演分享包直达入口、导出对象选择、可滚动隐私收据、sanitized share package API 和 JSON 分享确认。
- `HomeDialogPrivacy verification passed`，覆盖首页普通对话的 familyCircle 成员授权写入，以及本机/可生成 scope 不携带陈旧成员名单。
- `FamilyAccessIdentity verification passed`，覆盖手机号匹配、override 优先、无登录不解析和无效 override 回退。
- `FamilyAccessControl verification passed`，覆盖邀请手机号绑定、撤回邀请拒绝、成员权限撤回和非亲友 scope 不变。
- `FamilyAccessControlUI verification passed`，覆盖 Family 页面暴露接受邀请/撤回访问入口，并真实调用 `FamilyAccessControlService`。
- `DigitalHumanAsset verification passed`，覆盖 DHLiveMini manifest、视频/wasm/js/贴图资源 sha256 和 combined data 结构。
- `DigitalHumanPlaybackPolicy verification passed`，覆盖 WebAudio 完成/失败/忽略事件、SDK TTS 完成忽略规则、watchdog 上下限、系统 TTS stale callback 防护、友好 fallback 文案和路演音频链路验收日志口径。
- `DigitalHumanFallbackUI verification passed`，覆盖首页数字人故障卡、timeout 后保留当前回答给“重试数字人”、继续语音清理重试缓存、friendly fallback presentation 调用和 raw technical error 不直接 toast。
- `DigitalHumanReadiness verification passed`，覆盖 modern API Key、legacy 三件套、mock/offline、missing 配置、localhost 后端真机风险、修复建议、音频链路验收清单、JSON 证据和 API Key/Token 脱敏。
- `DigitalHumanDiagnosticsUI verification passed`，覆盖首页诊断入口、sheet 展示、音频链路验收卡、复制文本/JSON 脱敏诊断和不展示密钥文案。
- `DigitalHumanRuntimeLog verification passed`，覆盖运行时代码、诊断口径、严格播放审计脚本和 evidence report 质量 gate 对 `wav_synth_success`、`fallback=systemTTS`、`playback_timeout`、`playback_finished source=...` 的一致性，并验证完整三链路样本、缺链路失败、credential-shaped 日志脱敏失败三种情况。
- `BuildWarningCleanup verification passed`，覆盖 Toast keyWindow 迁移、LocalConfig copy output marker 和 preflight 诊断证据提示。
- `FamilyFootprintFallback verification passed`，覆盖足迹页路演/无 key/地图失败时的“家族足迹点亮预览”、无 key 跳过 `MAMapView` 创建、加载成功后清除失败态和 AMap 无关的 poster renderer。
- `FamilyFootprintPoster verification passed`，覆盖足迹海报当前 scope/generation、迁徙路线连线、点亮区域/到过城市/迁徙路线图例、迁徙点线与点亮区域共用坐标 bounds、region center/overlay coordinates 纳入 bounds、QR/导出入口和长文案不尾部省略。
- `RoadshowEvidenceScaffold verification passed`，覆盖 6 段 route completion key、route completion preferences 自动导出、App 内路线证据文件、数字人播放日志证据、preflight evidence manifest 和文件结构一致。
- `RoadshowDeviceSmokePreflight verification passed`，覆盖无真机退出码 2、`--allow-no-device` 的 `PASS_WITH_CONCERNS`、fake 真机 build/install/launch/container 证据、`xctrace` offline 但 `xcodebuild/devicectl` 可用的兜底真机路径、带严格播放审计命令的 `console_capture_next_steps.txt` 和 6 段 route completion preferences 自动导出。
- `RoadshowEvidencePackage verification passed`，覆盖 evidence report 的 JSON/Markdown 输出、缺失项统计、Roadshow Readiness、阶段归组 `Stage Evidence`、优先级 `nextActions`、数字人严格播放审计命令、分享包样本隐私检查命令、截图 PNG/录屏 MP4 格式质量 gate、路线完成状态质量 gate、路线复制验收清单质量 gate、数字人 readiness JSON 结构 gate、数字人播放日志必填项与内容质量 gate、分享包 JSON 有效性、外层 schema、内层 graphJSON 和 forbidden sentinel 质量 gate、分享包隐私抽查日志 PASS gate、文本证据隐私扫描、命中 key/token/secret 时的 `needs_privacy_review` 状态、原值不回显、`Archive Package`、`--archive` zip 生成/拒绝打包、`archive_inventory.json` size/sha256 校验、`--fail-on-missing` 和完整证据状态。
- iPhoneOS Debug build 已覆盖数字人系统 TTS 兜底、watchdog、WebView 失败处理和配置读取迁移的 Swift 编译。
- `Scripts/roadshow_device_smoke_preflight.sh` 在已连接 iPhone 17 / iOS 26.6 上通过，结果为 `PASS`；真机 device build `** BUILD SUCCEEDED **`；App 已安装为 `com.yxj.dreamjourney.app`，并使用 reset+seed+offline 参数启动成功；最新证据目录为 `/tmp/dreamjourney_roadshow_smoke_20260612_220440`；本轮 launch 日志确认启动但未输出 PID；从真机容器抽查到 roadshow seeded/offline/login 标记、陈氏家族线时空信箱、记忆档案馆、CareDashboard transcript、conversation memory 数据和数字人 readiness txt/json。证据报告状态为 `needs_manual_evidence`，完整度 `55%`、已存在 `17/31` 项、隐私命中 `0`；数字人播放日志需触发真实播放后生成。详见 `docs/superpowers/reports/2026-06-11-roadshow-device-validation.md`。
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 真机验证数字人对话：启动首页或打开“数字人真机诊断”后，App 会自动写入 `Documents/diagnostics/digital_human_readiness.txt/json`；正常网络确认 WebAudio WAV 出声和口型同步；断网/错 voice type 确认系统 TTS 兜底有声、不双播、不卡“正在讲述”；完成演练后重跑 preflight 同步 `diagnostics/digital_human_playback.log`，其中应包含 `playback_finished source=web_audio|system_tts|timeout` 中的实际路径，并运行 `python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json` 做三链路严格审计。
2. 逐屏路演 smoke：从首页“清单”进入主持清单，按 6 阶段确认语音陪伴、信箱、档案、足迹、关怀、分享/隐私边界，并截图留档。
3. 真机抽查分享包 JSON：自动 gate 已覆盖路演 seed/sentinel；真机还需保存实际导出样本作为路演证据。
4. 与服务端联调真实 `/v1/safety/evaluate`：确认响应字段、状态码、鉴权、超时和审计 HMAC 策略，并补充失败注入/端到端 smoke。
5. 补真实亲友身份的授权闭环：本机访问者身份解析、邀请手机号接受、成员撤回服务和本机演示 UI 已接入；下一步接真实云端亲友账号、服务端同步、持久化和离线冲突处理。
6. 处理完整 Simulator app build 的 `SpeechEngineToB` slice 阻断，并补普通对话 scope 按钮的 UI 自动化 smoke。
