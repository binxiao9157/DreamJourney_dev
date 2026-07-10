# P1 知识删除与三方合并总结果

## Summary

P1 已从后端 Mutation V2、iOS 每用户三方合并到跨仓库 release gate 完整闭环，同时保持 v1 客户端/旧后端兼容。

## Done

- P001：后端四类实体 upsert/tombstone、Postgres metadata、revision/operationId 幂等与 v1 兼容完成。
- P002：iOS per-user base、pending payload、三方合并、local-only 保护、v2 delta 与选择性 v1 fallback 完成。
- P003：部署形态 V2 smoke、release 组合 gate、状态文档和两仓库独立提交完成。

## Verification

- 子结果 `R000`、`R001`、`R002` 均通过独立 success check。
- 后端 195 项单测及所有本地 smoke 通过。
- iOS 模型/静态/release QA、跨仓库组合 gate 与 generic Simulator/iPhoneOS build 通过。
- 两仓库 `git diff --check` 通过。

## Known Gaps

- 提交尚未推送和部署，公网 Postgres V2 smoke 待部署后执行。
- 冲突为实体级 local-wins，未实现字段级 CRDT 或公开冲突 UI。
- change feed 分页、保留周期和 compaction 未纳入本轮。

## Artifacts

- R000：后端 Mutation V2 结果。
- R001：iOS 三方合并结果。
- R002：跨仓库 QA 与交付结果。
- `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-07-11-knowledge-tombstone-three-way-merge.md`
