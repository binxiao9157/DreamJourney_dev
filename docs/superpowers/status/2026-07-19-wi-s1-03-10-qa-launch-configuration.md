# WI-S1-03-10 QA Launch Configuration G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / IOS_LOCAL_VERIFIED`
- 本子切片只完成 QA launch argument 的统一 fail-closed 读取边界；没有把整个
  `WI-S1-03-10` 标记为完成。

## 本次范围

1. 在既有的 `FeatureFlagService.swift` 中新增 `QALaunchConfiguration`，作为唯一的
   `ProcessInfo.processInfo.arguments` 读取点。
2. `AppDelegate` 的 UIQA 场景、seed 及 feature flag 启动配置统一改为经该配置读取。
3. `EchoViewController` 的数字人、PCM drive、诊断面板和 keyed QA 参数也改为经该配置读取。
4. 非 `DEBUG` / `UI_QA_SIMULATOR` 构建的配置固定为空：同一 launch argument 不能启用 QA seed、
   smoke、隐藏数字人面板或诊断面板。
5. 保留全部既有 argument 字符串、优先级和场景执行逻辑，避免改变现有 UIQA runner 的调用合同。

## 运行边界

- 该配置不持久化任何 argument，不写入 `UserDefaults`，不提供公开 UI 或 deeplink 入口。
- 生产构建不读取有效 QA 参数；即使外部携带同名参数，也只能得到空配置。
- 本切片没有迁移 `AppDelegate` 内的具体 smoke/seed 执行体，也没有修改三 Tab、Stitch 视觉、
  账号/owner/AuthZ、Voice/Digital Human 业务逻辑。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
python3 Scripts/QA/product-v4/global-private-store-retirement-uiqa-check.py
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py
swift Scripts/QA/prd-stitch-ui/digital-human-live-panel-check.swift
python3 Scripts/QA/product-v4/provider-redaction-boundary-check.py
python3 Scripts/QA/product-v4/product-v4-stage1-roadmap-check.py
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- 新 gate 分别编译 Debug 和非 Debug 配置，证明相同参数在 Debug/UIQA 可解析，在生产语义下
  fail closed。
- 数字人静态检查同步到现有的 redacted correlation diagnostics 和 binding-safe local TTS helper，
  不再要求已退役的原始 request/turn 日志格式。
- Stage 1 路线图检查同步到已提交的 V1.3 M0-M4 header 与当前 package inventory 结构。
- 通用 iPhoneOS `build-for-testing` 成功；既有第三方地图库 warning 未由本切片引入。

## 未关闭 Gate 与后续

- `G0`：仅 QA launch configuration boundary 已验证；scenario registry、seed/export orchestration
  和 AppDelegate/Echo UIQA 执行体尚未迁移。
- `G1`：各 simulator UIQA scenario 的交互/截图回归仍待在逐段迁移后执行。
- `G3/G4`：Voice、Digital Human、APNs 和真机外部门保持原状态，本切片不宣称通过。

下一子切片：`WI-S1-03-10-G0-SCENARIO-REGISTRY`。先固定启动 scenario 的唯一优先级表和
seed policy，再把 `AppDelegate` 的 if/else 分发逐段替换为 registry 驱动的编排；不得新增公开 QA 入口。
