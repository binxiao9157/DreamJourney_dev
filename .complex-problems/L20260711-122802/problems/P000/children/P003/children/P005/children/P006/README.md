# 部署、备份与生产 maintenance preflight

## Problem

生产服务器仍需部署 `e1f06a8`，并在任何清洗写入前证明 health、版本、备份和 pre-dry-run 均满足安全条件。

## Success Criteria

- 服务器仓库和 API 容器运行 `e1f06a8`，health 为 production/Postgres。
- 不覆盖服务器私密 `.env`，不输出 token。
- 创建权限受限、非空、有校验值的 Postgres 备份。
- maintenance 默认 dry-run 在真实 Postgres 上成功，`mode=dryRun`、`invalidRecordCount=0`，报告只含聚合字段。
- 若任一条件失败，停止，不执行 apply。
