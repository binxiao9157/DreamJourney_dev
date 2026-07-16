# WI-S0-06-08 Server Deny Canary / Kill Switch / Legacy Retirement

日期：2026-07-16
Work Item：`WI-S0-06-08`
状态：`IMPLEMENTED / G0_VERIFIED / G2_CANARY_ACTIVE / ZERO_USE_WINDOW_ACTIVE / G4_OPEN`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`ACTIVE`

## 目标

- 在全局 observe 时按 feature 启用 server deny canary。
- kill switch 的优先级高于客户端缓存、QA audience 和全局 observe。
- 为旧 runtime alias 建立不含正文、账号、手机号、请求体或凭据的使用观测。
- 只有跨完整观察窗零命中并取得 Operations 批准后，才把 legacy alias 标记为 retired 并删除。

## 已实现合同

- 后端支持 `RELEASE_POLICY_ENFORCED_FEATURES` 按 feature canary。
- 后端支持 `RELEASE_POLICY_EMERGENCY_REVISION` 与 `RELEASE_POLICY_EMERGENCY_DISABLED_FEATURES` kill switch。
- `/ops/release-policy/observations` 仅允许 system principal，返回 bounded、no-store、value-free rollout evidence。
- 旧客户端低于 `minClient` 时，enforce canary 返回 `426 client_upgrade_required` 与 `readOnly/deny` access mode。
- iOS `/config/runtime` 请求声明 runtime contract version `2` 与当前 client build。
- iOS 解析 `rolloutContractVersion/runtimeContractVersion/canaryFeatures/killSwitchFeatures`，不改变公开 UI。

## 当前边界

- 当前 recorder 是单进程 bounded evidence；持久化聚合和跨实例指标仍由 `WI-S0-07` 接管。
- legacy alias 尚处于 `OBSERVING`，未伪造“已退役”结论。
- 168 小时 G2 观察窗和 Operations 批准仍待完成；具体 feature 的真实设备公开仍需 G4。

## 部署与演练回执

- 后端实现提交：`d3ae23d feat(WI-S0-06-08): add release policy rollout controls`。
- QA runtime contract 提交：`5bd336d test(WI-S0-06-08): mark typed runtime clients`。
- 两个提交均已推送并部署；服务器为 `production/postgres`。
- kill switch 演练：policy revision `2` / emergency revision `1` 临时关闭 `digitalHumanLivePanel`，线上返回 `emergencyRevoked`；随后用 policy revision `3` / emergency revision `2` 恢复。
- 最终常驻状态：全局 `mixed`，`familyManagement` 为 deny canary，kill-switch 集合为空。
- 干净观察窗起点：`2026-07-16T11:56:37Z`；起点证据为 typed hit `5`、legacy hit `0`。
- kill-switch 演练报告：`tmp/visual-qa/prd-stitch-ui/release-policy-rollout/20260716-wi-s0-06-08-kill-switch-drill/report.md`。
- 恢复报告：`tmp/visual-qa/prd-stitch-ui/release-policy-rollout/20260716-wi-s0-06-08-restored/report.md`。
- 干净观察窗报告：`tmp/visual-qa/prd-stitch-ui/release-policy-rollout/20260716-wi-s0-06-08-clean-window/report.md`。
- 数字人恢复回归：`tmp/visual-qa/prd-stitch-ui/backend-digital-human-session-smoke/20260716-wi-s0-06-08-clean-window-dh/report.md`。
