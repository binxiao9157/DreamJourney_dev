# WI-V0-01-08 G0：腾讯数字人 Session 生命周期预检

日期：2026-07-28
Work Item：`WI-V0-01-08`

## 本轮范围

后端提交 `39a963b` 新增默认关闭的
`digital_human_session_lifecycle_shadow`。它把未来的腾讯数智人 asset/session
生命周期与当前旧 lease 明确分开：

- 只接受内部 asset registry ID、项目引用哈希、owner/role/runtime generation、purpose
  和短 lease metadata；不接受 Provider session ID 或 credential；
- 只有 backend registry 中 active asset 才能成为 G0 future candidate；本地 QA asset
  override、撤销或未知 asset 都会清理 runtime 并回文字；
- 旧 generation、同 generation asset switch、重复 command 和迟到 heartbeat 都被围栏；
- open、heartbeat、close、reconcile 全部保留为 blocked/unknown：不把本地 lease 当作
  Provider ready、不声称 session 已关闭或 cleanup receipt 已落库；
- G0 仅允许 Owner 本人 role。家庭/第三方 role 不可借此提升数字人 session。

现有 `/digital-human/sessions` 的创建仍是 fail-closed；现有 heartbeat/release 仅维护
legacy 本地 lease。本轮没有修改任何路由、Provider 调用、数据库、iOS UI 或腾讯 SDK。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-digital-human-session-lifecycle-g0-gate.sh
env STORE_BACKEND=memory /tmp/dreamjourney-backend-test-venv/bin/python \
  -m unittest -v tests.test_digital_human_sessions
env STORE_BACKEND=memory /tmp/dreamjourney-backend-test-venv/bin/python \
  -m unittest -v \
  tests.test_safety_integration.SafetyIntegrationTests.test_minor_and_family_voice_or_digital_human_requests_hard_deny_before_provider
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：新增 8 项 lifecycle G0 测试、既有 8 项数字人 session API 测试及未成年人/家庭
高风险拒绝测试通过；完整后端验证通过（1214 项单测及既有 contract gates）。

## 未关闭 Gate

- `G1`：iOS 尚未消费 server-authoritative asset/session receipt；当前 `DigitalHumanSessionContract`
  的 lease 仍只是运行时本地 guard。
- `G2`：无 asset registry、session command/outbox、Provider session ID、heartbeat/close/
  timeout/unknown cleanup receipt 或持久化 reconcile worker。
- `G3`：无腾讯真实 open/heartbeat/close、并发、地区、成本或 cleanup 证据。
- `G4`：无真机首帧、稳定显示、切后台/杀进程后的 session 回收验收。

因此本项仅是 scoped G0。未推送、未部署，不能把当前 lease 或静态配置报告为腾讯数智人
session 已建立或已释放。
