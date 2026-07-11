# Receipt 最小化跨仓 Gate、构建与部署验收

## Problem Definition

后端实现已完成，但 iOS release 流程尚不知道新的 receipt maintenance gate，Task 26 状态文档、双仓提交、部署和真实 Postgres 证据也尚未收口。

## Proposed Solution

在 iOS QA 目录新增跨仓 contract check 和 gate runner，验证后端 compact writer/reader、maintenance CLI、组合 smoke、运维文档与默认无 apply，并接入 release regression 和 release QA package。更新状态文档与覆盖矩阵。运行跨仓 gate、release regression、Simulator/generic iPhoneOS 构建和双仓 diff check；分别提交推送。随后通过既有服务器访问方式部署后端，运行线上 health/knowledge smoke、receipt maintenance dry-run，只有报告满足硬门才执行小批 apply 和二次幂等验证。

## Acceptance Criteria

- iOS 跨仓静态 gate 覆盖 compact envelope、fingerprint 保留、CLI 默认 dry-run、组合 smoke 和运维文档。
- Gate 接入 release regression 与 release QA package。
- Task 26 状态文档记录实现、分支/提交、验证命令、部署顺序和线上证据。
- 默认 release regression、相关可选 gate、Simulator 与 generic iPhoneOS build、双仓 diff check 通过。
- 后端和 iOS 分别提交推送，不混入密钥或临时产物。
- 后端成功部署，线上 `/health` 正常。
- 线上 Postgres 先 dry-run；若 `status=ok` 且 failed=0，再小批 apply，并确认二次运行 candidate/updated=0。
- 线上 duplicate/conflict、privacy maintenance 和 change-feed receipt barrier smoke 通过。

## Verification Plan

运行新增 cross-repo gate、release regression、release QA package check、xcodebuild Simulator/generic iPhoneOS、后端 verify、git diff/check/status；部署后保存 health、dry-run/apply 与 deployed smoke 脱敏报告。

## Risks

- 线上 dry-run 若发现异常历史行或锁超时，必须停止 apply，记录 blocker，不猜测修复。
- JSONB apply 可能产生 WAL/表膨胀，先小 batch 并观察数据库。
- iOS 不需要修改产品 UI，也不做真机。

## Assumptions

- 既有服务器 SSH/部署文档和私密访问配置仍可用。
- 用户已授权完成后提交、推送和部署。
