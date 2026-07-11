# 收口 persona 可见检索与默认发布门

## Problem

Task 23 的 cache/storage 实现尚未接入默认发布回归；generation Context 的 semantic top-K 在 persona/evidence 过滤之前执行，其他 persona 或不可生成实体可能挤占当前角色候选。

## Success Criteria

- generation Context 在 semantic ranking 前只提供 expected identity 且 generation-eligible 的候选实体。
- 普通本地浏览搜索保持既有全账号图谱行为，不扩大公开数据权限。
- 新增纯模型/static gate 覆盖 persona prefilter 与关键词 fallback。
- semantic cache 和 storage 四条 runner 接入默认 release regression 与 release QA package。
- 完整 release regression、Simulator/generic iPhoneOS build、文档和 `git diff --check` 通过。
