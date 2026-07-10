# 统一知识管线验证与交付收敛

## Problem

知识库变更跨两个仓库和多条异步链路，需要统一验证合同、release gate、状态文档和回归证据，否则后续修改容易重新形成双轨或跨用户泄漏。

## Success Criteria

- 后端全量测试、知识 mutation/change-feed smoke 和 Context V2 smoke 通过。
- iOS 用户隔离、同步/提取、Echo context smoke、release regression 和 generic iPhoneOS build 通过。
- 两仓库 `git diff --check` 通过，未提交改动按模块清楚列出。
- 状态文档记录真实实现、兼容边界、验证命令和后续 P1/P2，不夸大为向量检索完成。
