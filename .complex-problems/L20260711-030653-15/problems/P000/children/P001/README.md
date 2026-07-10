# 后端 Mutation Proposal Builder

## Problem

后端 extraction 尚未基于权威 snapshot 生成稳定、可审计且可直接提交 Mutation V2 的 proposal。

## Success Criteria

- 基于 owner/persona/entity natural key 生成稳定 ID，并优先复用 snapshot 现有 ID。
- 输出 revision-bound upserts、metadata、证据状态和已解析关系，且不直接持久化。
- 单元/API 测试覆盖幂等、legacy ID、关系解析和隐私净化。
