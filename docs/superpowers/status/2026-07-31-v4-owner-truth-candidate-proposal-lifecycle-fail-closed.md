# Owner Truth：候选建议失效后的确认链路收敛

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / BACKEND_CONTRACT_ALREADY_DEPLOYED`

本轮只收敛正式访谈候选建议的只读状态与确认入口。目标是让已失效、无权限或已被替换的批次不能继续显示旧的确认操作，也不能把旧结果误导为可保存的正式记忆。

没有新增后端路由、迁移、写入、Provider 调用、公开入口或真机结论。

## 当前合同与 iOS 映射

| 后端事实或读取结果 | iOS 状态 | 用户可见行为 |
| --- | --- | --- |
| `candidateProposalState=invalidated` 或 `sourceState=inactive` | `unavailable/contentUnavailable` | 明确提示本次整理内容已失效；不再打开确认页。 |
| 当前聚焦 `reviewBatchID` 不在 inbox 的 `reviewReady` 项中 | `unavailable/contentUnavailable` | 不显示其他批次替代当前批次；不允许重载后误确认。 |
| `403`、`404`、`410` | `unavailable/contentUnavailable` | 不枚举原因、不展示旧内容；仅作为前向兼容的保守失败关闭。 |
| `409` | `unavailable/contextChanged` | 明确提示状态已更新，保留一次手动重新载入。 |
| `release_policy_denied` 或 `ownerTruthCandidateReviewUnavailable` | `unavailable/releasePolicyDisabled` | 保持既有产品策略关闭。 |
| 其他网络或服务错误 | `failed/requestFailed` | 保持既有可恢复失败提示。 |
| `AccountLease` 已替换 | `unavailable/staleAccountLease` | 账户租约优先于网络结果，丢弃过期回调。 |

这里的 `403/404/410` 分类是 iOS 的保守读取策略；当前后端正式失效语义仍以 `200 + invalidated/inactive` 为主，不把不存在的 `410-only` 合同写成已实现能力。

## 已落实的产品边界

1. 聚焦确认 inbox 接收精确 `focusedReviewBatchID`，只展示当前批次的 `reviewReady` 项；其他批次不能混入。
2. 失效或目标批次消失后，确认列表清空且重载按钮关闭；用户不能从旧入口进入详情、确认、修正或 Memory 激活。
3. `409` 仅代表当前上下文需要重新读取，不等同于失效，保留手动重新载入。
4. 自然输入页的“查看整理进度”入口在终态失效时隐藏；上下文变化时改为“重新查看整理状态”。
5. 本轮不改变全屏 Echo、公开 UI、候选提取 worker、候选确认写路径或正式记忆写入路径。

## 验证证据

- 静态守卫通过：
  `Scripts/QA/product-v4/owner-truth-candidate-proposal-status-handoff-check.swift`。
- iOS XCTest 通过：`DreamJourneyTests/OwnerTruthContractsTests`，`161/161`。
  覆盖失效状态、403/404/410、409、策略关闭、普通失败、聚焦批次消失、旧账户租约优先级，以及两条 UIKit 呈现断言。
- Swift 语法解析通过：
  `OwnerTruthContracts.swift`、`MemoryArchiveViewController.swift`。
- 模拟器正向 UIQA 通过：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh`。
  截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-candidate-proposal-review-ready-smoke/20260731-231244/01-owner-truth-interview-candidate-proposal-review-ready-smoke.png`。
  截图确认现有全屏 Echo 未被改动，Sheet 仅显示一个聚焦的待确认条目。
- 无签名通用 iPhoneOS Debug 构建通过：
  `tmp/owner-truth-candidate-lifecycle-generic-ios-build.log`。
- 本轮相关文件 `git diff --check` 通过。

## 未声明范围

- 未执行后端部署、线上 Postgres smoke 或真机验证。
- 未证明候选提取 worker 在生产环境形成 `reviewReady`。
- 未改变公开发布策略；候选确认仍遵循既有独立 feature/release policy。
- 全局 release regression 仍会被无关的 C00 inventory 基线差异提前停止（manifest 为 38 migrations/106 routes，当前干净后端为 70 migrations/148 routes）；本轮没有重标该基线。
