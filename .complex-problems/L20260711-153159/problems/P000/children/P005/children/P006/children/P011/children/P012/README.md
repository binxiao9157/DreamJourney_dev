# 同账号家庭刷新响应代次隔离

## Problem

FamilyRepository 并发 refresh 只比较账号 generation；同一账号的旧成功或旧失败响应可覆盖较新的 authority snapshot。

## Success Criteria

- 每次 refresh 捕获独立 freshness generation。
- callback 同时比较 owner、账号 generation 和 refresh generation。
- refresh A/B 乱序时旧成功与旧失败均被识别为 stale。
- 模型与 repository lifecycle gate 覆盖该行为并通过。
