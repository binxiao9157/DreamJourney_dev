# WI-S1-03-10 Profile 关怀升级 UIQA Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_G1_PARTIAL / PROFILE_CARE_ESCALATION_RUNNER_PARITY_VERIFIED`
- `QAProfileScenarioRunner` 现在统一承接 Profile 根 Tab 路由和 UIQA 结果 JSON 写入；
  `AppDelegate` 仅保留兼容包装和 typed scenario 调度。
- `ProfileCareEscalationBoundarySmoke` 的 draft-only 业务断言仍留在原 smoke 调用点，未把关怀、家人或后端业务规则迁入通用 Runner。

## 保持不变的合同

1. 启动参数仍为 `DJRunProfileCareEscalationBoundarySmoke`。
2. 结果文件仍为 `profile-care-escalation-boundary-smoke-result.json`。
3. 关怀升级仍只生成本地人工复核草稿：`deliveryState=draftOnly`、不连接真实联系后端、不联系第三方、不声明紧急服务、不写入原始转写。
4. 公开三 Tab、Stitch 视觉和生产启动路径不变；共用 Runner 仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 下编译。
5. 该 smoke 改为复用 `run-installable-simulator-uiqa.sh`，因此强制使用本机 QA Bundle ID
   `com.yxj.dreamjourney.app` 和 Team ID `2BTR77V3R8`，不再绕过本地身份守卫构建默认包。

## 验证

```bash
bash -n Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift "$PWD"
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh
git diff --check
```

结果：通过。

- 安装日志：`Local QA bundle id: com.yxj.dreamjourney.app`、`Local QA team id: 2BTR77V3R8`。
- Runtime result：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke/20260719-124820/profile-care-escalation-boundary-smoke-result.json`
- 截图：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke/20260719-124820/01-profile-care-escalation-boundary.png`
- 结果中 `completed=true`、`profileTabSelected=true`，并保留所有 draft-only 安全边界。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-PROFILE-CARE-STATE-RUNNER-PARITY`。

仅复用同一 Profile Runner 收敛 `ProfileCareStateSmoke` 的根 Tab 路由、结果写入和受保护模拟器安装；
不修改关怀数据状态、后端请求、公开 UI 或发布策略。
