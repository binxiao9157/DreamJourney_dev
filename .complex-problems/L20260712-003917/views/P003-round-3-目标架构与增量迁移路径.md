# P003: Round 3：目标架构与增量迁移路径

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T017

## Problem
现有工程已有 Archive、KBLite、Echo、Family、Voice、Digital Human 等大量能力，不能按新名词推倒重来；同时 Publication/Visitor、Source processing 等新目标需要明确权威数据和迁移边界。

## Success Criteria
- iOS、后端、对象存储、异步任务和 provider adapter 的目标边界明确。
- 每个领域对象都有权威来源、ID、状态机、权限、删除和审计责任。
- 现有模块被标为保留、重命名适配、抽取、替换或后置，且有理由。
- 数据迁移保持 backward compatibility、feature flag、回滚和双读/双写边界。
- Hermes/AOS 可借鉴机制仅在有证据和实际收益时进入方案。

## Subproblems
- P020: Round 3A：系统上下文与 iOS/后端模块边界
- P021: Round 3B：数据、API、授权、任务与 provider 合同
- P022: Round 3C：Legacy 迁移、rollout、rollback 与退役
- P023: Round 3D：目标架构独立复审与静态验收

## Results
- R047

## Latest Check
C048

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T017: problems/P000/children/P003/tickets/T017.md
- Result R047: problems/P000/children/P003/results/R047.md
- Check C048: problems/P000/children/P003/checks/C048.md

## Follow-ups
- none
