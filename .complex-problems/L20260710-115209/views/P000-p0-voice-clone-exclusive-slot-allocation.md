# P000: P0 voice clone exclusive slot allocation

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_06_p0-voice-clone-exclusive-slot-allocation.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 voice clone exclusive slot allocation

## Success Criteria
- Two logical profiles cannot own the same configured provider speaker.
- A fourth active profile against a three-slot pool receives an explicit capacity error rather than overwriting another voice.
- `/voice/synthesis` rejects missing, disabled, deleted, unaccepted, or cross-user profiles.
- A valid logical profile resolves to its assigned provider speaker for training, status refresh, and synthesis.
- Existing persisted profiles with `voiceProfileId=S_...` remain synthesizable when otherwise usable.
- No provider speaker ID is required in iOS role/family binding.
- Backend verification and iOS non-device build pass.

## Subproblems
- P001: 建立音色槽持久化与原子独占分配
- P002: 接入逻辑 profile 与 provider speaker 分离合同
- P003: 更新 iOS 逻辑 ID、QA 护栏和交接文档

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R003: problems/P000/results/R003.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- none
