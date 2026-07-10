# 后端 opaque auth session 合同

## Problem

实现 auth session 的内存/Postgres 安全持久化、登录签发、refresh 单次旋转、logout 撤销、过期校验和 runtime capability。只保存 token hash，不保存原文；保留 backend token 兼容。

## Success Criteria

API/store 测试覆盖签发、解析、过期、旋转、重放拒绝、撤销和账号清理，后端全量验证通过。
