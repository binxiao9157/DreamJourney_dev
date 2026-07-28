# WI-V0-01-11 G0 Local: Voice/Digital Human Exit Readiness Evidence

日期：2026-07-28

Work Item：`WI-V0-01-11`

## 本轮范围

iOS 提交 `9f7c90b` 为 Echo 的 QA-only runtime diagnostics 和导出证据包追加
VoiceProfile 退出边界。它只回答“当前角色选中的音色，是否能由当前账号作用域下的本地
快照解析到退出状态”，不把本地状态、Provider 状态或真机体验混为一谈。

新增字段：

- `voiceProfileExitEvidenceState`：`notSelected`、`localResolved` 或
  `unresolved`。
- `voiceProfileExitState`、`voiceProfileAccessRevoked`。
- `voiceProfileLocalCleanupState`、`voiceProfileProviderCleanupState`。
- `voiceProfileProviderCleanupReceiptAvailable`。

解析规则：

1. 当前角色未选择复刻音色时为 `notSelected`，退出字段为空。
2. 角色选择的 profile 与当前账号/角色的 `VoiceCloneProfileSnapshot` 精确匹配时，
   才为 `localResolved` 并导出本地退出状态。
3. profile 不匹配、账号状态不可解析或本地快照无法证明归属时为 `unresolved`，
   不推断任何清理结果。

Echo QA 面板和导出包仅显示经 allowlist 的状态码、布尔值和既有 profile 哈希；不新增
公开 UI、Provider 调用、音频播放、数字人 session、删除请求或持久化 receipt。
`localResolved` 仅表示本地快照匹配，绝不表示第三方清理、Provider delete 或外部验收
已经完成。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/product-v4/run-ios-voice-dh-readiness-evidence-gate.sh
python3 Scripts/QA/product-v4/product-v4-ios-audio-owner-lease-check.py
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

结果：Voice/DH 退出披露 gate、退出 readiness evidence gate、audio owner lease
静态检查、handoff 检查和 workspace 通用模拟器构建均通过。

## 仍然开放的门

- `G1`：没有以删除/禁用 profile 的交互场景完成模拟器截图验收。
- `G2`：没有 durable exit command、outbox、receipt ledger、对象/缓存/腾讯
  session cleanup reconciler。
- `G3`：没有火山或腾讯真实 disable/delete/query、质量、成本或清理回执。
- `G4`：没有真机、产品、隐私/法务和运营验收。

因此 `WI-V0-01-11` 仍是局部 `INTERNAL_READY` 证据增强，不能升级为
`VERIFIED`，也不能据此放开 Voice 或 Digital Human。
