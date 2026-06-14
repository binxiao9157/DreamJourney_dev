# 阶段一真机验收任务账本 - 2026-06-14

目标：把后续推进从“反复建议下一步”改成可收敛的验收账本。状态分为：

- 已封板：不再作为开发任务反复加入；只在全量验证或真机复测中回归。
- 开发中：仍有明确代码缺口，本轮优先推进。
- 待真机验收：代码链路已具备，需要真实设备、真实账号或真实后端证据。
- 待外部条件：需要服务端配置、第三方 key、真机操作或产品确认。

## 已封板，只回归验证

| 任务 | 当前状态 | 回归证据 |
| --- | --- | --- |
| 数字人冷启动明显切换 | 已封板 | `Scripts/DigitalHumanStartupRevealVerify/main.py`、`Scripts/DigitalHumanAssetVerify/verify_avatar_assets.py`、`Scripts/verify_phase1.sh` 的 iPhoneOS 构建。后续只在真机看到新现象时重开。 |
| 路演/演示 UI 从真实模式移除 | 已封板 | `Scripts/RealDeviceRuntimeGateVerify/main.py`、`Scripts/RealDeviceNoDemoStateVerify/main.py`、`Scripts/RealDeviceNoDemoStateTokensVerify/main.py`。 |
| 足迹页去掉城市/全国/世界层级选择，默认城市点亮 | 已封板 | `Scripts/FamilyFootprintIlluminationPolicyVerify/main.py`、`Scripts/RealDeviceRuntimeGateVerify/main.py`。后续只做真机视觉回归，不再重复改模式结构。 |
| 结构化知识库过滤路演/泛称残留 | 已封板 | `Scripts/KBLiteImportSanitizerVerify/main.swift`、`Scripts/KBLitePromptGraphSanitizationVerify/main.py`、`Scripts/RealDeviceNoDemoStateTokensVerify/main.py`。 |

## 开发中，优先推进

| 优先级 | 任务 | 完成口径 |
| --- | --- | --- |
| P0 | 记忆档案馆真实素材建库稳定性 | 文本、照片、截图 OCR、语音转写、声纹样本的成功/失败路径都不使用 mock，不泄露底层错误，保存后能看到来源证据。 |
| P0 | KBLite 与数字人对话记忆约束 | 数字人回复优先引用授权记忆；没有证据时明确不编造。结构化知识库可追踪来源。 |
| P1 | 长辈关怀看板跨设备验收 | 两台真机完成邀请、接受、撤回；撤回后服务端拒绝历史快照读取。 |
| P1 | 时空信箱真实信件验收 | 本机保存正文，后端只同步 metadata；回声只使用授权记忆，含边界声明。 |
| P2 | 真机证据报告 | 汇总截图、录屏、后端脱敏响应、验证日志，形成阶段一验收包。 |

## 待真机验收

| 任务 | 真机步骤 |
| --- | --- |
| 数字人 3-5 轮稳定对话 | 冷启动后连续语音对话，检查不抢话、有声音、口型停随音频、结束后记忆沉淀。 |
| 记忆档案馆真实照片分析 | 导入真实照片，优先走 `DreamJourneyBackendBaseURL` 的图片分析代理；失败时只显示可重试，不生成 mock 分析。 |
| 语音样本与声纹档案 | 导入同一具体人物 3 段语音，确认进入 `readyForTraining`；训练失败显示友好文案，成功后人物音色可被数字人 TTS 选择。 |
| 关怀看板周报 | 使用亲友范围完成多轮真实对话，确认看板只展示脱敏趋势，不展示原始 transcript。 |
| 时空信箱延迟投递 | 创建 1 分钟后投递信件，确认通知不暴露收件人和正文，阅读页正文仍只在本机。 |

## 待外部条件

| 条件 | 影响 |
| --- | --- |
| 线上后端长期可用与 HTTPS 域名 | 跨设备、图片分析代理、KBLite 快照恢复和关怀历史需要稳定服务。 |
| DeepSeek 图片分析 key 在服务器配置 | 旧照片真实分析需要服务端持有 key；未配置时只能保存素材并提示稍后重试。 |
| 两台真机或一个真机加可用第二账号 | 亲友邀请、撤回、跨设备关怀看板需要真实账号链路验收。 |

## 当前推进规则

1. 已封板任务不再进入开发 backlog，只保留自动验证和真机回归。
2. 真机新截图如果证明已封板任务仍有新问题，才重新打开，并记录为新缺陷而不是重复任务。
3. 每个代码任务必须有红灯校验、绿灯验证、全量 `Scripts/verify_phase1.sh` 或明确的局部验收命令。
4. 每次提交后优先推进 P0 记忆档案馆和 KBLite 约束，直到真实素材建库可稳定验收。
