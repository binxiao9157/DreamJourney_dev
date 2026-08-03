# Round 3C2B Typed API、Identity/AuthZ 与 Capability Rollout 结果

## Summary

已形成从当前未版本化/宽字典/shared-token 路径迁移到 typed `/v2`、强身份、fail-closed AuthZ 和版本化 Capability 的双轨 rollout 合同。RoutePolicy 必须在请求发送前固定；HTTP error、跨 Vault 404 或网络失败不能临时触发 legacy mutation。Authority cutover 后旧 route 只转同一 V2 use case/receipt，无稳定 command ID 的旧客户端只能升级或只读。

## Done

- Product Spec 新增第 30 节和 X01–X10 当前风险证据。
- 定义 EndpointDescriptor 与 H01–H05 auth modes，移除 `automatic/sharedTokenFallback`。
- 定义 Identity/Source/Memory/Conversation/DataRights/Optional typed clients 与 L01–L05 route modes。
- 固定 strong identity challenge/verify、session/refresh rotation/reuse、AccountLease CAS 和中性错误。
- 定义 G01–G09 AuthZ route groups、production unknown/error/fallback deny 和 cross-vault 404。
- 定义 CapabilitySnapshot 的 contract/dataAuthority/policy/epoch/cohort/minClient/TTL/四维成熟度。
- 定义 iOS/backend/provider credential eradication 和最终 `.app/.appex`/header scan gate。
- 编制 P00–P10 rollout waves、client/server compatibility matrix 和 error/retry contract。
- 增加 20 个身份、路由、AuthZ、capability、旧客户端和 credential 场景。
- Evidence Matrix 新增 7.5；新增 `product-v4-api-authz-rollout-check.py`。
- 将 iOS account/store 门禁截到第 30 节，避免未来章节污染计数。

## Verification

- API/AuthZ rollout check：10 risks、5 auth modes、5 route modes、9 groups、11 waves、20 scenarios，PASS。
- iOS Account/Store rollout check：11 risks、17 stores、9 waves、20 scenarios，PASS。
- API/AuthZ contract check：6 principals、36 endpoints、10 errors、13 scenarios，PASS。
- Backend evidence、Data contract、Job/Provider、Evidence Matrix 与 Product V4 docs checks 通过。
- Product V4 docs check当前为 36 requirements、21 conflicts、41 decisions、43 review responses、4 lifecycle banners。
- 专项安全 reviewer 未在限定窗口返回结果，已停止；不将其作为成功证据，Round 3D 重新独立复审。

## Known Gaps

- 没有生产 `/v2` route/client、strong identity provider、AuthZ enforce/canary、Capability snapshot 或 artifact secret scan 实现。
- shared/system/provider credential 当前是否进入真实 Release 包仍需产物与抓包证明。
- DR-023/026/031/040 仍有产品、合规、Provider 和运维门。
- 当前旧客户端分布、minimum client 和兼容窗口未知。
- 真实 route/Postgres cross-vault、refresh reuse、old-client 426 和 credential rotation 尚未验收。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-api-authz-rollout-check.py`
- `Scripts/QA/product-v4/product-v4-ios-account-store-rollout-check.py`
- `docs/plans/task_27_round_3c2b_solution.md`
- `docs/plans/task_27_round_3c2b_result.md`
