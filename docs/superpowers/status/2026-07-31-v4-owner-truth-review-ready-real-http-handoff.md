# Owner Truth：ReviewReady 真实 HTTP 定向确认交接

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / QA_ONLY / DEFAULT_OFF / NOT_DEPLOYED`

## 本轮闭环

在既有 `reviewReady -> focused confirmation inbox` 内存 UIQA 的基础上，补充了真实 `DreamJourneyBackendClient` 请求路径的受控 HTTP 验证：

- 仅在 `DEBUG` 或 `UI_QA_SIMULATOR` 下提供可注入的 Alamofire Session 和 base URL；正式 `shared` 客户端继续使用既有 Bundle URL、默认 Alamofire 会话、认证存储和 FeatureGate 重校验。
- 使用受控 `URLProtocol` 返回正式状态与收件箱 JSON，验证提案状态和确认收件箱分别发出一条 `GET`。
- 状态返回当前 `reviewReady` 批次，收件箱同时返回当前批次与另一条已就绪批次；页面只显示本地 `focusedReviewBatchId` 对应的当前批次。
- 请求带认证头，不带 `X-DreamJourney-QA-Owner-Truth`。
- 不会发出 `POST`、确认命令、Memory 激活、自动详情导航或其他写操作。
- 延迟收件箱响应返回前切换 `AccountLease`，旧结果被丢弃，页面不展示旧批次。

本轮不改变公开 UI、默认发布态、后端路由、Provider 或真实设备行为。

## 验证

- `DreamJourneyTests/OwnerTruthContractsTests`：153/153 通过。
- `owner-truth-candidate-proposal-status-handoff-check.swift`：通过。
- `run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh`：通过。
- 通用未签名 iPhoneOS Debug 编译：通过。
- `git diff --check`：通过。

UIQA 截图：

`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-candidate-proposal-review-ready-smoke/20260731-225733/01-owner-truth-interview-candidate-proposal-review-ready-smoke.png`

XCTest 结果包：

`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/OwnerTruthRealHTTP.xcresult`

## 未覆盖边界

- `404` / `410` 过期批次的专门 UI 语义尚未定义为本轮范围。
- 后端隔离 PostgreSQL smoke 已脚本就绪，但尚无专用管理员 DSN，因此未实际执行。
- 不构成部署、生产数据、真实 Provider、真机或公开功能的验收。
