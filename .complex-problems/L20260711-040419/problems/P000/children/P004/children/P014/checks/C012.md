# iOS 知识治理 Release QA 组合 Gate 成功检查

## Summary

R012 满足 P014 的全部 gate、公开边界和构建标准。完整 release regression 在修复两个由 Task 16 引起的旧 guard 漂移后通过，最终脚本和 package 再次检查无误。

## Evidence

- 日常 regression 明确运行 governance model/client/coordinator/boundary 四条轻量 guard。
- `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 调用完整 iOS 管线和后端 deterministic runner。
- boundary guard 扫描公开 Modules/App，当前只有 Services 定义 `performGovernance`。
- v4 release report 显示治理 gate=1，Simulator build 与 generic iPhoneOS build 均成功。
- 后端 verify 243 tests，治理组合 217 tests，package 和 diff checks 通过。

## Criteria Map

- release QA package 声明治理资产：满足。
- 默认轻量 governance guard：满足。
- 可选跨仓库组合 gate：满足。
- 公开 UI 非暴露：满足。
- package/regression/Simulator/generic iPhoneOS：满足。

## Execution Map

- R012 对应 QA 资产、release 集成、兼容 guard 修复和构建证据。

## Stress Test

- release regression 实际捕获并修复了路由数 56 -> 57 和 Archive delete helper 搬迁两处陈旧断言，证明 gate 能发现跨仓库合同漂移。
- 组合 gate 覆盖 outbox 损坏、revision conflict、跨 owner、事务回滚和 Context 排除。

## Residual Risk

- v4 生成报告的说明文本仍记录旧路由数 56，但生成脚本已修正为 57，route guard/deployed smoke/package 均已重新通过；这是证据文案时点差异，不是代码或 gate 缺口。
- 不包含交互式模拟器、真机和部署 Postgres，符合问题范围。

## Result IDs

- R012
