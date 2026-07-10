# 跨仓库 QA、构建与交付收敛

## Problem

新 proposal/persona 合同需要可重复的跨仓库证据，且不得破坏既有知识与公开 release 回归。

## Success Criteria

- 新增后端/iOS smoke 和 release 可选组合 gate。
- 后端全量测试、既有 knowledge gates、release regression、generic Simulator/iPhoneOS build 和 diff check 通过。
- 状态文档、ledger 和两个仓库的独立提交完整，且不推送、不部署、不做真机。
