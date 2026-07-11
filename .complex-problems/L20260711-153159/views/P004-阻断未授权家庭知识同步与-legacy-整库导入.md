# P004: 阻断未授权家庭知识同步与 legacy 整库导入

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P004
Body: problems/P000/children/P004/README.md
Ticket(s): T004

## Problem
knowledge sync 主要依据 privacy scope，ownerless/wrong-owner/unaccepted-family graph 缺少统一边界；KBLiteMultiUser 又信任文件自报 sourceUserId 并允许裸 graph 直接合并。

## Success Criteria
- 增加 owner/persona sync authorization policy，出站和 authoritative merge 复用。
- wrong-owner、ownerless legacy 上传和未授权 family persona 不进入远端同步或生成；个人 legacy 仅本地兼容。
- 裸 graph 永远拒绝，无后端 grant 的 share package 默认拒绝。
- KBSync UI 不把被拒绝导入显示为成功，公开 release 不提供可执行整库导入。
- 纯模型与静态 gate 覆盖 accepted exact-match 与各拒绝分支。

## Subproblems
- none

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P004/README.md
- Ticket T004: problems/P000/children/P004/tickets/T004.md
- Result R003: problems/P000/children/P004/results/R003.md
- Check C003: problems/P000/children/P004/checks/C003.md

## Follow-ups
- none
