# 后端数字人 Lease 持久化与并发仲裁

## Problem

内存和 Postgres store 尚无数字人 session lease。需要实现安全元数据持久化、同 context 复用、同设备替换、跨设备容量冲突、heartbeat、幂等 release 和 TTL 过期，并保证 Postgres 多 worker 原子性。

## Success Criteria

- 内存与 Postgres 提供一致 acquire/heartbeat/release/get 语义。
- Postgres acquire 使用事务级数据库锁完成容量判断和写入。
- lease payload 不包含腾讯 credential。
- store 单测覆盖复用、替换、冲突、heartbeat、release、expiry 和并发 SQL 合同。
