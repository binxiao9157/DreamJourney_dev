# PC-A1 回滚说明

1. migration `0095` 为 additive，不执行生产 down migration；出现问题时使用 forward-fix。
2. 可先关闭内部测试账号管理页或管理写入路由，保留已写入的 revision、snapshot 和审计记录。
3. 白名单登录资格与产品 entitlement 独立；不得通过回滚恢复“白名单即拥有全部功能”的隐式行为。
4. 已因权限变更撤销的 Access/Refresh Session 不得重新激活，账号需重新认证。
5. `scenarioBindings` 始终只作场景引用，任何回滚都不得把它提升为 Owner、Family 或 Visitor 权限依据。
6. 若新代码出现兼容问题，可回退 API 镜像并保留 `0095` 扩展列；旧代码忽略新增列。数据库恢复仅按权威 Runbook 和已验证备份执行。
