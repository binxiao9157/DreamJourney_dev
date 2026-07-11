# 将 Widget 隐私生命周期纳入发布回归并收口文档

## Problem

现有 release QA 没有覆盖 Widget 授权、跨账号清理、generation 竞态、provider fail-closed 或扩展工程配置，后续知识库改动可能重新引入隐私泄露。

## Success Criteria

- 增加静态 gate 检查 privacy allowlist、最小快照、账号清理/reload、provider 校验、entitlement、bundle ID 和扩展嵌入。
- 将模型 smoke 与静态 gate 接入 release QA package/release regression，默认执行且不依赖真机。
- `git diff --check`、相关 smoke、release QA、release regression、Simulator build 和 generic iPhoneOS build 全部通过。
- 更新 Task 21、PRD 覆盖/状态与进度文档，明确已完成证据和真机/App Group Portal 剩余外部门槛。
- 关闭 Task 21 Closure 账本并提交推送当前 iOS 分支。
