# 实现 Receipt Dry-run/Apply 维护与现有维护兼容

## Problem Definition

线上历史 `kb_operation_receipts.result` 仍可能保存完整 graph/mutation，需要默认只读、按用户隔离的维护入口转换为 compact envelope。与此同时，现有 privacy maintenance 会把不含 mutation 的 compact V2 receipt 误判为无效并在 apply 时中止，必须在部署前修复。

## Proposed Solution

新增独立 receipt maintenance service、Postgres store 方法和 CLI。先扫描超过 keep-days 的 legacy full receipt，按 operation kind 构造 compact envelope；dry-run 只统计候选、估算字节与风险，apply 对每个用户使用独立事务、advisory lock、lock/statement timeout 和批量更新。保持 receipt 表的 kind/schema/payload hash 不变。同步修改 privacy maintenance：识别 compact envelope 后只校验结构并原样保留 fingerprint，不要求已移除的 V2 mutation。

## Acceptance Criteria

- CLI 默认 dry-run，显式 `--apply` 才写库，并支持 keep-days、batch-size、lock timeout 与 statement timeout。
- 历史 full receipt 可转换为无 graph/原始 mutation/正文的 compact envelope，payload hash 不变。
- 按用户 advisory lock 和独立事务执行；一个用户锁超时或失败不会回滚其他用户。
- Apply 可重复运行，第二次无额外修改。
- 报告包含 scanned/candidate/updated/skipped/failed、按 kind 计数、估算 bytes before/after/saved，且不输出正文。
- Governance/archive 的 ID-only summary 可从历史 mutation/result 安全提取。
- Privacy maintenance 接受 compact V2 envelope，不重算其 payload hash；legacy full result 行为不变。
- Fake Postgres/服务单测覆盖 dry-run、apply、锁超时、用户级回滚、幂等和 compact privacy compatibility。

## Verification Plan

运行新增 maintenance 单测、现有 privacy/change-feed/knowledge 回归、完整 `STORE_BACKEND=memory scripts/verify_backend.sh`、CLI `--help`、`py_compile` 和 `git diff --check`。P003 再负责跨仓 gate、真实 Postgres dry-run/apply 与部署证据。

## Risks

- JSONB 更新会产生 WAL 与表膨胀，必须分用户、小批量并在部署文档中说明 vacuum 观察。
- 历史异常 receipt 不能猜测修复，应计入 failed/skipped 并保留原数据。
- Change 已压缩时不影响维护，因为 compact envelope 只依赖 receipt result 内的原始 revision 与可提取摘要。

## Assumptions

- Receipt 身份行永久保留，不按 TTL 删除。
- `payload_hash` 是幂等权威，历史最小化不得重新计算或修改。
- P001 dual-reader 已先部署代码路径但不会在 P002/P003 完成前上线。
