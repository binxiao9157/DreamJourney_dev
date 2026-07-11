# 后端部署与生产 Postgres 存量隐私验收

## Problem

本地测试不能证明真实 Postgres 的锁、JSONB 更新和存量数据状态。需要部署已推送后端，并在确认备份后按 dry-run/apply/dry-run 完成生产维护，同时验证新写入 mutation 的四个对外/持久化表面都使用 canonical title。

## Success Criteria

- 服务器拉取目标后端提交、重建服务，health 显示 production/Postgres 且版本与远端一致。
- apply 前确认可恢复备份，并先执行 dry-run；若 invalidRecordCount 非零则拒绝 apply，记录为明确阻断。
- dry-run 报告不含用户、source/entity ID、正文或 token。
- apply 成功后再次 dry-run，所有 changed 计数为 0，invalidRecordCount 为 0。
- 线上合成 sentinel mutation 的首次响应、change feed、receipt replay 均不含 raw title，且 canonical mutation 一致。
- 保存脱敏聚合证据，不做真机、不修改 UI 或其他产品模块。
