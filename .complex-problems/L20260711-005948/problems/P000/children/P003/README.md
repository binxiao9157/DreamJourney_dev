# 知识 V2 跨仓库 QA 与交付收敛

## Problem

后端和 iOS 分别实现后仍需一条可重复组合门证明删除不会复活、单侧更新不丢失、冲突可观察且 v1 fallback 不回归，并需要明确部署前后的版本边界。

## Success Criteria

- 新增 backend v2 smoke、iOS model/static gate 和可选 release regression 组合开关。
- 两客户端场景覆盖 upsert、tombstone、重复 operation、409、malformed feed、local-only 保留。
- 后端全量测试、iOS release regression、generic iPhoneOS build 与两仓库 diff check 通过。
- 状态/部署文档记录 schema、兼容路径、冲突策略、验证证据和未完成的分页/公开 UI。
