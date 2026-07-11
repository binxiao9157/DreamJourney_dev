# 跨仓库治理 QA 与交付收敛

## Problem

治理和来源级联横跨后端 snapshot、iOS 同步、Context 过滤与 Archive 生命周期；缺少组合 gate 会让任一层后续改动重新放出 rejected/superseded 知识。

## Success Criteria

- 后端 smoke 覆盖四类动作、source cascade、权限、revision 和 change feed。
- iOS 模型/静态 smoke 覆盖请求编码、权威响应、identity gate 和公开 UI 不误暴露。
- release regression 提供可选组合开关，日常检查至少运行轻量 guard。
- 后端全量验证、Simulator/iPhoneOS generic build、diff check 通过。
- canonical 设计、状态、Task 16 和 Closure Ledger 完整记录证据与剩余边界。
