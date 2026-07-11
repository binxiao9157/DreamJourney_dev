# 固化后端 Knowledge Governance Source Cascade Gate

## Problem Definition

`tests/test_knowledge_governance.py`、Archive store 测试和 fake Postgres 测试已证明核心代码，但缺少稳定 shell runner，release regression 无法用一个开关复用这些证据。

## Proposed Solution

在后端 `scripts/` 新增知识治理与来源级联 smoke runner，显式用 unittest 加载治理、Archive ownership、Context 和 fake Postgres 测试，不读取真实 Postgres DSN。runner 先做 compileall，再执行确定性的测试集合，并输出可被 iOS release regression 调用的单一退出码。

## Acceptance Criteria

- runner 覆盖四类治理动作、revision conflict、幂等、跨账号拒绝和 change feed。
- 覆盖 Archive ID 跨 owner 冲突、删除与治理 snapshot 的 memory/fake Postgres 组合事务。
- 覆盖 rejected/superseded Context 过滤与 replacement 注入。
- runner 可从后端仓库直接运行，也可由 iOS 仓库传入后端路径调用。
- 后端 compileall、目标测试集合与 `git diff --check` 通过。

## Verification Plan

运行新增 runner；再运行后端现有 deterministic 全量验证脚本（如存在）和 fake Postgres 测试，核对无真实数据库依赖。

## Risks

- 直接使用 unittest class/method 名容易随测试重命名失效；优先运行完整相关模块，保持覆盖与维护成本平衡。
- 后端全量 discovery 默认可能连接真实 Postgres，不能把环境错误混入组合 gate。

## Assumptions

- 当前治理实现和测试改动尚未提交，但均位于 DreamJourneyBackend 工作区。
- 本问题不部署线上服务。
