# 后端 change-feed 保留水位与安全压缩

## Problem

实现原子 change-page 读取、持久化保留水位、结构化 410 合同和 dry-run-first Postgres 压缩维护。

该问题属于父任务，因为没有可靠的服务端保留边界和原子读取，客户端无法区分真实故障与已压缩历史。

## Success Criteria

- memory/Postgres store 都能返回一致的当前 snapshot、水位和分页窗口。
- 请求早于水位时 legacy/paged API 均返回精确 410。
- apply 压缩只删除有 receipt 的安全历史，删除和水位同事务，dry-run/失败不写库。
- 后端专项测试与 smoke 通过。
