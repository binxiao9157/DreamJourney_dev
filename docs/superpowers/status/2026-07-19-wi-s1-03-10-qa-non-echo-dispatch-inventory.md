# WI-S1-03-10 非 Echo UIQA Dispatch Inventory G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / NON_ECHO_DISPATCH_INVENTORY_VERIFIED`
- 启动场景总数为 `35`。其中 `8` 个已由共享 `QAEchoScenarioRunner` 负责 root/Echo 路由，
  `1` 个需先完成 synthetic identity challenge，`6` 个有确定性本地 seed，`1` 个有
  AccountLease-sensitive 的自定义档案路由，剩余 `19` 个为普通延迟调度场景。
- 本轮只建立了静态分类 guard；没有改变任何 smoke 的登录、seed、重试、路由、结果文件或公开 UI。

## 分类与保留边界

| 类别 | 数量 | 处置 |
| --- | ---: | --- |
| 共享 Echo route | 8 | 继续由 `QAEchoScenarioRunner` 管理 key-window、Tab 和 Echo route。 |
| 先鉴权再 Echo route | 1 | `DigitalHumanRuntimeStubSmoke` 必须先完成 synthetic V2 challenge；不应降级为普通调度。 |
| seed 后再调度 | 3 | `ArchiveFailedAnalysisRetry`、`BackendEnvironment`、`ArchiveToEcho` 仍在 `AppDelegate` 保留确定性 seed。 |
| AccountLease 自定义路由 | 1 | `ArchiveMediaEchoContext` 保留 lease 捕获、清理与重试语义。 |
| 纯 seed | 3 | 三个 archive seed 场景保持同步即时执行，不引入无意义延迟。 |
| 普通延迟调度 | 19 | 后续仅逐个迁移，禁止批量重写 switch。 |

## 下一迁移目标

选择 `GlobalPrivateStoreRetirementSmoke`：

1. 不依赖真实 Provider、登录、Archive seed 或 AccountLease。
2. 自身已有独立 result model、持久化和结果 view，适合作为第一个 non-Echo runner parity。
3. 仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译，不触碰公开 App 的三 Tab 和 Stitch 视觉。

`DigitalHumanRuntimeStubSmoke`、`ArchiveMediaEchoContextSmoke` 与带 Archive seed 的跨 Tab 场景明确不在下一子切片处理，以避免把鉴权或数据准备错误抽象成通用行为。

## 验证

```bash
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
git diff --check
```

结果：通过。

新增的 `qa-non-echo-dispatch-inventory-check.py` 要求每个 `QALaunchScenario` 恰好归类一次，
并守卫下一迁移候选仍为低风险、独立调度的 `GlobalPrivateStoreRetirementSmoke`。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-GLOBAL-PRIVATE-STORE-RUNNER-PARITY`。

只将该独立 smoke 的 result persistence/root presentation 从 `AppDelegate` 迁到 compile-isolated
QA helper；保留 scenario 名称、输出文件名和 UIQA-only 边界。其余非 Echo 场景不在本次迁移。
