# Echo Readiness 严格语义预检

日期：2026-07-21

## 问题

原 `Echo Readiness Report v2` 将单项 `skipped` 与 `passed` 一并计入
`completed=true`。这会使未配置后端、未执行数字人会话探测或未执行复刻合成
探测的报告看起来像已经通过 Readiness。

这不符合 V4 对 `skipped/unknown/missing` 不得计为 PASS 的要求，也会误导
后续发布、真机和 Provider 排障判断。

## 修复

- 报告升级为 `schemaVersion=3` / `Echo Readiness Report v3`。
- 聚合层新增 `gateResult`、`readinessStatus`、`readinessReason` 和
  `notRunChecks`。
- 所有 required checks 通过时才允许 `completed=true`。
- `skipped`、`notRun` 或 `missing` 聚合为 `readinessStatus=notRun`；
  `failed`、`blocked` 和未知状态分别保持独立状态。
- `READINESS_STRICT=1` 在任何非 `passed` 聚合状态退出失败；非严格模式仍可
  导出诊断包，但不会把它标记为完成。

## 验证

- `python3 Scripts/QA/prd-stitch-ui/echo-readiness-report-strict-contract-check.py`
  - 无后端环境下普通模式：`completed=false`、`readinessStatus=notRun`。
  - 无后端环境下严格模式：退出码非零、`readinessStatus=notRun`。
- `swift Scripts/QA/prd-stitch-ui/echo-readiness-report-check.swift .`
- `swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .`
- `python3 -m py_compile ...` 与 scoped `git diff --check`

## 证据边界

这是 `WI-S0-07-09` 的 fail-closed 内部预检，不关闭该 Work Item，也不改变
Registry 的 `PLANNED/STOP` 状态。其直接依赖、G2 真实运营分母和 G4 发布/产品
门仍然开放；因此它不计入 V4 Work Item 完成数或整体进度。
