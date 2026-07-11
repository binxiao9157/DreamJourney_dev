# iOS Governance 串行提交与 Generation Gate 成功检查

## Summary

R008 覆盖了 P012 的全部成功标准。治理请求现在具备持久化先行、单一网络 owner、revision conflict 重放、权威响应合并和 user/persona generation 防污染机制，且目标 workspace 已完整编译。

## Evidence

- `KnowledgeSyncCoordinator.performGovernance` 在 `governKnowledge` 之前调用 `governanceOutboxStore.enqueue`。
- `startNextGovernance` 与普通同步共用 `isSyncing` 和 `syncGeneration`。
- 409 分支保留 outbox 与 `item.operationId`，通过 `governanceRevisionConflict` 先刷新基线。
- 同 persona 成功分支先 `applyAuthoritativeRemote`，之后才删除 outbox；角色已变化分支不应用旧 graph，改走 `governancePersonaChanged` 增量同步。
- 五条治理/合并脚本通过，DreamJourney workspace Simulator Debug 构建成功。

## Criteria Map

- `performGovernance` 与 outbox 先写后发：已满足，由 coordinator 静态合同检查覆盖。
- 普通 sync/governance 不并发，成功、失败、409 正确推进：已满足，由单一 `isSyncing` gate、明确分支和静态检查覆盖。
- 同 operation ID 重试，成功删除 outbox 并保存 base：已满足，operation ID 来自持久化 item，删除发生在权威合并和 base 保存之后。
- 旧 user/persona callback 不污染当前图谱：已满足，user generation 直接失效；persona 变化时只确认远端结果并重新拉 change feed。
- static/model smoke 和 Simulator build：已满足。

## Execution Map

- 执行结果：R008。
- 代码产物：`KnowledgeSyncCoordinator.swift`。
- QA 产物：`knowledge-governance-coordinator-check.swift` 及 runner。
- 构建证据：`/tmp/dreamjourney-task16-coordinator-workspace-build.log`。

## Stress Test

- 检查了最可能破坏数据边界的三个路径：409 revision conflict、请求期间 persona 切换、请求期间 user 切换。
- 额外复核了 Archive 无知识引用时的零命中删除；该路径返回 Archive cascade 合同而非治理响应，不与 iOS 严格治理响应模型冲突。

## Residual Risk

- 未在本问题内连接部署后端执行网络 smoke；该风险已明确归属 P004 跨仓库 QA，不阻塞 P012 的 iOS 协调器实现成功。
- 当前没有公开治理 UI，符合本问题范围。

## Result IDs

- R008
