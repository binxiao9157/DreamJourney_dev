# WI-S1-01-06 KBLite Compatibility Runtime Shadow G0

日期：2026-07-31
范围：`WI-S1-01-06` 的 iOS 兼容 Projection 读取运行时接线

## 本轮完成

1. 新增 `OwnerTruthKBLiteCompatibilityProjectionRuntime`。
   - 仅在 `DJEnableOwnerTruthKBLiteCompatibilityQA` 的 Debug/UIQA 条件下创建并刷新。
   - 复用已有的 typed read envelope、`AccountLease` 围栏和独立
     `owner_truth_kblite_compatibility_v1.json` 缓存。
   - AccountLease 改变、登出、挂起或删除前执行 `unmount()`：取消旧请求语义并删除独立缓存。
2. 将该 runtime 接入 `KnowledgeSyncCoordinator` 的当前账号同步生命周期。
   - 当前账号通过既有 session、owner 和 lease 校验后才挂载。
   - `userDidChange`、账户 teardown 和 lease generation 变化会先卸载。
   - 它不向 `KBLiteManager`、`KnowledgeThreeWayMerge`、`/kb/sync` 或任何 legacy writer 传递结果。
3. 增补 3 个 iOS XCTest 和静态守卫。
   - 挂载只写独立 Projection cache。
   - 账户替换前卸载会清空独立 cache。
   - QA gate 关闭时不发请求。

## 验证

```text
bash Scripts/QA/product-v4/run-ios-owner-truth-kblite-compatibility-gate.sh
```

结果：通过。

- 两个静态检查通过。
- `DreamJourneyTests/OwnerTruthContractsTests` 在 iPhone 17 Simulator 通过。
- `generic/platform=iOS` Debug `build-for-testing` 通过。

## 明确未完成/未声称

- 这不是 legacy KBLite read cutover；旧 `kb_graph` 仍是原有兼容路径。
- 不做 `projectionSource=legacy_compat` fallback，也不以本地 legacy graph 伪造 authority epoch/checkpoint parity。
- 未接入公开 Archive、Echo 或 Stitch 页面；普通用户不可见。
- 未做后端部署、线上 Postgres、真实数据 parity、百万级重建压测或 G2/G3/G4 结论。
- 在后续 `WI-S1-01-09/10` 的真实 legacy inventory、parity 和 cohort Gate 通过前，不得提升为 authority 或退役 legacy writer。
