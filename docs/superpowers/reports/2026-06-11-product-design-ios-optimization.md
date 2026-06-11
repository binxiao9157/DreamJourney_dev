# Product Design + Build iOS 优化记录

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

目标：使用 Product Design 和 Build iOS Apps 两个插件，对当前阶段2路演闭环做一次面向阶段1产品目标的设计审计、iOS 实现优化和验证收口。

## 审计范围

- 首页 AIRecording 路演入口状态可见性。
- Roadshow seed/reset/offline 参数与用户可感知反馈。
- 阶段1“记忆陪伴、隐私边界、亲友关怀、可路演 demo”的产品契合度。
- iPhoneOS build gate、阶段2脚本验证和真机 smoke 前置条件。

## 当前限制

- 当前机器没有连接物理 iPhone/iPad，无法完成真实设备逐屏 smoke、截图留档和 VoiceOver 实测。
- iOS Simulator 列表可见，但没有 booted 设备；完整 simulator app build 仍受 `SpeechEngineToB` simulator slice 风险影响，本轮没有把截图审计建立在 Simulator 上。
- Product Design 本地没有已保存用户上下文，审计基于当前代码、docs 文档、阶段1/阶段2目标和本轮构建结果。

## Product Design 发现

### 优势

- Roadshow Demo Cut 已经具备 seed/reset/offline 的完整启动契约，适合把分散功能串成固定演示路线。
- 隐私边界文案已经明确“不复活、不诊断、不展示私密原文”，与阶段1产品伦理边界一致。
- 关怀看板、KBLite 分享包、时空信箱、记忆档案馆和 mock 对话已经覆盖阶段1主叙事。

### 主要缺口

- 路演模式在 UI 上不可见：启动参数生效后，用户和演示者没有一个稳定的第一屏信号确认当前处于 seed/offline/demo 状态。
- 失败兜底边界主要存在于文档和脚本中，第一屏缺少“这是本机演示，不调用外部服务”的即时解释。
- 距离可路演 demo 仍缺真机逐屏截图、计时走查和分享包 JSON 抽查证据。

## 本轮实现

### 1. 首页路演状态 Banner

新增 `RoadshowModeBannerView`，在首页标题与消息流之间展示路演状态。仅当满足任一条件时出现：

- `--seed-roadshow-demo` 或 `DREAMJOURNEY_SEED=roadshow_demo`
- `--reset-roadshow-demo` 或 `DREAMJOURNEY_RESET_DEMO=1/true`
- `--roadshow-offline-mode` 或 `DREAMJOURNEY_ROADSHOW_OFFLINE=1/true`
- 本机已经存在 roadshow seeded 标记

Banner 文案区分普通 seed 与 offline mode：

- offline：强调使用 seed 数据、mock 对话和 mock 安全兜底。
- seed：强调固定家庭、信箱、档案、看板和分享包数据已准备。

### 2. RuntimeStatus 服务化

`RoadshowDemoSeed` 新增 `RuntimeStatus` 和 `runtimeStatus(...)`，把 launch 参数、环境变量、UserDefaults seeded/offline 标记统一为可测试状态模型，避免 UI 层重复解析参数。

### 3. 可访问性与布局

- Banner 使用现有暖色视觉体系，避免引入新的视觉语言。
- Banner 提供 `accessibilityLabel`，让读屏能读出路演状态和边界说明。
- 普通模式下 Banner 高度为 0 且隐藏，保持首页原有布局节奏。

## Build iOS 结果

本轮使用 Build iOS Apps 的会话检查能力确认：

- 当前 XcodeBuildMCP session defaults 为空，本轮没有依赖隐式默认配置。
- 当前 iOS 26.5 Simulator 均未启动；未强行启动 Simulator 做不稳定截图验证。

本轮 shell 构建验证：

- `bash Scripts/verify_phase2.sh`：exit 0
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build：`** BUILD SUCCEEDED **`
- `RoadshowDemoSeed verification passed`
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 14/14 passed`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `RemoteSafetyGuard verification passed`

真机 smoke 前置验证：

- `bash Scripts/roadshow_device_smoke_preflight.sh --allow-no-device`：exit 0
- 结果：`PASS_WITH_CONCERNS`
- 原因：脚本和 iPhoneOS build gate 通过，但当前未连接物理 iOS 设备，尚未执行逐屏真机 smoke。

## 当前完成度判断

| 项目 | 完成度 | 说明 |
| --- | ---: | --- |
| 路演数据闭环 | 85% | seed/reset/offline、mock 对话、mock safety、演示脚本、preflight 和首页状态可视化已闭合。 |
| 阶段1产品契合度 | 82% | 核心叙事已能串起“记忆、陪伴、亲友关怀、隐私边界”，但仍缺真实设备逐屏证据和现场节奏打磨。 |
| 真机测试准备度 | 70% | iPhoneOS build gate 通过，脚本和启动契约清晰；卡点是物理设备、签名 Team、截图/日志留档。 |
| 路演 demo 准备度 | 75% | 可按固定路线演示，且第一屏能识别路演模式；仍需真机跑通、分享包抽查和 8-10 分钟计时演练。 |

## 下一步建议

1. 连接物理 iPhone，配置 Xcode Team，使用 `--reset-roadshow-demo --seed-roadshow-demo --roadshow-offline-mode` 真机运行。
2. 逐屏保存首页 Banner、信箱、档案、语音 mock、关怀看板、KBLite 分享包截图和控制台 `[RoadshowDemo]` 日志。
3. 自动或手动抽查分享包 JSON，确认不含 `localOnly`、完整私密原文、未授权成员内容。
4. 做一轮 8-10 分钟路演计时走查，把卡顿点回填到 `2026-06-11-roadshow-demo-cut.md`。
5. 后续若要提升 demo 质感，可补一个“路演路线检查清单”入口，把 5 个阶段1主场景按顺序呈现给演示者。
