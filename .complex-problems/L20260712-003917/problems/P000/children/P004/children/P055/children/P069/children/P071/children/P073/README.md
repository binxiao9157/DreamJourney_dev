# Round 4E1A1：补齐危机响应与 AI 披露路线

## Problem

当前 Stage 0 路线有 Release Policy、Privacy 和 Operations 止损，但没有一个独立 Work Item 对 `FR-SAFE-001/002` 负责。危机/自伤表达、AI 身份披露、地区资源边界和“不能延迟、不能人格化、不能诊断”因此只有原则，没有可执行 owner、接口、证据和 stop-line。

## Success Criteria

- 在 `WP-S0-06` 新增且仅新增一个 16 字段 Work Item `WI-S0-06-09`。
- 该项明确 AI 身份披露、危机/自伤即时分流、地区资源政策、不可延迟、不可伪装真人和不可诊断边界。
- `FR-SAFE-001/002`、适用 CR/DR/finding 有精确引用；Product/Privacy/Legal/地区资源外部门不得被静态测试关闭。
- Stage 0 计数由 49 项/784 字段更新为 50 项/800 字段，相关批次、停止线和验收描述一致。
- 不新增公开医疗、诊断、医生或自动干预功能。

## Verification

- 检查新增 Work Item 16 个必填字段、ID 顺序和唯一性。
- 检查 `FR-SAFE-001/002` 的精确边和外部门语义。
- 运行 Product V4 文档检查、路线检查及 `git diff --check`。

## Boundaries

- 只修改产品路线和检查约束，不修改 iOS/后端生产代码。
- 不将危机资源目录、地区法律或运营流程臆造为已批准。
