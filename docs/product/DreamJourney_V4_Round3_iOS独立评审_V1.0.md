# DreamJourney V4 Round 3 iOS/客户端独立架构评审

版本：V1.0
日期：2026-07-12
状态：独立只读评审输入；尚未经过主控 disposition
范围：Product Spec 22/25/29/30/34、Evidence Matrix 第 6 节和指定 iOS 源码；未修改工作区

## 1. 结论摘要

- `BLOCKER`：2 项（IAR-02、IAR-03）。
- `HIGH`：5 项（IAR-01、IAR-04、IAR-05、IAR-06、IAR-07）。
- 核心判断：V4 的 AccountLease、owner-scoped store、server-derived principal、typed route、runtime port 和组合迁移方向总体正确，但当前 iOS 仍存在跨账号状态、客户端 principal、legacy owner 自动认领和 UI/runtime 高耦合风险。
- 本报告是独立异议来源，不表示主控已经接受全部结论；Round 3D4 必须逐项响应。

## 2. Findings

### IAR-01 — HIGH：账号切换与认证会话竞态

- **分类**：实现缺口；目标设计正确但尚未落地。
- **源码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/UserManager.swift:31-47,127-145,167-178`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:3738-3763`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/BackendAuthSessionStore.swift:53-60,68-85`
- **Spec**：22.0、22.6、29.1-29.3。
- **问题/影响**：`UserManager` 主要串行化同步切换副作用；profile、archive、refresh 等异步请求没有统一 account generation/lease。`BackendAuthSessionStore` 是单例且使用单一 `current-auth-session` Keychain key，`save` 可覆盖当前 session，`clear` 的可选 sessionId 保护不足以阻止旧异步流程覆盖新账号。logout 也未证明取消全部旧任务。
- **建议**：引入 `AccountSessionActor/AccountLease`；所有 callback、timer、refresh、repository 写入执行 generation checkpoint/CAS；switch/logout 先失效旧 lease，再取消旧任务。

### IAR-02 — BLOCKER：Archive Store owner 边界

- **分类**：实现缺口，当前实现存在高风险 legacy 行为。
- **源码证据**：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift:210-227,640-669,756-785,876-914`。
- **Spec**：22.4、22.5、29.4、34.9。
- **问题/影响**：legacy item 存在自动认领；未登录时可回退固定 `user_001`；archive owner 又可来自 `DigitalHumanContextStore`，不必等于当前 authenticated subject。远端 merge 未证明再次强制 owner/epoch/generation 过滤，可能造成跨账号显示、写入或错误迁移。
- **建议**：所有 store 注入不可变 `AccountContext`；owner 不匹配 quarantine/fail closed；禁止自动认领与 `user_001` fallback；远端 merge 校验 owner、authorityEpoch 和 generation。

### IAR-03 — BLOCKER：客户端 principal 与共享 token fallback

- **分类**：实现缺口，当前实现违背目标 AuthZ 边界。
- **源码证据**：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:2551-2562,2632-2644,3638-3648,3835-3847`。
- **Spec**：25.0-25.5、25.8-25.10、30.0-30.6。
- **问题/影响**：客户端仍支持共享 API token 并可作为 Bearer；多类 API payload 仍传 `userId/viewerUserId`。客户端可声明 principal，无法满足服务端由 verified session 派生 owner、禁止 shared system token 的目标合同。
- **建议**：移除客户端长期/shared token 与 Bearer fallback；subject/owner 从服务端 session 派生；按域拆 typed client；旧 facade 仅兼容读取，不满足 AuthZ 时 read-only/upgrade-required。

### IAR-04 — HIGH：Echo/Digital Human runtime 未绑定 AccountLease

- **分类**：实现缺口；生命周期方向正确但边界尚未完整。
- **源码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift:14-20,91-112,175-203`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Echo/EchoViewController.swift:722-734,1483-1551,2302-2365`
- **Spec**：22.1、22.2、22.5、22.6。
- **问题/影响**：已有 generation/context guard，是可复用保护；但 runtime token 未显式携带 account/session generation，coordinator 也没有明确 actor/线程约束。ViewController 直接协调 backend、provider runtime、session lease 和 UI，账号切换及后台恢复仍依赖调用纪律。
- **建议**：runtime token 绑定 `AccountLease + conversation/profile generation`；coordinator 标记 `@MainActor` 或独立 actor；session/voice/provider 命令移入 runtime/application port。

### IAR-05 — HIGH：Feature Flag 默认开放与 Widget 生命周期证据不足

- **分类**：文档目标与当前实现冲突；Widget 为部分正确实现但验收不足。
- **源码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/App/FeatureFlagService.swift:30-60,83-96`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift:53-89,111-145`
- **Spec**：22.3、22.4、22.5、34.8。
- **问题/影响**：Care/Family/TimeLetter/VoiceClone/DigitalHuman 等 flag 默认开启并持久化，违反 Future/Beta 默认关闭和服务端 policy Authority。Widget digest/generation 校验较好，但使用单一 App Group 文件名；本次范围内没有证明 account switch/logout 能原子失效旧快照。
- **建议**：改为服务端 `ReleasePolicy` + TTL，离线默认 deny；Widget 使用 owner/generation envelope，并由统一 account lifecycle 在 login/switch/logout 原子 invalidate。

### IAR-06 — HIGH：旧客户端迁移仍可能形成双 Authority

- **分类**：实现缺口；目标迁移设计正确，当前仍为 legacy 双轨。
- **源码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift:230-245,619-631`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:3638-3664`
- **Spec**：22.5-22.7、30.8-30.10、34.5、34.8。
- **问题/影响**：Archive add/update 仍可直接 backend sync；client 仍大量使用 raw `[String: Any]` facade，没有 `/v2` typed route、min-client、epoch 或旧客户端只读降级。若直接迁移会形成 legacy/V4 双写或双读。
- **建议**：先建立 typed client/contract tests；旧入口全部经 facade；authority cutover 后旧客户端只读并拒绝 direct write，旧 callback 不得写新 store。

### IAR-07 — HIGH：Echo ViewController 职责过载

- **分类**：实现缺口与过度设计风险；目标分层尚未落地。
- **源码证据**：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Echo/EchoViewController.swift:2302-2365,5665-5810`。
- **Spec**：22.1、22.2、22.5、22.6。
- **问题/影响**：ViewController 同时承载 UI、账号读取、backend session、provider runtime、lease heartbeat/release、UIQA smoke 和 fallback，扩大生命周期竞态面且难以单测，也阻碍 Digital Human 作为可选 runtime 从 Owner QA 核心隔离。
- **建议**：ViewController 只发送 Intent/渲染 ViewState；分离 conversation application、DH runtime adapter、lease client 和 QA harness；保留已有 lifecycle guard，但缩小调用者集合。

## 3. 压力测试建议

同时启动账号 A 的 Echo/DH 会话、Archive sync 和 401 refresh；在 callback 延迟期间执行 logout、切换账号 B，再发布 Widget snapshot。断言：

- A 的 callback 不能写 B 的 store。
- 旧 token 不能覆盖或刷新 B 的 session。
- 旧 DH lease 被释放且不能恢复旧角色 runtime。
- Widget 不保留 A 的可见快照。
- 旧客户端只能进入只读/升级错误，不能走 legacy direct write。

## 4. 残余风险

- 本报告未审查后端、Widget extension 全部调用链和真实 Provider。
- 指定文件之外可能仍有 owner 写入、global store、通知或 runtime 路径。
- 当前尚无统一 XCTest target、账号 A/B、crash recovery 和旧客户端迁移生产证据。
- 上述限制不会降低 IAR-02/IAR-03 的严重度；只限制本报告对全仓“除此之外无风险”的证明能力。
