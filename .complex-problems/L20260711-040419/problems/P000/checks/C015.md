# Task 16 知识治理与来源删除级联成功检查

## Summary

R015 由四个已独立成功检查的主子问题汇总，Task 16 的全部原始成功标准均有代码、自动化回归、构建和交付证据。剩余项均明确属于公开体验、历史迁移或部署生产化，不应阻塞本任务关闭。

## Evidence

- C000：后端治理 builder/endpoint 对四类 action、稳定 replacement、owner/persona/revision/timestamp 和幂等完成验证。
- C005：Archive 归属、source cascade、memory/Postgres 组合事务及 Context 行为完成验证。
- C010：iOS 模型/client/outbox/coordinator、权威 graph 应用和旧 user/persona 回调隔离完成验证。
- C014：跨仓库 gate、旧合同兼容、release regression、两种构建、文档和提交完成验证。

## Criteria Map

- 四类动作由 snapshot 生成 Mutation V2：满足。
- correct 保留旧实体并创建 replacement，旧实体不进 Echo：满足。
- 删除来源后直接引用实体不再可生成：满足。
- owner/persona/revision/operation/timestamp 与跨账号拒绝：满足。
- iOS 权威 graph 应用和旧身份回调隔离：满足。
- 旧 mutation/proposal/merge/evidence/Context 兼容：满足。
- 非真机 release regression 和 generic iPhoneOS build：满足。

## Execution Map

- R000/R005/R010/R014 对应四个主子问题。
- R015 汇总根任务结果。

## Stress Test

- 后端覆盖 correction 非法字段/关系、missing source/target、跨 owner、revision conflict、重复 operation、SQL 中途失败与回滚。
- iOS 覆盖非法 schema/correction、损坏 outbox、账号/角色切换、409 重放和公开 UI 误暴露。
- release regression 捕获并修复 route count 与 Archive helper 架构变化造成的陈旧 QA 断言。

## Residual Risk

- 公开治理 UI、legacy sourceRef 迁移、payload hash、change feed compaction、真实 Postgres/部署/真机均已在 canonical 和状态文档中明确列为后续，不影响 Task 16 的非真机基础设施闭环。

## Result IDs

- R015
