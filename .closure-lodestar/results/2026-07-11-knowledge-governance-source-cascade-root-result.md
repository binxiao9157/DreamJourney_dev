# Task 16 知识治理与来源删除级联总结果

## Summary

Task 16 已完成非真机全闭环：后端权威治理、Archive 来源删除组合事务、iOS 强类型 consumer 与 durable outbox/coordinator、Context 排除证明、跨仓库 release gate、文档和本地提交均已落地。

## Done

- P001：四类治理 action、状态转换、纠正 allowlist、稳定 replacement、owner/persona/revision/timestamp 约束。
- P002：Archive ID 跨 owner 保护、sealed timeLetter 边界、memory/Postgres 同事务档案删除与知识 `deleteSource` 级联。
- P003：iOS typed action/response/metadata、backend client、per-user outbox、409 同 operation 重试、user/persona generation gate。
- P004：后端 217-test gate、iOS release boundary/组合 gate、243-test backend verify、Simulator/generic iPhoneOS build、canonical/status 文档和双仓提交。
- rejected/superseded 继续被 Context 过滤，correct replacement 可进入目标 persona。

## Verification

- 子问题检查 C000、C005、C010、C014 全部成功。
- Backend commit `3057ef9`；iOS commit `69306c1`。
- release regression：`20260711-task16-knowledge-governance-v4` 成功。
- `git diff --check`、release QA package、敏感凭据模式检查通过。

## Known Gaps

- 未开放公开治理 UI；需后续 PRD/Stitch 决策。
- 历史 `archiveImageAnalysis/session-*` 到 canonical `memoryArchiveItem/archive-id` 的迁移未做。
- operation payload hash、change feed compaction、真实 Postgres deployed smoke、线上部署和真机不在本任务范围。

## Artifacts

- `docs/plans/task_16_p1-knowledge-governance-source-cascade.md`
- `docs/superpowers/status/2026-07-11-knowledge-governance-source-cascade.md`
- `docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`
- Backend `3057ef9`
- iOS `69306c1`
