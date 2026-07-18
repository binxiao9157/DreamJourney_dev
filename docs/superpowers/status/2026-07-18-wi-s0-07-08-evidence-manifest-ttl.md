# WI-S0-07-08 Evidence Manifest 与 TTL

日期：2026-07-18

## 当前状态

- Work Item：`WI-S0-07-08`
- Authority lock：`OPERATIONS_EVIDENCE`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / IOS_LOCAL_COMMITTED / BACKEND_DEPLOYED / G0_G1_G2_SCOPED_VERIFIED / G3_G4_EXTERNAL_OPEN`
- 说明：本 Work Item 的 Manifest 存储、TTL 与 retention 运维能力已在部署后端的隔离 Postgres 中验证。该结论只关闭此范围内的 G2；不会把 Provider/真机/签发策略等外部门伪记为已完成。

## 已实现的证据边界

- 后端新增 `evidenceManifest` append-only metadata envelope 和 `0010_evidence_manifest` migration。
- Manifest 固定记录 commit、build、environment、窗口、样本摘要哈希、排除项、schema 版本、redaction 版本、artifact hashes、签发/过期时间、签发方、状态和 owner lease hash。
- 后端只接受 machine principal 的 `/ops/evidence-manifests`；该路由 `no-store`，拒绝未声明字段，不能上传 `reportBody`。
- hash mismatch、过期、legacy 无 Manifest、非 passed 状态均无法通过验收验证。
- iOS Echo QA export 会先导出既有红脱敏 bundle，再生成与该 bundle SHA-256 绑定的本地 Manifest。没有可信 source commit 的手动导出只能标为 `legacyUnverified`，不作为验收成功。
- iOS 本地 Manifest 和 bundle 都按 owner lease 隔离，默认 7 天 TTL；账号清理会同时移除该 owner 的 QA 元数据和临时导出目录。

## 本地验证

- iOS：`echo-qa-evidence-bundle-check.swift` 通过。
- iOS：Debug Simulator build 通过。
- iOS：`run-echo-qa-evidence-bundle-export-smoke.sh` 通过，验证 source commit、artifact hash、owner isolation、expiry、排除项和无 raw marker 泄露。
- iOS UIQA 证据目录：`tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260718-231208/`。
- iOS 证据提交：`b0cd090fc06ad73cdc88585efbe847a445dc47ea`（`feat(ops): bind echo QA exports to manifests`）。该次 export 的 `sourceCommit` 与上述提交一致，`artifactHash` 为 `dbcf63be4e19e6d55282236ee47754487963b3d517499a15ff92205400a8b22d`，并已验证 owner isolation、TTL expiry、source commit/hash 绑定与无 raw marker 泄露。
- Backend：Manifest、retention、store、route-auth、migration 和 runtime contracts 相关单测通过。
- Backend：完整测试集 `589` 项通过，`scripts/verify_backend.sh` 通过，包含 Python compilation、FastAPI smoke、provider boundary 和 diff check。

## G2 部署与验收

1. Backend `main@933af481b181affd4335721e2690d56470ed20e1` 已推送、部署并重建 API 容器；`0010_evidence_manifest` 已应用，`/ready` 返回 `200`。
2. `dreamjourney-evidence-manifest-retention.service` 与 `.timer` 已安装并启用；timer 处于 `active`，按日执行 metadata retention。
3. 部署容器内运行 `backend-evidence-manifest-deployed-smoke.py` 通过，使用 temporary Postgres，不修改生产业务数据。验证包含 migration head `0010`、持久化/读取、tamper hash mismatch 拒绝、legacy evidence 拒绝、过期 evidence 拒绝、retention 删除和 reissue。
4. smoke 摘要：`manifestCountBeforeRetention=2`、`manifestCountAfterRetention=0`、`expiredCount=3`、`reissueProducedNewEvidenceId=true`、`rawPrivateMarkerLeaked=false`、`status=passed`。

## 仍然开放的边界

- `WI-S0-07-09` strict readiness 仍依赖完整 Stage 0 证据和 G4；本 Work Item 不替代其聚合硬门。
- 需要 Security 签发策略时，仍应由对应 Owner 决定；当前 Manifest 只记录 issuer metadata，不实施签名或集中上传正文/完整日志。
- Provider、真机、产品/隐私/法律等 G3/G4 证据保持外部开放，不能由本地或部署 smoke 自动关闭。
