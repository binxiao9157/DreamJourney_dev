# Owner Truth C05 iOS ViewState Parity G1

## 范围

对应终版路线图 `WI-MIG-01-06 / C05` 的 iOS G1 基础：同一语义 Intent 的 legacy 与 V4 独立读结果可生成只含摘要哈希的 ViewState parity report。该比较器不发网络请求、不写本地或服务端数据、不选择 Authority、不改变当前用户结果。

## 已实现

- `OwnerTruthMigrationParityViewStateSnapshot`：明确 `legacy` 与 `v4` 两个来源，包含语义 route decision、可见性、ViewState phase、缓存状态、authority epoch、citation set、projection checkpoint 与 presentation 摘要。
- `OwnerTruthMigrationParityViewStateComparator`：按 C05 `M01` 到 `M08` 生成稳定 mismatch report。
- `M01` 到 `M07` 始终阻断批准窗口；`M08` 仅限同一 surface、同一 presentation hash pair、带审批引用 hash 与到期时间的处置。
- QA gate 默认关闭，只有 Debug/UIQA 且带 `DJEnableOwnerTruthMigrationParityQA` 时才可调用。
- 当前测试桩同步实现了 `fetchOwnerTruthInterviewNaturalInputCurrentSession`，修复上游协议新增方法后 Swift 包测试无法编译的问题。

## 验证

```bash
Scripts/QA/product-v4/run-ios-owner-truth-migration-parity-view-state-g1-gate.sh
```

该 gate 依次执行：静态边界检查、Swift 包单测、generic iPhoneOS `build-for-testing`。不需要模拟器或真机。

## 不代表已完成的事项

- 这只是 G1 的合约与 synthetic ViewState 比较基础；尚未把真实 legacy/V4 UI adapter 的结果接入 QA cohort。
- 没有真实数据观察窗、Postgres shadow 或批准差异分类，因此不能作为 C05 的 G2 或 cutover 证据。
- 不修改公开 Archive/Echo UI，不开启 V4 Authority，不执行 Provider 或对象存储副作用。

## 下一步

在 `S1-03 adapter shadow` 具备真实 V4 ViewState 后，将它与 legacy compatibility read 接入此比较器，按 QA/internal cohort 运行；再结合 C05 后端 Postgres shadow 形成完整窗口证据。
