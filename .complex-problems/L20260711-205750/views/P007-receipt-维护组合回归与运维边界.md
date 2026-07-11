# P007: Receipt 维护组合回归与运维边界

Status: done
Parent: P002
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P002/children/P007
Body: problems/P000/children/P002/children/P007/README.md
Ticket(s): T006

## Problem
Receipt 维护必须与 change-feed compaction、privacy metadata maintenance 和线上重放合同共同工作，需要一条后端组合回归和明确的运维边界，避免单测通过但脚本组合失效。

## Success Criteria
- 新增后端 receipt maintenance smoke，验证 dry-run、apply、duplicate replay 和第二次幂等。
- 现有 privacy maintenance 在 compact V2 receipt 存在时 dry-run/apply 不报 invalidRecords。
- Change-feed compactor 仍把 compact receipt 行视为有效幂等屏障。
- `verify_backend.sh` 接入必要 smoke，默认不依赖真实 Postgres。
- CLI `--help`、py_compile、后端全量测试与 diff check 通过。
- 输出部署前先 dry-run、观察 bytes/WAL/vacuum、再分批 apply 的运维说明。

## Subproblems
- P008: Receipt Maintenance 脏 Compact 与扫描完整性修复

## Results
- R005

## Latest Check
C006

## Bodies
- Problem: problems/P000/children/P002/children/P007/README.md
- Ticket T006: problems/P000/children/P002/children/P007/tickets/T006.md
- Result R005: problems/P000/children/P002/children/P007/results/R005.md
- Check C006: problems/P000/children/P002/children/P007/checks/C006.md

## Follow-ups
- none
