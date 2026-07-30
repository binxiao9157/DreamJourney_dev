# WI-S1-01-06 正式记忆 Projection 恢复状态

日期：2026-07-30

## 本轮闭环

补齐了一个真实的恢复可发现性缺口：正式确认的 Candidate 已经激活为
`MemoryVersion`，但兼容 Projection 仍在异步重建或重试时，系统此前会正确地
fail closed，却没有一条正式、可发现的状态读路径。

新增的恢复 inbox 仅在现有 `ownerTruthCandidateReview` 正式发布策略允许、且当前
Owner 会话有效时可读：

`GET /v2/vaults/{vault_id}/interview-memory-projection-recovery-inbox`

响应只允许：

```json
{
  "schemaVersion": "owner-truth-interview-memory-projection-recovery-inbox-v1",
  "vaultId": "...",
  "items": [
    {
      "reviewBatchId": "...",
      "candidateId": "...",
      "state": "rebuilding"
    }
  ]
}
```

不会返回 Candidate 正文、Source、DecisionReceipt、Memory/MemoryVersion ID、worker
job、checkpoint、重建原因或 Provider 信息；客户端也没有重试/重建按钮，已有
Projection Worker 仍是唯一恢复 owner。

## 实现边界

- 后端只列出：正式确认、当前有效、已激活、当前 Projection 中尚未有条目，且精确 rebuild
  effect 仍可执行的记忆。
- Projection 权利不再有效时不把它伪装成可自动恢复的 `rebuilding` 项。
- 正式 MemoryVersion 激活现在会在写入前检查 Projection rebuild effect kernel；缺失
  kernel 时 fail closed，避免产生无法进入 Projection 的激活记录。
- iOS 将合同绑定到 `AccountLease` 和同一正式 feature gate；既有默认关闭的“纳入正式
  记忆”页仅显示数量摘要“正在整理正式记忆”，读取失败不会影响激活待办。
- 公开 Archive/Echo、三 Tab、Stitch 全屏视觉和普通用户导航均未改变。

## 终态误报防线

后续本地补强使“Projection 缺失”不再单独等价于 `rebuilding`。后端会将当前
`MemoryVersion` 精确关联到兼容 Projection 的 async operation/job，并仅在 operation 仍为
`accepted`、job 为 `pending`/`retryWait`/`leased` 且未请求取消时返回恢复项。

已取消、阻断、失败、未知、完成或缺少精确 effect 的任务均从 inbox 隐去；不会把终态故障
伪装为继续恢复。该收紧仍不暴露 job/operation ID、错误、MemoryVersion、Candidate、Source
或客户端重试入口。

## 验证

- 后端聚焦 API、Projection worker、认证、路由所有权、运行时与 formal Postgres smoke
  静态测试：59 项通过。
- 后端 `scripts/verify_backend.sh`：通过，包含 1,617 项单测及现有 Gate、FastAPI smoke、
  编译与 diff 检查。
- iOS 两个 scoped static check：通过。
- iOS Simulator `DreamJourneyTests/OwnerTruthContractsTests`：123/123 通过。
- iOS `generic/platform=iOS` Debug、`CODE_SIGNING_ALLOWED=NO` build：通过。
- iOS 在 macOS 上直接执行 `swift test` 会因现有 `OwnerTruthContractsTests.swift` 直接
  `import UIKit` 不能作为 macOS package test 运行；已改用 iOS Simulator XCTest 验证。
- 后端可执行的 disposable Postgres formal smoke 已扩展为先验证 `rebuilding`，再验证
  worker 完成后 inbox 为空；本机没有显式隔离 Postgres admin DSN，因此未执行该 smoke。
- 本次 runnable-state fence 的后端聚焦套件：46/46 通过；完整
  `scripts/verify_backend.sh`：1,619 个单测及现有 Gate 通过。

## 提交与状态

- 后端：`DreamJourneyBackend` `main@bc4f23e`
  `feat(owner-truth): expose projection recovery state`
- iOS：`DreamJourney_dev` `feature/prd-stitch-ui-adaptation@fb0d242`
  `feat(owner-truth): add projection recovery inbox UI`
- 未推送、未部署、未开启公开功能、未进行真机验证。

## 后续 Gate

部署前需要在隔离 Postgres 上执行：

```bash
DREAMJOURNEY_OWNER_TRUTH_FORMAL_SMOKE=1 \
OWNER_TRUTH_FORMAL_SMOKE_ADMIN_DATABASE_URL='<isolated-admin-dsn>' \
scripts/run-backend-owner-truth-interview-confirmation-formal-postgres-smoke.sh
```

该 Gate 通过前，当前结论仅为本地 G0/模拟器证据，不能声称已完成线上 Projection
恢复验收。
