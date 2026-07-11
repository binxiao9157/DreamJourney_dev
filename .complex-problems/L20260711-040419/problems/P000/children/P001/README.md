# 后端知识治理动作合同

## Problem

通用 Mutation V2 无法证明确认、拒绝和纠正语义，也不能阻止客户端原地改写历史。需要由服务端当前 snapshot 构建严格、可审计的 governance mutation，并保持 owner/persona/revision 边界。

## Success Criteria

- 新增纯函数 governance builder 和 owner-only endpoint。
- confirm/reject/correct 状态转换、correction 字段 allowlist、时间和目标校验完整。
- correct 将原实体标记 superseded，并生成稳定 confirmed replacement，不原地改写。
- endpoint 返回权威 graph、revision、Mutation V2 和无正文 summary。
- memory/Postgres、operation ID、revision conflict、Context evidence 既有行为不退化。
