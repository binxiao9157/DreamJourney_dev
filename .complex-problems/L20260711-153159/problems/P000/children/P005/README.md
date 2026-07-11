# 将家庭授权边界纳入发布回归并收口文档

## Problem

现有 QA 分散验证 family UI、Context 和知识同步，没有一个默认 gate 能证明 KBPerson、账号切换、relation spoof、未授权 sync/import 均 fail closed，也没有同步产品覆盖矩阵。

## Success Criteria

- 新模型/static/组合 gates 进入默认 release regression 和 release QA package。
- 现有后端 family/context 测试证明 pending/failed/revoked 拒绝、accepted 放行。
- release QA、完整 regression、Simulator/generic iPhoneOS build 与 diff check 通过。
- canonical 知识架构、PRD coverage、release matrix 和 Task 22 状态说明一致。
- 按实际变更提交推送；需要后端变化时部署并跑 Postgres smoke，否则记录后端无行为变化依据。
