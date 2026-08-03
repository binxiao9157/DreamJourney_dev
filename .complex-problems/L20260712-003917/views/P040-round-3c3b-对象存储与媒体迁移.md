# P040: Round 3C3B 对象存储与媒体迁移

Status: done
Parent: P033
Root: P000
Source Ticket: T034 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P033/children/P040
Body: problems/P000/children/P003/children/P022/children/P033/children/P040/README.md
Ticket(s): T036

## Problem
当前媒体 upload intent 为 mock，部分内容只有设备路径/base64/metadata，没有 private object、checksum/scan/delete receipt。需要设计不伪造 uploaded/verified 状态的对象迁移、引用切流、孤儿清理和删除传播。

## Success Criteria
- 定义 private namespace、signed intent/commit/HEAD/checksum/mime/scan/encryption 生命周期。
- 编制当前文字/照片/音频/视频/文档/生成音频到 SourceObject/GeneratedAudio 的迁移目录。
- 定义 metadata backfill、copy/upload、verify、reference cutover、rollback 和 orphan reconciler。
- local-only/mock/missing/unsafe 对象保持明确状态，不进入处理/检索。
- 删除覆盖 object version/marker/cache/backup/provider receipt 和普通访问先撤销。
- 至少 12 个上传、DB crash、checksum、scan、orphan、删除与权限场景。
- 增加静态门禁并同步 Evidence Matrix。

## Subproblems
- none

## Results
- R032

## Latest Check
C032

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P033/children/P040/README.md
- Ticket T036: problems/P000/children/P003/children/P022/children/P033/children/P040/tickets/T036.md
- Result R032: problems/P000/children/P003/children/P022/children/P033/children/P040/results/R032.md
- Check C032: problems/P000/children/P003/children/P022/children/P033/children/P040/checks/C032.md

## Follow-ups
- none
