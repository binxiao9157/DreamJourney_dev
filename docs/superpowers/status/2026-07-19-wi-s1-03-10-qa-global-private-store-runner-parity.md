# WI-S1-03-10 私有存储退役 UIQA Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_G1_PARTIAL / GLOBAL_PRIVATE_STORE_UIQA_RUNNER_PARITY_VERIFIED`
- `GlobalPrivateStoreRetirementSmoke` 的运行、结果 JSON 持久化和临时结果页面展示已从
  `AppDelegate` 移到 `ProductV4GlobalPrivateStoreRetirementUIQASmoke.runAndPresent()`。
- `AppDelegate` 现在只保留 typed scenario 的延迟调度，不再持有该 smoke 的私有存储断言、文件写入或
  root replacement 细节。

## 保持不变的合同

1. 启动参数仍为 `DJRunGlobalPrivateStoreRetirementSmoke`。
2. 结果文件仍为 `global-private-store-retirement-uiqa-result.json`。
3. 结果页面仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 下替换临时 QA root；公开三 Tab、
   Stitch 视觉和生产启动路径不变。
4. A/B 私有存储隔离、stale lease、legacy quarantine 和 reserved fallback writer 的原有断言不变。

## 验证

```bash
python3 Scripts/QA/product-v4/global-private-store-retirement-uiqa-check.py
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
Scripts/QA/product-v4/run-global-private-store-retirement-uiqa-smoke.sh
git diff --check
```

结果：通过。

- Runtime result：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/global-private-store-retirement/20260719-124100/global-private-store-retirement-uiqa-result.json`
- 截图：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/global-private-store-retirement/20260719-124100/01-global-private-store-retirement.png`
- 结果中 `completed=true`，并且 Conversation/Memoir/Memory/Map/Home photo 的 A/B 隔离、stale lease
  拒绝、legacy receipt 和 reserved writer 拒绝均为通过。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-PROFILE-CARE-ESCALATION-RUNNER-PARITY`。

只抽离 `ProfileCareEscalationBoundarySmoke` 的 Profile root/Tab route 与结果写入，先验证其 draft-only
边界；不同时迁移后台失败重试、family persona 或真实关怀数据请求。
