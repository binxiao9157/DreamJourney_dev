# 部署 Reader-first 后端并安全最小化线上 Receipt

## Problem Definition

后端新提交尚未部署，真实 Postgres maintenance SQL、锁、JSONB update、幂等重放和历史数据分布未验证。

## Proposed Solution

使用现有 SSH 私密配置部署后端 `4c0538b`，确认服务健康和数据库类型。先在服务实际环境运行 `maintain_knowledge_operation_receipts.py` dry-run，将 stdout JSON 单独保存并审计 status、failed、byKind 与估算 bytes。满足硬门后，以小 batch 和短 lock timeout apply；复跑 dry-run/apply确认无候选。最后运行 deployed knowledge mutation/replay/conflict smoke、privacy maintenance dry-run和 change-feed compaction dry-run，保存脱敏报告并更新状态文档。

## Acceptance Criteria

- 服务器运行 `4c0538b`，health 200/store=postgres。
- First dry-run 无写且 status=ok、failedUsers=0、failed=0、byKind 合法。
- Apply 小批成功；第二次 dry-run candidate=0，第二次 apply updated=0。
- Receipt 行数与 payload hash identity 不被删除/重写。
- 线上 duplicate/conflict、privacy maintenance、change-feed barrier 验收通过。
- 报告不含正文、DSN、token 或 SSH 凭据。

## Verification Plan

服务器 git/container/service/health，maintenance JSON jq/Python 审计，前后 receipt count/hash aggregate 对比，deployed knowledge smoke，privacy/change-feed dry-run和最终文档记录。

## Risks

- Dry-run 为 partial 或出现未知 kind 时立即停止 apply并记录 blocker。
- 物理空间不会立即回收，观察 WAL/autovacuum，不执行 VACUUM FULL。

## Assumptions

- 私密 SSH/后端访问文档仍存在并被 gitignore。
