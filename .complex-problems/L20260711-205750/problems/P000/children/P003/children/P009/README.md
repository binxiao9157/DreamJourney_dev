# Receipt 最小化跨仓 Gate 与非真机构建

## Problem

iOS release 流程尚未固定后端 receipt 最小化、maintenance 默认 dry-run 和组合 smoke 合同，需要跨仓 gate、状态文档和两类非真机构建证据。

## Success Criteria

- 新增跨仓 static check 和 runner，检查后端核心 helper、CLI、smoke 与运维文档。
- 接入 release regression 和 release QA package。
- 更新 Task 26 状态文档、PRD/知识库覆盖和验证命令。
- 跨仓 gate、默认 release regression、release QA package check 通过。
- Simulator 和 generic iPhoneOS 构建、双仓 diff check 通过。
- 不修改公开 UI、不做真机。
