# 接入 Receipt 跨仓 Release Gate 并完成非真机构建

## Problem Definition

后端 receipt 最小化功能尚未被 iOS release regression 和 QA package 守护，状态文档也未形成可复验交接证据。

## Proposed Solution

沿用现有 knowledge privacy/change-feed gate 模式，新增 Swift static contract check 和 shell runner。Static check 读取后端 helper/store/CLI/smoke/运维文档，断言最小 envelope、fingerprint-first、dirty compact canonical compare、default dry-run 和 no delete/no hash rewrite。Runner 执行后端组合 smoke与 static check。Release regression 默认运行 static contract，可选开关运行完整跨仓 gate；release QA package 验证接入。更新 Task 26 状态文档与覆盖矩阵，运行 default release regression、QA check、Simulator 和 generic iPhoneOS build。

## Acceptance Criteria

- Static check 与 runner 可在任意正确 BACKEND_ROOT 下执行。
- Release regression 默认有低成本静态 guard，并暴露可选完整 gate 开关。
- Release QA package 检查新增产物和 runner 接入。
- 状态文档记录实现边界、命令、分支、部署前后顺序和不做真机。
- Default release regression、完整 gate、Simulator/generic iPhoneOS build、diff check 通过。

## Verification Plan

运行新增 runner、Swift check、release QA package check、默认 release regression、xcodebuild 两类非真机构建和双仓 `git diff --check`。

## Risks

- Release regression 已较大，默认只运行静态 guard，完整后端组合 gate使用显式开关。
- 不应读取或输出后端私密部署 token。

## Assumptions

- BACKEND_ROOT 默认指向同级 `DreamJourneyBackend`。
