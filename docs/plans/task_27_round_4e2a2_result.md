# Round 4E2A2 Selector、失效重排与 Header 结果

## Summary

Roadmap 已接入 typed Execution Registry，明确 planning 与 execution 的授权边界、唯一排序算法、当前 baseline、MIG evidence-only 边界，以及 incident/evidence/decision/dependency/owner/lock/source drift 的状态失效和 replan 规则。当前唯一输出是 `PLAN_ASSIGN_OWNER:WI-S0-03-01`，不授权修改产品代码。

## Done

- Header/第6节更新为 Round 4A-D、E1、E2A 已完成，E2B 总 checker 与 Round 5 独立复审仍待完成；明确不代表工程实现。
- 新增 Execution Registry 的 authority/source hash/stale/milestone DAG/字段语义说明。
- 固定 `STOP_THE_LINE / EXECUTE / PLAN_ASSIGN_OWNER / NO_EXECUTABLE_ACTION` 四类 action。
- 固定候选过滤与排序 tuple：action、release class、selectorBand、priority、stableRank、ID。
- 当前 baseline 记录唯一 `PLAN_ASSIGN_OWNER:WI-S0-03-01`，`currentActionAuthorizesImplementation=false`。
- `WI-MIG-01-01` 只作为未选中的次级只读 inventory 候选；MIG 不拥有业务 aggregate。
- 新增 source stale、incident、evidence fail/expired/missing、open decision、dependency rollback、Owner/lock丢失、不可逆事实的状态与 replan 表。
- 更新 Stage 1 和 Optional/Migration 旧 header checker，使其严格校验新的 E2B/Round 5 边界，而非依赖历史文案。

## Verification

- Registry 重生成与 `--check`：通过；当前 SHA-256 连续两次均为 `45c543c9e819bf4bae2771c9749efd5fb7d67619486388554d2a490087b1edc7`。
- jq 按 current planning 条件复算首项：`WI-S0-03-01 / P0 / CREDENTIAL_CONTROL / rank=1 / STOP`。
- traceability、Stage 1、Optional/Migration、links、docs checks：通过。
- `git diff --check`：通过。

## Known Gaps

- Selector 规则目前由 Roadmap 定义、仅做人工/jq复算；Round 4E2B 仍需独立总 checker 和八类负向 fixture。
- Header 仍明确 `E2B_TOTAL_CHECK_PENDING`，不能在总 checker 通过前标 Round 4 总验收完成。
- 当前 action 只是分配 Owner 的规划动作，任何真正开发仍需要显式 `GO + owner + lock + dependencies`。

## Artifacts

- `docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`
- `docs/product/DreamJourney_V4_路线执行注册表_V1.0.json`
- `Scripts/QA/product-v4/product-v4-stage1-roadmap-check.py`
- `Scripts/QA/product-v4/product-v4-optional-migration-roadmap-check.py`
