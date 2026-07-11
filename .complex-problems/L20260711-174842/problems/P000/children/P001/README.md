# 语义缓存账号、代次与内容隔离

## Problem

`KBLiteSemanticSearch` 使用无锁全局字典和 entity ID key；跨账号、跨类型、同 ID 内容更新和账号切换期间的旧 warm task 都可能复用或写入错误向量。

## Success Criteria

- cache scope 绑定不可逆 owner key 与 KBLite generation。
- cache key 包含 entity kind、ID 与 searchable text fingerprint，不包含原始正文或 userId。
- cache 激活、读取、写入、失效均线程安全。
- 旧 scope 的异步 warm task 不能写入当前 scope。
- 登出、账号切换与内容更新有自动化 gate，且既有关键词 fallback 保持不变。
