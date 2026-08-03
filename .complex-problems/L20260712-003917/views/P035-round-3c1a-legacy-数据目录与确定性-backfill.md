# P035: Round 3C1A Legacy 数据目录与确定性 Backfill

Status: done
Parent: P031
Root: P000
Source Ticket: T028 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P031/children/P035
Body: problems/P000/children/P003/children/P022/children/P031/children/P035/README.md
Ticket(s): T029

## Problem
当前 18 张后端表、JSONB payload、Archive/KBLite 和本地 iOS 数据与 Round 3B 的 38 个 V4 逻辑对象之间没有逐项迁移合同。若直接建新表或双写，可能伪造确认状态、转移 owner、丢失来源、重复记录或把不可解析历史数据静默升级。

## Success Criteria
- 编制覆盖所有当前 authority/projection 的 legacy-to-target migration catalog。
- 每个迁移对象包含 legacy locator、目标对象、deterministic ID、owner/vault/subject、authorityEpoch、source evidence 和 migrate/derive/quarantine/do-not-migrate 策略。
- 定义 batch checkpoint、canonical checksum、幂等 upsert、重跑、尾部追赶和 quarantine 裁决合同。
- 缺 owner/source/review 的记录不得自动成为 Confirmed MemoryVersion。
- 定义跨 owner ID 冲突、重复 JSONB、无效时间、孤儿媒体和不可解析 payload 的处理。
- 至少 8 个 backfill 故障场景可验证。
- 当前代码证据与线上未知数据分布明确分开。

## Subproblems
- none

## Results
- R025

## Latest Check
C025

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P031/children/P035/README.md
- Ticket T029: problems/P000/children/P003/children/P022/children/P031/children/P035/tickets/T029.md
- Result R025: problems/P000/children/P003/children/P022/children/P031/children/P035/results/R025.md
- Check C025: problems/P000/children/P003/children/P022/children/P031/children/P035/checks/C025.md

## Follow-ups
- none
