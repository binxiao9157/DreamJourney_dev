# P1 知识删除与三方合并成功检查

## Summary

R003 汇总的三个子闭环已全部通过独立检查，并满足根票对后端原子 delta、iOS 三方合并、隐私边界、兼容性和非真机验证的要求。

## Evidence

- P001/P002/P003 分别由 `C000`、`C001`、`C002` 判定成功。
- 后端 195 项测试、FastAPI、v1/v2 smoke 通过。
- iOS 模型 smoke、静态/QA checks、release 组合 gate、generic Simulator 和 generic iPhoneOS build 通过。

## Criteria Map

- InMemory/Postgres v2 原子应用、幂等、409：P001 覆盖。
- change feed v1/v2 兼容与权威 graph：P001/P002 覆盖。
- per-user base、三方合并、delta：P002 覆盖。
- local-only/无授权实体保护：P002 模型与主控审查覆盖。
- 单边更新/删除、双方编辑/删除冲突、malformed feed、用户切换：模型与现有 generation guard 覆盖。
- v1 smoke、release regression、generic iPhoneOS：P003 与最终构建覆盖。

## Execution Map

- 后端负责权威 revision、mutation 与变更历史。
- iOS 负责本地/远端三方决策和稳定 pending 重试。
- release gate 将纯模型与部署形态 HTTP 合同串联。

## Stress Test

- 编辑与删除双向冲突均确定性 local-wins，并留下不含正文的 QA evidence。
- localOnly 与远端同 ID 时不会上传、误删或被覆盖。
- stale v1 sync 不能恢复 tombstone，重复 v2 operation 不重复执行。
- 旧服务端只在明确合同不支持时 fallback，一般校验错误保持可见。

## Residual Risk

- 未推送/部署，因此线上 Postgres gate 仍是上线前必跑项，不影响本轮本地实现完成判定。
- 字段级 CRDT、公开冲突 UI 和 change-feed compaction 留作后续独立规划。

## Result IDs

- R003
