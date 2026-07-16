# WI-S0-06-05 Runtime Capability 五轴合同

日期：2026-07-16
Work Item：`WI-S0-06-05`
状态：`IMPLEMENTED / G2_VERIFIED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`RELEASED`

## 1. 目标与边界

- 分别表达 `implemented`、`enabled`、`providerReady`、`releaseVisible`、`externalVerified`。
- Provider 配置、mock 合同或代码存在均不能单独推导为公开可用。
- 旧 runtime bool 继续兼容旧客户端；新 iOS 合同缺失时按 `unknown/deny`。
- G3/G4 只能由有效外部证据产生，代码和一次 smoke 不能自行签署。
- 不改变三 Tab、Stitch 视觉或普通用户页面布局。

## 2. 已实现

- Backend 新增 `RuntimeCapabilityComposer` 和版本化 `capabilitySnapshots`。
- `/config/runtime` 为图像分析、音频、视频、时间信件、家庭、家人空间、音色复刻和数字人输出五轴、Provider、fallback、reason 与 evidence timestamp。
- text-only 图像分析和 mock object storage 明确 `providerReady=false`。
- Voice Provider 即使配置完成，仍保持 `releaseVisible=false`、`externalVerified=false`，不会自动公开。
- iOS 新增 `RuntimeCapabilitySnapshot`、保守 legacy decode 和账号隔离缓存。
- Archive/Profile 普通入口同时要求 route policy allow 和五轴 `isPubliclyAvailable`；QA launch arg 仍只用于内部壳层。
- Voice Clone/Digital Human Provider effect 使用完整合同的 `isProviderOperational`，旧 bool 不再解锁 effect。
- Echo QA 面板增加 Voice/Digital Human 五轴诊断摘要。

## 3. 验证入口

- Backend unit：`.venv/bin/python -m unittest tests.test_runtime_capabilities`
- Backend full：`./scripts/verify_backend.sh`
- iOS model：`Scripts/QA/prd-stitch-ui/run-runtime-capability-snapshot-model-smoke.sh`
- iOS integration：`swift Scripts/QA/prd-stitch-ui/runtime-capability-axis-integration-check.swift`
- Release regression：`Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- 部署 smoke：`scripts/run-backend-runtime-capability-deployed-smoke.sh`

## 4. Gate 状态

- 本地 G0：五轴全组合、legacy fail-closed、静态消费 Gate 和 iOS build 已通过。
- G2：`PASS`。Backend `d455dda` 已推送、部署；线上 `/health` 为 `production/postgres`，`/config/runtime` 五轴 smoke 与 release-policy smoke 通过。
- G3：`OPEN`。Provider sandbox/配额/质量证据不能由本项关闭。
- G4：`OPEN`。产品、Privacy、真机和外部验收不能由本项关闭。
- 公开 release 继续保持当前 Closed Pilot Owner 文字核心；隐藏功能没有新增公开入口。

## 5. 验证证据

- Backend full verify：333 tests，FastAPI、credential boundary、knowledge smoke 全部通过。
- iOS model/integration Gate 通过。
- iOS Debug Simulator generic build：`BUILD SUCCEEDED`，DerivedData 为 `tmp/DerivedData/WI-S0-06-05-first`。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260716-wi-s0-06-05-static-rerun/report.md`。
- Backend commit：`d455dda feat(WI-S0-06-05): separate runtime capability axes`，已推送和部署。
- iOS commit：由本文所在提交记录；未经用户明确要求不推送。

## 6. 后续

- 下一 Work Item：`WI-S0-06-06`，保证 QA override 仅在 Debug/UIQA 当前进程有效且不能绕过生产 command deny。
