# iOS Governance 串行提交与 Generation Gate 结果

## Summary

已将知识确认、拒绝、纠正和来源删除动作接入现有 `KnowledgeSyncCoordinator`，治理动作与普通知识同步共用同一串行网络所有权。请求先持久化到用户隔离 outbox，再发送后端；权威响应成功合并并保存 revision 后才删除 outbox。

## Done

- 新增 `performGovernance` 协调入口，并在请求前校验后端会话、当前用户、KBLite 已加载用户与 persona identity。
- 使用 `isSyncing` 和 `syncGeneration` 复用现有串行网络 gate，避免普通同步和治理请求并发写图谱。
- 409 revision conflict 保留原 operation ID 与 outbox，先刷新权威基线，再自动重试。
- 后端成功后再次校验 persona identity；角色已变化时不直接应用旧角色响应，改走普通增量同步恢复。
- 同 persona 响应通过现有三方合并落地，并在本地图谱和远端基线持久化成功后移除 outbox。
- 账号切换会失效旧 generation，并通过明确错误结束旧 completion；服务端结果仍可依靠同 operation ID 幂等恢复。
- 新增 outbox 损坏清理日志和 QA-only pending count，不记录知识正文。
- 新增 coordinator 静态合同检查脚本。

## Verification

- `run-knowledge-governance-coordinator-check.sh` 通过。
- `run-knowledge-governance-model-smoke.sh` 通过。
- `run-knowledge-governance-client-check.sh` 通过。
- `run-knowledge-governance-outbox-model-smoke.sh` 通过。
- `run-knowledge-three-way-merge-model-smoke.sh` 通过。
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` 通过。

## Known Gaps

- 本 ticket 未连接真实后端执行治理请求；部署态 smoke 和 release regression 接入由 Task 16 的跨仓库 QA 问题处理。
- 暂未增加公开治理 UI，符合当前 Task 16 的合同与基础设施范围。

## Artifacts

- `DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift`
- `Scripts/QA/prd-stitch-ui/knowledge-governance-coordinator-check.swift`
- `Scripts/QA/prd-stitch-ui/run-knowledge-governance-coordinator-check.sh`
- `/tmp/dreamjourney-task16-coordinator-workspace-build.log`
