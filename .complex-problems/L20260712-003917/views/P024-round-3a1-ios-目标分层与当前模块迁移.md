# P024: Round 3A1：iOS 目标分层与当前模块迁移

Status: done
Parent: P020
Root: P000
Source Ticket: T018 (split)
Source Check: none
Package: problems/P000/children/P003/children/P020/children/P024
Body: problems/P000/children/P003/children/P020/children/P024/README.md
Ticket(s): T019

## Problem
UIKit 页面和 Service 当前同时承载展示、状态、缓存、后端合同和 provider runtime，需要定义可渐进抽取的依赖方向，且不能改变已对齐 Stitch UI。

## Success Criteria
- 定义 AppShell/Feature/Domain/Application-Repository/Infrastructure/Runtime 六层职责和允许依赖。
- Source/Review/OwnerQA/Profile/DataRights 等核心 feature 与可选 Beta/Future 模块边界明确。
- 本地 draft/cache/projection/runtime 与后端 authority 边界明确。
- 至少 12 个当前 iOS 模块/服务分类保留、适配、兼容、后置或退役。
- 给出不改公开 UI 的渐进抽取顺序和测试 seam。
- 该问题属于 T018，因为 iOS 可迁移性是系统模块边界的一半。

## Subproblems
- none

## Results
- R016

## Latest Check
C016

## Bodies
- Problem: problems/P000/children/P003/children/P020/children/P024/README.md
- Ticket T019: problems/P000/children/P003/children/P020/children/P024/tickets/T019.md
- Result R016: problems/P000/children/P003/children/P020/children/P024/results/R016.md
- Check C016: problems/P000/children/P003/children/P020/children/P024/checks/C016.md

## Follow-ups
- none
