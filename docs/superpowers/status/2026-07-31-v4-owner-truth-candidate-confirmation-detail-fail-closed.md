# Owner Truth：候选确认详情的陈旧操作失效保护

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / BACKEND_CONTRACT_ALREADY_DEPLOYED`

本轮补齐候选建议确认详情在异步操作期间的 fail-closed 边界。此前候选建议状态页和聚焦确认 inbox 已能在批次失效时收敛；本轮确保用户已经进入详情后，旧批次的异步回调也不能重新显示或操作旧候选。

没有新增后端路由、迁移、写入、Provider 调用、公开入口或真机结论。

## 已落实的保护

1. 确认详情为每次载入的候选批次生成独立 generation；旧 batch/single action 回调只能影响仍绑定的当前详情。
2. 提交或回读期间，刷新按钮、候选列表和批量确认按钮均不可操作，不能在提交中刷新后让旧回调覆盖新详情。
3. `ownerTruthCandidateSourceInactive`、`403/404/410` 与既有终态失效仍保持保守关闭：详情清空并重新读取，后续读取仍以正式后端结果为准。
4. `responseMismatch` 与 `reconciliationFailed` 代表结果无法可靠核对，不再重新开放旧候选；详情立即清空并重新读取。
5. 普通可恢复请求失败仍保留既有重试语义；只有候选内容、结果版本或回读一致性无法确认时才强制清空。
6. 新详情已配置后，旧 action use case 的回调会被 generation 丢弃，不会再次触发刷新、清空或写入界面状态。

## 后端合同边界

| 场景 | iOS 处理 |
| --- | --- |
| 来源已失效 / `ownerTruthCandidateSourceInactive` | 清空旧详情，重新读取；若后端继续返回终态则保持不可确认。 |
| 泛化 `409` | 视为上下文变化，清空旧详情并重新读取。 |
| action 回执与预期候选不一致 | 不复用旧详情，重新读取。 |
| 回读确认结果不能证明本次操作已收敛 | 不复用旧详情，重新读取。 |
| 网络或服务暂时失败 | 保留当前合法详情和可恢复提示。 |

`403/404/410` 是 iOS 前向兼容的保守读取分类；当前后端的正式来源失效事实仍以既有状态/错误合同为准，本轮没有伪造新的后端 `410` 语义。

## 验证证据

- 静态守卫通过：
  `Scripts/QA/product-v4/owner-truth-candidate-proposal-status-handoff-check.swift`。
  该守卫覆盖 generation、操作中刷新锁、旧候选交互锁、终态/上下文失效与结果核对失败后的重读路径。
- iOS XCTest 通过：`DreamJourneyTests/OwnerTruthContractsTests`，`169/169`。
  包含来源失效、终态读取、`409`、batch/single action 的来源失效与回读失效合同，以及确认提交瞬间的刷新锁与结果不一致/回读不一致后的详情清空时序。
- Swift 语法解析通过：
  `OwnerTruthContracts.swift`、`MemoryArchiveViewController.swift`。
- 模拟器正向 UIQA 通过：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh`。
  截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-candidate-proposal-review-ready-smoke/20260731-234554/01-owner-truth-interview-candidate-proposal-review-ready-smoke.png`。
  截图确认既有全屏回响背景与确认抽屉未被改动，且只显示聚焦批次。
- 无签名通用 iPhoneOS Debug 构建通过：
  `tmp/owner-truth-confirmation-detail-fail-closed-generic-ios-build.log`。
- 本轮白名单文件的 `git diff --check` 通过。

## 未声明范围

- 未新增或修改后端来源失效、确认写入、候选提取、正式记忆写入或 Projection worker 合同。
- 未执行隔离 Postgres、线上部署、全局 release regression 或真机验证。
- 全局 release regression 仍会被无关的 C00 inventory 基线差异提前停止（manifest 为 38 migrations/106 routes，当前干净后端为 70 migrations/148 routes）；本轮没有重标该基线。
