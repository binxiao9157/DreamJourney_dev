# 跨仓交付、文档与部署验收

## Problem

Canonical source 合同需要跨仓门禁、release QA、清晰数据迁移边界和线上只读 audit 证据，避免后续再次误称或误级联。

## Success Criteria

- 跨仓 gate 验证 canonical 生成、legacy 只读分类和 Archive 删除隔离。
- Canonical 设计修正旧的“session 映射 Archive”假设。
- 后端全量、Simulator/generic iPhoneOS、release regression 通过。
- 分仓提交推送，后端部署并跑线上只读 audit smoke；不做真机、不执行历史 apply migration。
