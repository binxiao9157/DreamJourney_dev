# 跨仓隐私 QA、构建与提交发布

## Problem

canonical mutation 与历史维护工具尚未被现有 release QA package 固化，也没有形成可部署的双仓提交。需要在不改变公开 UI 的前提下补齐脚本、文档、非真机构建与回归证据，并分别推送后端和 iOS 仓库。

## Success Criteria

- 新增可重复的 maintenance/canonical mutation contract gate，覆盖默认 dry-run、raw title sentinel、receipt/change/replay 一致性和脱敏报告结构。
- gate 以可选开关接入现有 release regression 或 release QA package，默认公开 MVP 路径不执行生产写操作。
- 后端全量、知识 smokes、iOS 静态检查/release regression、Simulator 可用 smoke、generic iPhoneOS build 与 diff check 通过。
- 状态文档记录运行方式、非真机边界和生产执行顺序。
- 后端与 iOS 分仓提交并推送，提交不混入非本任务变更。
