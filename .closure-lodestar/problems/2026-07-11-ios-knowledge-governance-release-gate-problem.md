# iOS 知识治理 Release QA 组合 Gate

## Problem

iOS governance model/client/outbox/coordinator 检查已存在但尚未纳入 release QA package，后续修改可能绕过 identity、operation ID 或公开 UI 边界。

## Success Criteria

- release QA package 默认执行 governance model/client/coordinator 轻量 guard。
- release regression 新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 可选组合开关，运行完整 iOS governance/outbox/three-way smoke 和后端 runner。
- 静态 guard 证明公开 UI 没有新增治理入口或治理状态文案。
- 标准 release QA、开启组合 gate、Simulator Debug workspace build 和 generic iPhoneOS 无签名 build 通过。
