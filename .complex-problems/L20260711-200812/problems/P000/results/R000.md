# Echo Trace 账号隔离与登出清理结果

## Summary

四类 Echo QA/诊断数据已从全局存储迁移到 active-owner 作用域。账号切换和登出会清理旧账号记录、页面缓存及临时导出，旧 session/voice 异步回调不能写入新账号证据。

## Done

- 使用 SHA-256 owner digest 为 trace、runtime diagnostics、evidence package、QA bundle 派生账号级存储键，不暴露原始 user ID。
- record/read/export 全部要求显式 owner，并由 active-owner scope 拒绝失效账号操作。
- evidence package、数字人 session 摘要和语音合成摘要携带 owner，trace/runtime/session/voice owner 不一致时拒绝记录和导出。
- 导出文件写入 owner digest 目录；账号切换和登出同时清除 UserDefaults、默认导出目录、manifest 和旧版全局文件。
- UserManager 将账号状态、Echo scope、KBLite、Knowledge 协调器和通知串行化；旧账号 profile 保存通过 expectedUserId 拒绝。
- Echo 页面在账号变化时失效生命周期、释放旧 runtime/session 且不生成新账号 diagnostics，并清空 capability、trace、provider 和 evidence 缓存。
- 腾讯 session 与声音复刻回调使用请求发起时 owner，并在回调到达时再次校验当前账号。
- 新增 owner isolation model smoke/static guard，并接入默认 release regression 和 release QA package。

## Verification

- `run-echo-trace-owner-isolation-model-smoke.sh` 通过。
- owner isolation、trace export、runtime diagnostics、evidence package、QA bundle 静态检查通过。
- Echo trace、evidence package、QA evidence bundle 三条模拟器导出 smoke 通过。
- 默认 `run-release-regression.sh` 通过，报告位于 `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-204702-release-regression/report.md`。
- Debug Simulator 与 generic iPhoneOS 无签名构建通过。
- `git diff --check` 通过。
- 独立复审指出的导出残留、owner 盖章、账号副作用竞态、旧 runtime 缓存和 nickname-only 竞态均已修复。

## Known Gaps

- 本任务按计划不做真机验证。
- UIQA 临时账号的纯 mock 导出会复制到 Simulator Documents 供外部 harness 读取；生产账号导出仍受 owner 生命周期清理约束。
- operation receipt 生命周期不属于本任务，保留为后续知识库隐私维护候选。

## Artifacts

- `docs/plans/task_25_p1-echo-trace-account-isolation.md`
- `docs/plans/task_25_solution_ticket.md`
- `Scripts/QA/prd-stitch-ui/echo-trace-owner-isolation-check.swift`
- `Scripts/QA/prd-stitch-ui/echo-trace-owner-isolation-model-smoke.swift`
- `Scripts/QA/prd-stitch-ui/run-echo-trace-owner-isolation-model-smoke.sh`
- `tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260711-203344/`
- `tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-export-smoke/20260711-203407/`
- `tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260711-203428/`
