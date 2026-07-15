# WI-S0-03-04 Realtime Voice 安全接入路径记录

日期：2026-07-16
Work Item：`WI-S0-03-04`
状态：`EXTERNAL_BLOCKED`
Decision：`KEEP_DIRECT_MOBILE_CLOSED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`HELD`

## 1. Gate 与依赖

- 直接依赖 `WI-S0-03-01/02/03` 已完成；`WI-S0-03-06` 也已封死 QA artifact 回流路径。
- Registry 要求 `G3` 与 `G4`，当前均为 `MISSING`，静态代码或 mock 不能替代 Provider sandbox、撤销与风险证据。
- 当前 `/voice/realtime-token` 返回 value-free `blockedStaticCredential`，iOS 只允许文字回响 fallback。

## 2. 本轮可逆目标

1. 核对火山官方 realtime SDK/协议是否提供可撤销、带 scope/TTL/audience 的 per-session mobile credential。
2. 若官方能力满足，定义 server-side mint/broker 合同和 deny/replay/expired 验证；不得将长期 credential 下发 iOS。
3. 若官方能力不满足，固定 `backendProxyOrText` 决策，补 capability decision receipt、静态 gate 和线上 value-free smoke，不伪造 `expiresAt`。
4. 本项不在 G3/G4 缺失时开放 realtime voice，不改变公开 UI。

## 3. Provider 官方合同核对

- 官方依据：`https://docs.volcengine.com/docs/6561/1597646?lang=zh`，核对日期 `2026-07-15`。
- 官方 iOS Dialog SDK 接入示例要求客户端配置 `APPID`、`APPKEY`、`ACCESS TOKEN` 和固定 Resource ID。
- 当前公开合同未验证 per-session credential 的 `scope`、`TTL`、`audience`、单会话 `revocation`，也没有可用于 G3 的撤销回执。
- 结论只表示“官方公开合同未验证”，不推断 Provider 永远不支持；在取得新的官方合同与 sandbox 证据前，移动端直连保持关闭。

## 4. 已落地的关闭路径

- `/voice/realtime-token` 与 `/config/runtime.voice` 共用同一份 server-authoritative 决策。
- 合同固定为 `accessPath=backendProxyOrText`、`mobileDirectAllowed=false`、`brokerStatus=providerContractNotVerified`。
- `decisionReceipt` 明确列出四项 required/verified/missing 属性，且不返回 Provider 密钥、不虚构 `expiresAt` 或 `expiresInSeconds`。
- iOS 对旧合同、缺字段、未知 broker 状态一律默认拒绝；只有显式 `scopedSessionCredential` 路径才可能进入后续 broker 实现。
- `DialogEngineManager` 记录无值 reason code 后回落文字路径，不重新读取本地或包内共享凭据。

## 5. Gate 结论

- `G3=MISSING`：没有 Provider sandbox 的签发、replay/expired/wrong-subject/wrong-device deny 与撤销回执。
- `G4=MISSING`：没有完成对应隐私、安全和风险验收。
- Work Item 以 `EXTERNAL_BLOCKED` 收敛关闭路径；不得标记 `VERIFIED`，不得开放 realtime voice。

## 6. 验证与交付

- Backend：`308` 项单测、FastAPI smoke、credential response boundary smoke 通过。
- Backend commit：`2fafa50 security: close unverified realtime voice path`，已推送 `origin/main` 并部署。
- 线上：production 健康检查为 `store=postgres`；value-free deployed smoke 通过。
- iOS：realtime secure-path、credential response boundary、mobile credential retirement 三条 gate 通过。
- iOS：无签名 iPhoneOS Release generic build 通过；最终 `.app/.appex` credential artifact scan 通过。
- Release app：`tmp/DerivedData/WI-S0-03-04/Build/Products/Release-iphoneos/DreamJourney.app`。
