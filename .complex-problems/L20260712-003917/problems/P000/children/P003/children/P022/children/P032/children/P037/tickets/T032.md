# Round 3C2A iOS AccountSession、Generation 与本地 Store 迁移方案

## Problem Definition

当前 iOS 使用 `UserManager`、Keychain session、全局 refresh、各 feature 自有 generation 和大量 UserDefaults/文件目录共同表达“当前账号”。这些状态不原子：冷启动可只有本地 user、A refresh 可覆盖 B session、A Archive callback 可按完成时的当前账号写入 B，Memoir/Memory/Voice/TTS 等全局 store 可跨账号命中。需要一个不改变 UIKit/Stitch UI 的统一账号生命周期和本地数据迁移合同。

## Proposed Solution

在 Product Spec 增加 iOS Account/Store rollout 章：

1. 定义 `AccountSessionActor` 状态机：`signedOut/reconciling/authenticating/active/refreshing/switching/revoked/deletionPending`。
2. 定义不可变 `AccountSessionSnapshot` 与 `AccountLease`，包含 subject/vault/principal/session/tokenFamily/accountGeneration/authorityEpoch/policy snapshot；每次账号身份变化单调增加 generation。
3. 冷启动只以可由后端验证的 Keychain session 为身份 Authority；本地 UserModel/Profile 仅作缓存。session 缺失/无效不进入业务页，cache mismatch 在验证后替换而不是让本地 user 覆盖 session。
4. refresh 对 `sessionId + tokenFamilyId + generation` single-flight/CAS；切换或 logout 后旧 refresh/result/retry 只能丢弃，不能保存或改 UI。
5. request/task/timer/callback 捕获 lease，在发送、401 retry、decode、use-case apply、store commit、UI publish 前验证；账号切换顺序固定为 rotate generation → cancel/close old work → unmount old stores → verify new session → mount new scope → publish UI。
6. 建 `AccountScopedStoreRegistry` 和版本化 envelope，覆盖 Draft/Archive/KBLite/Conversation/Memoir/Memory/DelayedReply/Inbox/Voice/TTS/DH/Receipt/Export/Widget/Notification/Policy 等状态。
7. legacy 数据按 `owner-proven migrate / rebuildable purge / runtime purge / unclaimed quarantine` 处理；禁止 `legacy_unassigned`、昵称或最后登录账号自动认领。
8. 草稿只在本地 Account Scope；显式 submit/seal 后才由服务端创建 Source/TimeLetter command receipt。
9. 实施顺序先新增 XCTest target 与 deterministic clock/fake session/store tests，再引入 Actor/Lease，最后按域迁移 store；现有页面和三 Tab 不重写。

## Acceptance Criteria

- Product Spec 明确当前 6 个 blocker/5 个 high 的文件级证据与目标归属。
- `AccountSessionSnapshot/Lease` 字段、不变量、CAS、状态机和生命周期顺序完整。
- 冷启动、登录、refresh、switch、logout、revoke、delete、前后台均有 fail-closed 行为。
- 至少 15 类本地 store/runtime/cache 有 Authority、scope key、legacy migration、switch/logout/delete 行为。
- 每个异步阶段校验 lease，禁止旧 generation 保存 session、写 store、发布 UI 或恢复 runtime。
- store envelope 不含原始 subject/phone，使用 digest + schema/authorityEpoch/payload hash；Keychain secret 不进入普通文件。
- TimeLetter/Archive draft 不在封存/提交前 sync 后端。
- Widget/App Group、通知和导出文件纳入同一账号撤销/清理边界。
- 至少 15 个冷启动、竞态、切换、升级、清理和 crash recovery 场景。
- 新增 `product-v4-ios-account-store-rollout-check.py`，Evidence Matrix 保持 `DESIGNED/NOT_IMPLEMENTED`。

## Verification Plan

- 静态门禁检查状态机、字段、15 类 store、生命周期矩阵和场景数量。
- 对照 reviewer 文件证据验证每个 blocker/high 都有 wave/acceptance 归属。
- 独立 reviewer 攻击 A-refresh/B-login、A-callback/B-store、global cache、draft sync、widget/notification 和 crash point。
- 运行全部 Product V4 门禁与 `git diff --check`。
- 本轮不修改生产 Swift、不创建 XCTest target或构建 App；这些是路线图 Stage 0 实施任务。

## Risks

- 本地 legacy 数据无法普遍证明 owner；安全结果可能是隔离/删除而不是自动迁移。
- 多 singleton 一次替换风险高，必须用 adapter/registry 分域 strangler，不能建立另一个 ServiceLocator。
- 保存 Keychain 与挂载 store 无法跨介质原子，需以可重放状态机和冷启动 reconciliation 恢复。

## Assumptions

- 后端 subject/vault/session 是身份 Authority，`UserManager` 不再决定是否已认证。
- local draft 可保留为加密 owner-scoped 数据，但 account delete 必须清除；最终 logout retention UX 属产品策略。
- iOS 视觉以当前 Stitch/实现为准，本轮只设计数据流和生命周期。
