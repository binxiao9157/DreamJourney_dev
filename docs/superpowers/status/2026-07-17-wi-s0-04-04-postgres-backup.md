# WI-S0-04-04 Postgres Backup Manifest、调度与告警

日期：2026-07-17
Work Item：`WI-S0-04-04`
状态：`INTERNAL_READY / DEPLOYED / G2_SERVER_LOCAL_BACKUP_VERIFIED / OFFHOST_KMS_PRIVACY_SRE_PENDING`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`DB_RECOVERY`
Lease：`ACTIVE`

## 已实现

- `pg_dump --format=custom` 生成独立于 Compose volume 的数据库 artifact。
- 默认强制 OpenSSL AES-256-CBC/PBKDF2 加密；未配置 key 时 fail closed，只有显式 QA override 才允许未加密。
- 加密后通过流式解密到 `pg_restore --list` 验证 archive 可访问性，验证通过后才写成功 manifest。
- value-free manifest 记录 backupId、时间、schemaHead、LSN、SHA-256、size、encryptionRef、retentionClass、expiresAt 和 status，不记录 DSN、凭据或用户正文。
- manifest 原子写入；artifact/manifest 权限为 `600`，备份目录为 `700`；失败会清理 partial 和未验证孤儿 artifact/manifest。
- 磁盘空间预检、单实例锁、中断、pg_dump、加密、archive 校验、manifest 校验均有 machine-safe 失败回执。
- freshness gate 默认可要求 36 小时内最新可验证备份；过期/陈旧/checksum/size/schema mismatch 均 fail closed。
- retention 只输出 `auditOnly` 计划，`automaticDeletion=false`，并保护至少最后一份有效备份。
- systemd 每日备份 timer、周 retention audit timer、Persistent 补跑和 OnFailure alert receipt 已安装。
- 新增本地 fake-Docker 全链路 smoke 与服务器 deployed smoke；均不输出 backupId、checksum 或数据库正文。

## 验证

- 后端全量 `385` 项测试通过；凭据边界、FastAPI、知识库 smoke、Python compile、shell syntax 和 `git diff --check` 通过。
- 实现提交 `434a3bd`、deployed evidence follow-up `127f7ac`、诊断强化 `1b7f2fe` 和 Bash 3.2 磁盘不足 fail-closed 修复 `ecb2cf6` 已推送；服务器源码为 `ecb2cf6`。
- 本地集成 smoke：连续两次加密备份、解密访问、freshness、SIGTERM 中断、磁盘不足、checksum 损坏、alert receipt、retention audit 均通过；系统 Bash 3.2 路径连续 20 次通过，磁盘不足不会继续生成成功备份。
- 服务器真实生产 Postgres 已连续生成两份当前加密 backup；两份 schemaHead 均为 `0001`，manifest/artifact 均为 `600`，备份根目录为 `700`。
- 服务器 latest-backup freshness gate 通过；没有残留 `.partial` 或持有中的 lock。
- retention report 显示两份有效备份、`action=auditOnly`、`automaticDeletion=false`。
- alert receipt 已通过 systemd unit 生成；OnFailure 当前指向 `dreamjourney-db-backup-alert@database-backup.service`。
- 两个 timer 均 enabled/active；每日备份与周 retention audit 的下一次执行时间可由 `systemctl list-timers` 复核。
- 服务器 deployed smoke 返回：两份 current verified backup、加密 artifact、freshness、权限、retention、alert 和 timer 全部通过。
- 备份执行后 API `/ready` 仍为 `ready`，未影响线上服务。
- iOS release regression 已通过，报告位于 `tmp/visual-qa/prd-stitch-ui/release-regression/20260717-wi-s0-04-04-final/report.md`；备份静态门已成为默认回归项。

## 未关闭边界

- 当前 artifact 与加密 key 都在同一服务器，只证明 server-local 加密恢复起点；off-host copy、KMS/独立 key custody 尚未完成。
- 当前备份使用现有数据库 owner；受限 backup role、密码托管和轮换需要 Data/SRE 窗口。
- timer 已启用且两次 service 手工执行成功，但首个自然 timer 周期尚未到达；不能把安装状态冒充长期连续成功率。
- alert receipt 与 journal 已验证，但尚未接入外部 paging/on-call 渠道并演练送达。
- 35 天 retention 是工程默认值，Privacy/Legal 尚未正式批准；因此保持 audit-only，不自动删除。
- backup 成功不等于 restore 成功；隔离 restore、删除不复活、receipt replay、RPO/RTO 属于 `WI-S0-04-05`。

## 下一步

进入 `WI-S0-04-05`：只在隔离数据库执行 restore、迁移 head 校验、完整性验证和恢复证据；不得覆盖生产数据库或伪造 RPO/RTO。
