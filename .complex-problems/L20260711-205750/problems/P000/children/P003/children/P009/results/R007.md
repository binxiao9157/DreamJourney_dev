# Receipt 跨仓 Gate 与非真机构建结果

## Summary

已完成 P009：新增跨仓静态/完整 gate，接入 release regression 与 release QA package，更新状态文档，并完成默认 release regression、Simulator smoke 和 generic iPhoneOS 构建。

## Done

- 新增 Swift static contract check，覆盖 compact writer/reader、fingerprint-first、dirty compact canonical compare、privacy hash 保留、CLI 默认 dry-run、组合 smoke 和运维边界。
- 新增跨仓 runner，串联 Swift guard 与后端 34 项 receipt maintenance smoke。
- Release regression 默认执行静态 guard，新增 `RUN_KNOWLEDGE_RECEIPT_MAINTENANCE_GATE=1` 可选完整 gate。
- Release QA package 检查新增 guard、runner 和状态文档。
- 状态文档记录部署先 dry-run、不删除 receipt、不重写 hash、不做真机及验证证据。

## Verification

- 完整跨仓 receipt gate：通过，后端组合 smoke 34 项。
- Release QA package check：通过。
- 默认 release regression：通过；包含后端 304 项 verify、全部 Swift guard、Simulator build、Archive -> Echo 和延迟回信 smoke。
- Generic iPhoneOS 无签名构建：通过，Bundle ID 使用 `com.yxj.dreamjourney.app`。
- 双仓 `git diff --check`：通过。

## Gaps

- 尚未提交、推送、部署或执行线上 Postgres；这些属于 P010，按用户要求本轮暂停。
- 不做真机。

## Artifacts

- `Scripts/QA/prd-stitch-ui/knowledge-receipt-maintenance-contract-check.swift`
- `Scripts/QA/prd-stitch-ui/run-knowledge-receipt-maintenance-gate.sh`
- `docs/superpowers/status/2026-07-11-knowledge-operation-receipt-minimization.md`
- `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task26-receipt-final/report.md`
- `tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260711-task26-receipt-final-iphoneos/report.md`
