# WI-V0-01-10 G1 Local: Voice/DH Exit Disclosure

日期：2026-07-28

Work Item：`WI-V0-01-10`

## 本轮落地

后端提交 `de2d397` 将 VoiceProfile 公共合同升至 `contractVersion=4`，
不改现有 disable/delete 路由的本地生命周期语义，只追加可机器读取的
退出边界：

- 正常 profile：`exitState=active`。
- disable：`exitState=accessRevoked`，本地保留记录，Provider 清理
  `notRequested`。
- delete：`exitState=partial`，本地记录为 `tombstoned`，Provider 清理为
  `unsupported`，且 `providerCleanupReceiptAvailable=false`。

iOS 提交 `95c9e6d` 解析上述字段，并对旧后端版本按 sample status
做保守默认。删除确认、结果反馈和状态卡片只说明“已停止用于回响”，并明确
第三方服务清理尚未接入，不能确认第三方数据是否已删除。

本轮没有调用火山或腾讯的删除接口，没有新增 Provider 任务、持久化 receipt、
外部清理队列、公开发布入口或真实设备行为。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
STORE_BACKEND=memory PYTHONPATH=. \
  /tmp/dreamjourney-backend-test-venv/bin/python -m unittest -v \
  tests.test_core_services.VoiceCloneProfileAPITests
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python scripts/verify_backend.sh

cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/product-v4/run-ios-voice-dh-exit-disclosure-gate.sh
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

结果：VoiceClone API 定向 23 项通过；后端完整验证通过（1220 项主测试及
既有 smoke/gate）；iOS disclosure 静态门禁和 workspace 通用模拟器构建通过。

## 仍然开放的门

- `G1 UIQA`：尚未用模拟器跑删除状态卡片的交互截图。
- `G2`：没有 durable exit command、outbox、receipt ledger、对象/缓存/DH
  session cleanup reconciler。
- `G3`：没有火山/腾讯真实 disable、delete、query 或 backup-retention 回执。
- `G4`：没有真实设备、隐私/法务和用户验收。

因此该项最高状态仍为 `INTERNAL_READY`；任何 UI 都不得把 `partial` 或
`unsupported` 显示为“已完成第三方清理”。本轮未推送、未部署。
