# 心境追踪状态 UIQA Smoke

## 目标

把 `我的 -> 心境追踪 / 长辈关怀` 的 empty / stale / failed 状态固定成可重复的模拟器 UIQA 回归，避免再次出现“心境追踪加载失败”但缺少清晰状态、重试入口和验收证据的问题。

## 覆盖范围

- `empty`：暂无可用关怀信号。
- `stale`：数据可能不是最新。
- `failed`：关怀信号加载失败。
- Profile 卡片展示：
  - 状态文案。
  - `重新同步` 操作入口。
  - 稳定状态标识。
- 长辈关怀子页展示：
  - 状态卡。
  - 聚合状态文案。
  - 不暴露医生联系、拨号、短信或后端干预提交。

## 一键运行

```bash
RUN_ID=20260619-profile-care-state-smoke \
tmp/visual-qa/prd-stitch-ui/run-profile-care-state-smoke.sh
```

## 输出证据

- `tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/<run-id>/profile-care-state-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/<run-id>/01-profile-care-state-smoke.png`
- `tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/<run-id>/runtime.log`
- `tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke/<run-id>/oslog.log`

## Release 回归接入

- 静态 guard：`tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke-check.swift`
- release regression 默认只跑静态 guard。
- 如需跑公开 MVP 关怀/心境追踪 P0 回归门，使用统一开关：

```bash
RUN_P0_PROFILE_CARE_REGRESSION=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

该开关会同时跑本地 empty / stale / failed UIQA，以及真实后端 active / empty / stale / failed-retry UIQA。只需要单独跑本地状态 smoke 时，仍可使用 `RUN_PROFILE_CARE_STATE_SMOKE=1`。

## 边界

这个 smoke 使用本地 fallback 快照，不验证真实后端 `/care/snapshots/latest/{userId}`。真实后端 active / empty / stale / failed 合同仍由 release-like backend acceptance 和 backend state fixture 检查覆盖。
