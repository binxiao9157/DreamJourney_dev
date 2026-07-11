# 知识变更流稳定分页完成状态

日期：2026-07-11

## 结论

Task 18 已完成非真机代码闭环。知识变更流由一次性读取升级为向后兼容的稳定目标水位分页；iOS 仅在完整终页验证后提交权威图谱，并通过 KBLite graph CAS 保留分页期间产生的本地知识。公开 UI、Stitch 页面和 Echo 文案未改变。

## 后端合同

- 旧客户端不传 `limit` 时继续获得原 `userId / sinceRevision / currentRevision / changes` 完整响应。
- 新客户端传 `limit` 时，首请求以当时 revision 固定 `targetRevision`。
- 后续请求携带相同 target，只读取 `sinceRevision < revision <= targetRevision`。
- 分页响应增加 `targetRevision / nextSinceRevision / hasMore / pageLimit`。
- `limit` 范围为 1...100；revision 必须满足 `0 <= sinceRevision <= targetRevision <= current revision`。
- Memory 与 Postgres 都按 revision 升序、目标上界和页大小读取。
- 固定 target 后产生的新 revision 不会进入当前分页轮次；无进展的非终页作为 revision gap 拒绝。

## iOS 提交语义

- `KnowledgeChangePage` 严格校验用户、连续 revision、完整分页字段、稳定 target、页尾水位和 mutation metadata。
- `KnowledgeChangeFeedReducer` 限制最大页数，只保留最终权威图谱，不累计全部 graph body。
- Coordinator 的正常同步和 409 refresh 共用分页状态机；`userId + generation + pullSessionId` 共同隔离旧回调。
- 中间页不写 remote base、不清 pending、不写 KBLite、不发送本地 mutation/governance。
- 终页才执行三方 merge；KBLite graph mutation token 变化时重新读取本地 graph 并有限重算，避免覆盖分页期间的新知识。
- 旧后端缺少分页字段时，仅接受为单页终态，保持兼容。

## QA

单独运行分页组合门禁：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-knowledge-change-feed-pagination-gate.sh
```

该门禁覆盖：

- iOS 三页 reducer、legacy 单页、revision gap、空非终页、target 漂移、页数上限和 CAS policy。
- Coordinator typed client、终页前无副作用、409 共用分页、generation/pull session 隔离和 CAS 重算合同。
- 后端 memory/Postgres bounded query、稳定 target、并发新增、非法参数和原知识 delta smoke。
- Release regression 默认执行该跨仓门禁，QA package 静态检查防止入口丢失。

## 发布边界

- 后端功能提交 `cacf7dd` 已推送并部署；可重复 deployed smoke 提交 `be5587c` 已推送且服务器目录已同步。
- iOS 在本轮完成提交推送，但没有执行真机验证。
- 本轮不包含 change feed 保留/compaction、snapshot fallback 或中间页恢复 journal。
- 上线前仍需部署新后端，并在真实 Postgres 运行分页 smoke。
- 历史 canonical sourceRef 迁移、timeLetter 草稿字段收敛和公开知识治理体验仍是后续任务。

## 本轮验证

- 后端全量：254 tests、compile、FastAPI、knowledge delta/v2/evidence smoke 通过。
- 跨仓分页 gate：通过。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task18-knowledge-change-feed-pagination/report.md`。
- Simulator workspace Debug build：通过。
- generic iPhoneOS arm64 build：通过，未连接真机。
- 线上 Postgres deployed smoke：通过；`stablePaginationVerified=true`、`postTargetRevisionExcluded=true`。
- 线上健康检查：`store=postgres`；API 容器运行正常。
- Closure ledger：`L20260711-104956` 已关闭。
