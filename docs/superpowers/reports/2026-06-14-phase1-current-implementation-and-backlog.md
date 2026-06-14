# 阶段一当前工程实现与待开发清单 - 2026-06-14

基准目标：`docs/阶段一.docx` 的阶段一产品规划。  
当前分支：`feature/phase2-mock-dialog-engine`。  
推进原则：后续不再把已封板任务反复加入开发队列；只基于真机新问题或缺失证据重开缺陷。

## 1. 当前结论

当前工程已经具备阶段一核心链路的真机验收基础，但还不是完整生产闭环。

综合判断：

- App 侧核心模块已从路演模式转向真实测试模式。
- 记忆档案馆、KBLite、数字人对话、时空信箱、关怀看板、后端 metadata sync 都已有可运行实现。
- 主要剩余风险不在“再堆新功能”，而在真实设备、真实账号、真实后端、真实素材的连续验收。
- 后续开发应围绕验收暴露的问题做定点修复，避免重复打磨同一类 UI/体验问题。

## 2. 模块实现状态

| 模块 | 当前状态 | 判断 |
| --- | --- | --- |
| 记忆档案馆建库核心 | 文本、照片、截图 OCR、语音素材、声纹样本、隐私范围、KBLite 入库、后端 metadata sync 已打通。失败路径已避免暴露 OCR、语音识别、声纹训练底层错误。 | 接近真机验收；仍需真实照片/真实语音/声纹训练闭环验证。 |
| KBLite 结构化知识库 | 对话抽取、档案素材入库、信箱元信息入库、sourceRef、旧 demo/泛称清理、多用户生命周期隔离、后端快照恢复已有实现。 | 核心可用；仍需真实数据连续入库和跨设备恢复验证。 |
| 数字人对话记忆约束 | 对话 prompt/RAG 已改为使用 `.prompt` 授权裁剪图谱；无证据时有“不编造/邀请补充”约束。 | 开发侧已封住主要隐私口；仍需真机连续对话验证回复是否真的遵守。 |
| 数字人启动与播放 | 冷启动首帧切换已封板；真人 poster/视频 ready 门禁、系统 TTS 兜底、播放证据日志已有。 | 不再重复开发冷启动；只做真机回归和长轮次稳定性测试。 |
| 时空信箱 | 本机信件、延迟投递、本机通知、边界回声、授权记忆引用、后端 metadata-only 同步、正文/回声不出端已有实现。 | 待真机验证延迟通知、后端响应脱敏、跨设备 metadata 恢复。 |
| 长辈关怀看板 | 脱敏快照、7 天趋势、历史快照、亲友 active/accepted 校验、撤回后 403、原始 transcript 不展示已有实现。 | 待两台真机验证邀请/接受/撤回和周报内容。 |
| 足迹点亮 | 已转为默认城市点亮；城市/全国/世界选择已从真实模式移除；高德行政区点亮和本地兜底已有。 | 已封板，只做真机视觉回归，不再反复改模式结构。 |
| 后端服务 | DreamJourneyBackend 已覆盖 KBLite、档案、信箱、亲友、关怀、图片分析代理、Postgres/InMemory 存储。 | 待服务器线上 smoke、HTTPS、鉴权和长期数据验证。 |
| 安全边界 | 本地 SafetyMonitor、危机干预、脱敏锁、边界提示不进记忆已有。 | 阶段一可先验本地规则；生产化仍需 Safety Guard 后端服务。 |
| 适老终端 B 面 | App 内“一键对话/潜行建库”有基础。 | 独立小程序/音箱形态未实现，阶段一不应继续扩范围。 |

## 3. 已封板任务

以下任务不再进入开发 backlog；只有真机出现新问题时才重开缺陷。

| 任务 | 封板原因 | 回归方式 |
| --- | --- | --- |
| 数字人冷启动明显切换 | 已多轮修复并有启动揭示门禁。 | `Scripts/DigitalHumanStartupRevealVerify/main.py`、真机冷启动录屏。 |
| 路演/演示 UI 清理 | 真实模式门禁已覆盖 seed/mock/route UI。 | `Scripts/RealDeviceRuntimeGateVerify/main.py`、`Scripts/RealDeviceNoDemoStateTokensVerify/main.py`。 |
| 足迹默认城市点亮 | 产品方向已明确，模式结构不再反复切换。 | 真机视觉回归和 `Scripts/FamilyFootprintIlluminationPolicyVerify/main.py`。 |
| 结构化知识库路演/泛称残留过滤 | 已有导入清理和显示裁剪门禁。 | `Scripts/KBLiteImportSanitizerVerify/main.swift`、真实账号清理后复测。 |
| 用户可见底层错误治理首轮 | OCR、语音识别、声纹训练失败路径已改为友好文案。 | 对应 MemoryArchive 验证脚本和真机失败场景复测。 |

## 4. 唯一待开发/待验收任务清单

### P0：记忆档案馆真实素材建库验收

目标：证明真实素材可以进入档案馆、结构化知识库和数字人引用链路。

任务：

1. 真机添加文字素材，选择“可生成”，保存后进入结构化知识库验证人物、地点、事件、事实和来源。
2. 真机导入真实照片，走后端图片分析代理；失败时只允许显示“可重试”，不允许 mock 分析成功。
3. 真机导入语音素材，补转写/摘要，确认语音事实进入知识库。
4. 同一具体人物导入 3 段语音，确认声纹档案进入 `readyForTraining`；训练失败不暴露底层错误，训练成功后 speakerId 不覆盖全局默认音色。
5. 核查后端 `/archive/items/{userId}` 只含 metadata，不含本地路径、图片/音频本体。

完成证据：

- 档案馆截图。
- 结构化知识库截图。
- 后端 archive items 脱敏响应。
- 声纹档案状态截图。
- `Scripts/verify_phase1.sh` 通过日志。

### P0：数字人对话记忆约束真机验收

目标：数字人不是自由发挥，而是优先使用授权记忆；没有证据时不编造。

任务：

1. 先通过档案馆沉淀一条明确人物/地点/事件记忆。
2. 首页用“可生成”隐私范围进行 3-5 轮语音对话。
3. 询问已沉淀事实，观察是否能自然引用。
4. 询问未沉淀事实，观察是否明确“还没有记住这段，可以讲讲吗”，而不是编造。
5. 结束对话后等待 5-10 秒，验证新事实是否进入结构化知识库。

完成证据：

- 对话截图/录屏。
- 结构化知识库更新截图。
- 设备日志中 `DialogMemoryGrounding` / RAG payload 发送记录。

### P1：长辈关怀看板跨设备验收

目标：亲友只能看授权后的脱敏聚合信号，撤回后不能继续看。

任务：

1. A 设备登录主账号，创建亲友邀请。
2. B 设备登录被邀请手机号，通过邀请码或 deeplink 接受。
3. A 设备用“亲友”范围完成多轮真实对话。
4. B 查看关怀看板，确认只有脱敏趋势和周报，无原始 transcript。
5. A 撤回 B 权限。
6. B 再次读取 latest/history，后端应返回 403，App 显示“亲友权限未生效或已撤回”。

完成证据：

- 邀请/接受/撤回截图。
- 关怀看板截图。
- 后端 403 脱敏响应。

### P1：时空信箱真实信件验收

目标：信件正文只在本机，后端只保存 metadata；回声只引用授权记忆。

任务：

1. 先沉淀一条相关人物记忆。
2. 创建给具体姓名的信件，选择“可生成”或“亲友”。
3. 设置 1 分钟后投递，确认本机通知文案不暴露收件人和正文。
4. 打开信件，确认“原信仅本机显示”和“不是逝者真实回复”边界。
5. 查询后端 `/mailbox/letters/{userId}`，确认没有 `body`、`replyText`、`bodyPreview`。
6. 换设备登录同账号，只能恢复 metadata，不应凭空出现正文。

完成证据：

- 投递通知截图。
- 阅读页截图。
- 后端 mailbox letters 脱敏响应。

### P2：线上后端 smoke 与证据报告

目标：把阶段一真机验收从“本地可跑”推进到“服务器可长期测”。

任务：

1. 确认 `DreamJourneyBackendBaseURL` 指向 HTTPS 域名。
2. 跑后端 `/health`、`/config/runtime`、`/archive/image-analysis?dryRun=true`、`/kb/snapshot/{userId}` smoke。
3. 核查服务端 `DEEPSEEK_API_KEY`、`AMapWebServiceKey`、VolcEngine 配置状态。
4. 汇总真机截图、录屏、后端响应、验证日志。
5. 形成阶段一验收证据包。

完成证据：

- 后端 smoke 命令输出。
- 运行时配置脱敏截图。
- 证据包目录或报告。

## 5. 不再重复执行的动作

以下动作只有在明确失败时才做，不作为默认下一步：

- 不再反复改数字人冷启动首帧。
- 不再反复切换足迹城市/全国/世界模式。
- 不再重新引入路演任务引导或 seed UI。
- 不再仅因为看到验证脚本存在就重复跑同一类验证；全量验证只在代码提交前运行。
- 不再为“看起来还能优化”而修改已封板模块。

## 6. 下一次恢复工作时的建议顺序

1. 先做 P0 真机验收，不写新代码。
2. 记录失败现象、截图、日志、后端响应。
3. 只对失败项开缺陷修复。
4. 每个修复必须带红灯验证、绿灯验证、提交、推送。
5. 修复后更新本文件或 `2026-06-14-phase1-acceptance-task-ledger.md`，避免任务重复入列。

## 7. 当前最近验证与提交

最近关键提交：

- `15bbed5 Use prompt-safe graph for dialog grounding`
- `a9209f2 Add phase1 acceptance task ledger`
- `770c6a2 Hide raw voice profile training errors`
- `29a828c Use friendly voice profile training failures`
- `a76e353 Use friendly screenshot OCR failures`

最近全量验证日志：

- `/tmp/dreamjourney_verify_phase1_prompt_archive_snapshot.log`

关键通过项：

- `DialogMemoryGrounding verification passed`
- `DialogRealtimeRAGFinalASR verification passed`
- `DialogMemoryRAGPayload verification passed`
- `KBLitePromptGraphSanitization verification passed`
- `** BUILD SUCCEEDED **`
