# WI-S0-06-04 Captured Policy Gate

日期：2026-07-16
Work Item：`WI-S0-06-04`
状态：`IMPLEMENTED_OBSERVE / G2_VERIFIED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`RELEASED`

## 1. 目标与边界

- iOS 页面入口与网络请求复用同一个不可变 `FeatureDecision`。
- 后端不信任客户端 `enabled=true`，按服务端发布策略重新判定，并在 effect 前重验。
- 深链、旧页面、账号切换、策略过期、紧急撤销和 `401` 重试不得绕过 Gate。
- `FeatureDecision` 只作为 Intent/command metadata 和 QA 证据，不写入业务 Authority。
- 不修改现有三 Tab、Stitch 视觉或普通用户文案。

## 2. 已实现

- iOS：`FeatureGateEvaluator` 捕获 `decisionId/feature/policyVersion/accountGeneration/allowed/reason/expiresAt`，请求前校验账号代际、缓存有效期、策略版本和服务端当前决定。
- iOS：Archive、Echo、Profile 受控入口统一经过 route gate；`/profile`、`/context/build`、Echo 延迟回信、账号注销、隐藏媒体和 Provider route 统一映射 command feature。
- iOS：同一 decision metadata 进入请求头，并在 `401` token refresh 后继续复用；Echo QA 证据包记录 policy version、revision、allow/deny 和 reason。
- Backend：`ReleasePolicyCommandGate` 重新计算服务端决定，校验 decision id、feature、policy version/revision、account generation 和 expiry。
- Backend：支持 `RELEASE_POLICY_COMMAND_MODE=observe|enforce`；默认 `observe`，先收集旧客户端与 UI/command mismatch，不直接破坏现网。
- Backend：同步 handler 与 system dispatch 在进入 effect 前重验；隐藏 feature 即使客户端伪造 allow 也不能成为服务端 Authority。

## 3. Gate 与迁移状态

- `G0`：沿用 `WI-S0-03-07` 的 `CLOSED_WITH_RISK_EXCEPTION`，不再阻断开发。
- `G2`：`PASS`。Backend `f6e6abc` 已推送并部署；线上 Postgres health、release-policy snapshot smoke 与 command observe smoke 通过。
- `G3/G4`：仍为 Provider/Privacy/真实外部验收 Gate，不由本 Work Item 虚假关闭。
- 部署顺序：后端 `observe` 先部署；审阅 mismatch 和旧客户端覆盖后，才允许按 cohort 切换 `enforce`。

## 4. 验证入口

- iOS model：`Scripts/QA/prd-stitch-ui/run-feature-gate-evaluator-model-smoke.sh`
- 跨仓静态 Gate：`swift Scripts/QA/prd-stitch-ui/captured-feature-policy-gate-check.swift .`
- Backend unit：`STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_release_policy`
- 部署 smoke：`scripts/run-backend-release-policy-command-deployed-smoke.sh`
- 一键回归：`RUN_BACKEND_RELEASE_POLICY_COMMAND_SMOKE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 5. 验证证据

- Backend：`./scripts/verify_backend.sh` 通过，328 tests + FastAPI/knowledge/credential smoke 通过；目标 release-policy tests 18 项通过。
- iOS：feature evaluator model、captured policy 跨仓 Gate、release QA package、`git diff --check` 通过。
- iOS workspace Debug Simulator build：`BUILD SUCCEEDED`；日志 `tmp/wi-s0-06-04-final-build.log`。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260716-wi-s0-06-04-static-pass/report.md`。
- 线上：`/health` 返回 `store=postgres`；snapshot smoke 通过；command smoke 返回 `mode=observe core=allow hidden=observeDeny`。
- Backend commit：`f6e6abc feat(WI-S0-06-04): gate captured release policy commands`，已推送、部署。
- iOS commit：由本文所在提交记录；未经用户明确要求不推送。

## 6. 完成边界与下一项

- 本 Work Item 已完成 route/command captured policy 的实现和 G2 部署证据，`RELEASE_POLICY` lease 已释放。
- `G3/G4` 仍保持外部未关闭，不影响继续开发，但不得据此公开 hidden feature。
- 下一 Work Item：`WI-S0-06-05`，拆分 capability、provider readiness 与 release exposure，不改变公开视觉布局。
