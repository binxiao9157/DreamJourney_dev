# P000: P1 知识 Mutation Proposal 与 Persona 归属

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_15_p1-knowledge-mutation-proposal-persona-schema.md` using recursive problem, ticket, result, and check state.

Task context:

# P1 知识 Mutation Proposal 与 Persona 归属

## Success Criteria
- 相同 owner/persona/自然键重复提取产生相同 ID；已有 legacy UUID 会被复用。
- proposal 不直接写库，且可直接作为 Mutation V2 upserts 使用。
- 所有 proposal 实体可回答 owner、persona、来源、证据状态和隐私范围。
- 人物/地点/事件/事实关联只指向当前 snapshot 或本次 proposal 的有效 ID。
- 角色或用户切换后的旧异步结果不会写入当前知识库。
- personal 旧数据兼容；family Context 只消费目标 digitalHumanId 的显式 family facts。
- Task 12-14 的 revision/tombstone/evidence/Context 回归不退化。
- 后端全量验证、iOS release regression、generic Simulator/iPhoneOS 构建和 `git diff --check` 通过。

## Subproblems
- P001: 后端 Mutation Proposal Builder
- P002: 后端 Persona Context Policy
- P003: iOS Proposal 消费与 Identity-bound 合并
- P004: 跨仓库 QA、构建与交付收敛

## Results
- R006

## Latest Check
C006

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R006: problems/P000/results/R006.md
- Check C006: problems/P000/checks/C006.md

## Follow-ups
- none
