# WI-S0-03-05 数字人安全接入路径记录

日期：2026-07-16
Work Item：`WI-S0-03-05`
状态：`EXTERNAL_BLOCKED`
Decision：`KEEP_DIRECT_MOBILE_CLOSED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`HELD`

## 1. Gate 与依赖

- 直接依赖 `WI-S0-03-01/02/03` 已完成；`WI-S0-03-04/06` 也已分别封死 realtime voice 和 QA artifact 的旧凭据回流路径。
- Registry 要求 `G3` 与 `G4`，当前均为 `MISSING`。静态代码、mock 或通用 project credential 不能替代 Provider sandbox、scope/TTL/audience/revocation 与风险验收证据。
- 当前 `/digital-human/sessions` 返回 value-free `blockedStaticCredential`，iOS 只允许普通 Echo 音频或文字 fallback。

## 2. 本轮可逆目标

1. 核对腾讯数智人官方 iOS SDK/aPaaS 合同是否提供可撤销、带 scope/TTL/audience 的 per-session mobile credential。
2. 若官方能力满足，定义 server-side broker 合同和 deny/replay/expired 验证；不得将长期 project credential 下发 iOS。
3. 若官方能力不满足，固定 `textFallback` 决策，补 capability decision receipt、静态 gate 和线上 value-free smoke，不伪造有效期字段。
4. 本项不在 G3/G4 缺失时开放腾讯移动端直连，不改变公开 UI。

## 3. Provider 官方合同核对

- 服务端渲染 iOS SDK：`https://cloud.tencent.com/document/product/1240/110200`。
- aPaaS 接口调用：`https://cloud.tencent.com/document/product/1240/90943`。
- 云渲染交互会话 Demo：`https://cloud.tencent.com/document/product/1240/130451`。
- 服务端创建会话：`https://cloud.tencent.com/document/product/1240/100388`。
- 核对日期：`2026-07-15`。
- 官方 iOS SDK 接入要求客户端以项目级 `appkey/accesstoken` 初始化；aPaaS 调用也使用项目级凭据和签名。
- 服务端创建会话接口能返回流地址，但当前公开合同未验证可供移动 SDK 使用的 per-session credential 具备 `scope`、`TTL`、`audience` 与单会话 `revocation`。
- 临时 AK/SK 文档属于其他基础 iPaaS/账号托管路径，不作为云渲染移动 SDK scoped credential 的证明。
- 结论只表示“官方公开合同未验证”，不推断 Provider 永远不支持；在取得新的官方合同与 sandbox 证据前，移动端直连保持关闭。

## 4. 已落地的关闭路径

- `/digital-human/sessions` 与 `/config/runtime.digitalHuman` 共用 `DigitalHumanAccessPolicy`，合同版本为 `4`。
- 合同固定为 `accessPath=textFallback`、`mobileDirectAllowed=false`、`brokerStatus=providerContractNotVerified`、`releaseVisible=false`。
- `decisionReceipt` 明确列出四项 required/verified/missing 属性，且不返回 Provider 密钥、不虚构 `expiresAt` 或 `expiresInSeconds`。
- iOS runtime parser、session credential 和 factory 均默认拒绝；旧合同、缺字段、未知 broker 状态或未验证属性不能选择真实腾讯 bridge。
- iOS 已删除 `TencentDigitalHumanSDKConfiguration` 的 `appKey/accessToken` 字段以及 `VirtualmanParams(appkey:accesstoken:)` 初始化路径。
- 腾讯 bridge 在 scoped broker 未实现前 fail closed，普通 Echo fallback 保持可用。

## 5. Gate 结论

- `G3=MISSING`：没有 Provider sandbox 的 scoped credential 签发、replay/expired/wrong-subject/wrong-device deny 与撤销回执。
- `G4=MISSING`：没有完成对应隐私、安全和风险验收。
- Work Item 以 `EXTERNAL_BLOCKED` 收敛关闭路径；不得标记 `VERIFIED`，不得开放腾讯移动端直连。

## 6. 验证与交付

- Backend：`308` 项 memory-store 单测、FastAPI smoke、credential response boundary smoke 通过。
- Backend commit：`d23b940 security: close unverified digital-human mobile path`，已推送 `origin/main` 并部署。
- 线上：服务器 HEAD 为 `d23b940`；Postgres 环境 value-free deployed smoke 通过。
- iOS：digital-human secure path、credential response boundary、mobile credential retirement、QA artifact 与 release QA package gate 通过。
- iOS：无签名 iPhoneOS Release workspace generic build 通过；最终 `.app` credential artifact scan 通过。
- iOS commit：本文所在提交。
- Release app：`tmp/DerivedData/WI-S0-03-05-workspace/Build/Products/Release-iphoneos/DreamJourney.app`。
