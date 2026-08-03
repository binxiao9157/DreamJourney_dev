# Round 3C2 iOS、API 与 AuthZ 双轨 Rollout 方案

## Problem Definition

当前 iOS 的 `UserManager` 本地账号、`BackendAuthSessionStore` Keychain session、全局 refresh waiter、Archive/mailbox callback、Memoir/Memory/Voice/TTS/DelayedReply 本地状态和旧 route fallback 没有同一账号代次。后端又仍有 shared/system token、ownership shadow/fallback 和未版本化 route。若直接接 `/v2`，旧请求可覆盖新账号 session、A 的响应可写入 B 的 store、跨 Vault 404 可触发 legacy fallback，并形成双 Authority。

## Proposed Solution

分两条互锁的 rollout 轨道：

1. **iOS Account/Store 轨道**
   - 建立唯一 `AccountSessionActor`，原子持有 `subjectId/vaultId/principalId/sessionId/tokenFamilyId/accountGeneration/authorityEpoch/releasePolicySnapshot`。
   - 冷启动必须协调 UserDefaults user 与 Keychain session；缺一、过期或 subject 不匹配时进入 re-auth，不进入业务页。
   - 所有 request/task/timer/callback 捕获不可变 `AccountLease`，发送、retry、解析和 store commit 前均验证；切账号先旋转 generation，再取消旧任务，最后激活新 store scope。
   - 所有私有 store 使用 owner/vault digest + schema version envelope；无 owner 证明的 legacy state quarantine 或清理，禁止自动认领。
   - TimeLetter 等 draft 保持 local，只有显式封存/提交才产生稳定 commandId。
   - 先建立 XCTest target 和 concurrency/store migration tests，再迁 UI；保持 Stitch 视觉不变。
2. **API/AuthZ 轨道**
   - 将 `DreamJourneyBackendClient` 收窄为 `LegacyFacadeClient`，新增按 Identity/Source/Memory/Conversation/DataRights 的 typed `V2Client` 和 route policy。
   - 用户业务请求只允许 `userRequired` bearer session，不再附 shared/system token；machine/operator/provider credential 不进入 iOS。
   - legacy route 在 cutover 前可作为单 Authority；V2 read 可 shadow compare，V2 mutation shadow 只能 dry-run。cutover 后 legacy facade 调同一 V2 use case/receipt，错误不得 fallback 到旧写。
   - 强身份、refresh rotation/reuse、session CAS、logout/revoke 和 AuthZ enforce 与 account generation 联动。
   - ReleasePolicy/Capability snapshot 固定 `contractVersion/policyVersion/authorityEpoch/cohortId/issuedAt/expiresAt/minClientVersion` 与四维成熟度；一个 command 使用同一快照，未知/过期 fail closed。
   - 逐能力 cohort rollout：Identity → Profile/Source read → Memory review → Owner QA → optional modules；每步有 read shadow、command dry-run、canary、pause、rollback 和 retirement gate。

## Acceptance Criteria

- 明确当前 blocker/high 与绝对文件证据，不把已有局部 KBLite/Echo generation 当全局完成。
- 定义 `AccountSessionActor/AccountLease` 字段、生命周期、冷启动/登录/refresh/logout/switch/delete 顺序。
- 覆盖 Archive、KBLite、Conversation、Memoir、Memory、Voice/TTS、DH、DelayedReply、Notification、Draft、Receipt/Export 等私有状态的迁移策略。
- refresh/result/callback/store commit 均有 generation/session/authorityEpoch CAS；A 的任何晚到结果不能写 B。
- typed V2/legacy facade route policy 明确，401/403/404/409/5xx/unknown schema 不触发旧 mutation fallback。
- iOS release 不携带 system/provider credential，用户请求不附 `X-DreamJourney-Api-Token`。
- 强身份与 AuthZ 从当前状态到 fail-closed 的 rollout/cutover/rollback 有执行顺序。
- capability/release policy 按 server cohort、TTL、minimum client 和当前 command snapshot 工作，optional feature 默认关闭。
- 至少 15 个账号竞态、旧客户端、错误 fallback、cache 隔离和 canary 故障场景。
- 增加对应 Product Spec 章节、Evidence Matrix 状态和静态门禁。

## Verification Plan

- 对照独立 iOS reviewer 的 6 个 blocker/5 个 high 逐项映射到目标修复 wave。
- 静态门禁检查 Actor/Lease/store envelope/typed route/no fallback/credential removal/capability/cohort/rollback。
- 独立 reviewer 攻击 refresh 覆盖、callback 跨账号、legacy global store、404 fallback 和旧客户端写入。
- 运行全部 Product V4 门禁和 `git diff --check`。
- 本轮不修改生产 iOS/后端代码、不构建/真机；XCTest/concurrency/upgrade matrix 是路线图 Stage 0 实施证据。

## Risks

- 当前没有 XCTest target，很多竞态只能先冻结合同，不能以源码静态检查证明已修复。
- 活跃客户端版本、旧本地数据分布和 LocalConfig 进入 Release 的真实情况未知。
- 强身份 provider 和生产 AuthZ enforce 尚未实现；客户端 rollout 不能代替后端安全门。
- 一次性改造所有 store 风险过高，应先抽统一 lease/envelope，再分域迁移。

## Assumptions

- 保留 UIKit/Stitch 三 Tab 和现有页面视觉，不为迁移重写 UI。
- Round 3B `/v2`/AuthZ 与 Round 3C1 authorityEpoch/data waves 是服务端合同输入。
- Optional Family/Care/TimeLetter/Voice/DH 独立 rollout，不能阻断 Owner 文字核心。
