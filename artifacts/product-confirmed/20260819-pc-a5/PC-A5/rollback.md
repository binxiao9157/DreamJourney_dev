# PC-A5 回滚说明

1. 可以关闭 iOS 入口或回退客户端代码，但不得把已撤销的 Relationship、Access Grant 或 Contribution Grant 重新激活。
2. 后端代码回退前确认旧版本不会写入 migration `0098` 的新表；数据库采用 forward-fix，不删除 termination receipt 或 disposal queue。
3. 已接受 Source 和 PublicationVersion 不受关系解除影响；Publication Grant 仍只能由 Owner 独立撤销。
4. 如解除事务出现异常，使用 receipt、relationship epoch 和 Grant event 审计定位，不通过恢复旧 Session/缓存绕过当前权限。
