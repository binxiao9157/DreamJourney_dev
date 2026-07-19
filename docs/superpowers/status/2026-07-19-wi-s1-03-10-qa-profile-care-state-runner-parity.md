# WI-S1-03-10 Profile 关怀状态 UIQA Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_G1_PARTIAL / PROFILE_CARE_STATE_RUNNER_PARITY_VERIFIED`
- `QAProfileScenarioRunner` 扩展为统一承接 Profile 根导航控制器和根 `ProfileViewController` 的 UIQA 路由；
  `ProfileCareStateSmoke` 不再在 `AppDelegate` 重复查找 Window、Tab 和 Navigation stack。
- 关怀状态结果 JSON 复用 `QAProfileScenarioRunner.writeResult`，结果 schema、状态断言和错误语义不变。
- 修正了旧静态检查对启动参数位置的过时假设：启动参数已由 `FeatureFlagService` 的统一 registry 管理，不应要求
  `AppDelegate` 持有同一字符串。

## 保持不变的合同

1. 启动参数仍为 `DJRunProfileCareStateSmoke`。
2. 结果文件仍为 `profile-care-state-smoke-result.json`。
3. `empty`、`stale`、`failed` 三种本地安全 fallback 及其 `重新同步` 行为保持原有断言。
4. 公开 Profile 页面、关怀数据模型、后端请求和发布态功能开关均未改变。
5. 该 smoke 改为复用 `run-installable-simulator-uiqa.sh`，强制使用本机 QA Bundle ID
   `com.yxj.dreamjourney.app` 和 Team ID `2BTR77V3R8`。

## 验证

```bash
bash -n Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh
swift Scripts/QA/prd-stitch-ui/profile-care-state-smoke-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift "$PWD"
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh
git diff --check
```

结果：通过。

- 安装日志：`Local QA bundle id: com.yxj.dreamjourney.app`、`Local QA team id: 2BTR77V3R8`。
- Runtime result：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/20260719-125440/profile-care-state-smoke-result.json`
- 截图：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/20260719-125440/01-profile-care-state-smoke.png`
- 结果中 `completed=true`、`profileTabSelected=true`，并完整覆盖 `profileCareStateEmpty`、
  `profileCareStateStale`、`profileCareStateFailed`。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-PROFILE-CARE-BACKEND-STATE-RUNNER-PARITY`。

仅复用现有 Profile Runner 收敛后台关怀状态 smoke 的 Profile 根路由、结果写入和受保护模拟器安装；
不改变后端状态合同、重试策略、公开 UI 或 release gate。
