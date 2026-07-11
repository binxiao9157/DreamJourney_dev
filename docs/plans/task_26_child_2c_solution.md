# 固化 Receipt Maintenance 组合 Smoke 与运维说明

## Problem Definition

单项测试已证明转换和 Postgres 维护，但仍需显式证明 compact receipt 与 privacy maintenance、change-feed compaction、duplicate replay 能组合工作，并给部署人员一套先 dry-run、后 apply 的安全顺序。

## Proposed Solution

新增后端一键 receipt maintenance smoke，运行 receipt 纯函数/Postgres/隐私维护/change-feed compaction/核心 duplicate 测试及 CLI help；将其接入 `verify_backend.sh`。补后端部署文档，明确 reader-first 部署、dry-run 报告字段、异常停止条件、分批 apply、二次幂等、WAL/表膨胀/vacuum 观察和回滚边界。增加静态 smoke 断言维护脚本默认无 `--apply`。

## Acceptance Criteria

- 一键脚本覆盖 receipt 转换、Postgres dry-run/apply、compact privacy compatibility、change-feed receipt barrier 和 duplicate replay。
- `verify_backend.sh` 显式运行该 smoke。
- CLI help 和默认 dry-run 合同由脚本检查。
- 运维文档说明部署顺序、dry-run 审阅字段、apply 前置条件、失败处理、幂等复跑和数据库观察项。
- 组合测试不依赖真实 Postgres，不输出知识正文。
- 后端全量回归、py_compile、diff check 通过。

## Verification Plan

运行新增一键 smoke、`STORE_BACKEND=memory scripts/verify_backend.sh`、CLI help、grep 确认文档/脚本接入和 `git diff --check`。

## Risks

- Fixture smoke 不能替代线上 Postgres；文档必须明确 P003 先 dry-run 后 apply。
- 不应在本轮自动执行 production apply 或删除 receipt 行。

## Assumptions

- P005/P006 已通过本地验收。
- 线上部署和真实 Postgres 证据由 P003 最终收口。
