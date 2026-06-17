# P001: P1 Profile safety flow shells and care visibility

Status: done
Parent: P000
Root: P000
Source Ticket: none (none)
Source Check: C000
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
Task 4 的 family/persona switcher 已完成，但 profile safety flows 仍缺少最小可验收闭环：

- 账号注销仍是占位 alert，没有 destructive confirmation shell 或明确的合规边界。
- 医生联系仍是占位 alert，没有安全说明、非紧急提示或联系契约边界。
- 心境追踪仍只按 feature flag 显示，没有结合 selected persona/mode 做可见性判断。

这些功能仍必须保持隐藏或安全降级，不能直接对默认发布态开放。

## Success Criteria
- 默认 release flags 仍不公开 `accountDeletion`、`careDoctorContact`、`familyManagement`、`familySpace`。
- 账号注销在隐藏态下显示 destructive confirmation shell，但最终删除动作仍不可执行，且文案说明需要完整合规流程。
- 医生联系在隐藏态下显示安全说明，强调非紧急、非医疗诊断，并保留未接入真实联系契约的边界。
- 心境追踪可见性通过一个明确 helper 结合 `careDashboard` 与 selected persona/mode 判断；默认 self 状态仍保持当前 Stitch/profile 视觉。
- 新增或更新静态 guard，覆盖上述 release gate、安全文案和 care visibility 合约。
- 相关 guard、`git diff --check` 和 iOS Debug 构建通过。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R001: problems/P000/children/P001/results/R001.md
- Check C001: problems/P000/children/P001/checks/C001.md

## Follow-ups
- none
