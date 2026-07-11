# 知识操作 Receipt 最小化 iOS/QA 状态

日期：2026-07-11

## 范围

本文件记录 DreamJourney_dev Task 26 的 iOS/QA 跨仓 release gate、非真机构建、后端部署和线上 Postgres receipt 最小化验收。本轮不改变公开 UI，也不做真机验证。

静态合同覆盖：

- Memory/Postgres 新 writer 只保存 `receiptEnvelopeVersion=1` compact result，reader 同时兼容 legacy full 与 compact result。
- Duplicate replay 必须先校验 operation kind 与 payload fingerprint，再读取并重建 result。
- Dirty compact envelope 必须经过 canonical compare，不能仅凭 envelope version 跳过。
- `maintain_knowledge_operation_receipts.py` 的 `--apply` 使用 `store_true`，默认 dry-run。
- 后端组合 smoke 同时覆盖 compact/full replay、payload conflict、privacy maintenance 与 change-feed compaction。
- 运维合同不删除 receipt identity，也不重写 payload hash。

## QA Gate

低成本静态检查：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
swift Scripts/QA/prd-stitch-ui/knowledge-receipt-maintenance-contract-check.swift "$PWD"
```

完整 fixture gate：

```bash
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
Scripts/QA/prd-stitch-ui/run-knowledge-receipt-maintenance-gate.sh
```

Release regression 默认执行低成本 Swift static check；只有显式设置下列开关才运行完整后端组合 smoke：

```bash
RUN_KNOWLEDGE_RECEIPT_MAINTENANCE_GATE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 部署边界

生产部署必须先完成 reader-first 发布和数据库备份，再运行后端 fixture smoke。线上维护先 dry-run，不带 `--apply`；审阅候选数、失败用户、operation kind 与预计节省量后，才允许在低峰期用小 batch 显式 apply，并立即再次 dry-run 验证幂等。

维护只更新 `kb_operation_receipts.result`。不删除 receipt 行，不修改 operation identity、kind、schema version，不重写 payload hash。已经压缩的正文恢复依赖部署前备份。

后端 `4c0538b` 已采用 reader-first 顺序部署到生产 API 容器。线上先执行 `keep-days=0`、`batch-size=20` dry-run，确认 12 条候选、3 条已压缩、失败为 0 后执行 apply。Apply 后再次运行 dry-run/apply，候选数和更新数均为 0。

## 验证

- 新增跨仓 gate：通过；后端组合 smoke 共运行 34 项 fixture tests。
- Release QA package check：通过；历史视觉证据目录缺失按既有逻辑跳过严格 evidence 校验。
- 默认 release regression：通过。报告：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task26-receipt-final/report.md`。
- Simulator 编译与 Archive -> Echo、延迟回信模拟器 smoke：通过，证据位于上述 release regression 目录。
- Generic iPhoneOS 无签名构建：通过。报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260711-task26-receipt-final-iphoneos/report.md`。
- iOS 与后端仓库 `git diff --check`：通过。
- 后端全量 verify：304 项测试、FastAPI/knowledge smokes 与 receipt maintenance 34 项组合 smoke 通过。
- 后端提交 `4c0538b` 已部署；公网 `/health` 返回 production/Postgres，认证 runtime 和部署知识 smoke 通过。
- 线上 Receipt dry-run：扫描 15 条，候选 12 条，已压缩 3 条，失败用户和失败记录均为 0；允许 kind 仅有 `kb.sync` 与 `kb.mutation`。
- 线上 Receipt apply：12 条全部更新；receipt count、kind 分布和 identity/payload hash 聚合指纹保持不变。
- Postgres `result` 聚合占用从 15408 字节降至 2396 字节，减少 13012 字节。
- 二次 dry-run 候选为 0，二次 apply 更新为 0；部署知识 smoke 新写入 receipt 后，最终 18 条 receipt 全部为 compact，候选仍为 0。
- Privacy metadata maintenance dry-run：`status=ok`、`invalidRecordCount=0`，未计划改写 compact receipt。
- Change-feed maintenance dry-run：`status=ok`、无跳过用户、无锁或 statement timeout、无计划删除。
- 线上脱敏证据：`tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/`，该目录被 git 忽略，不包含用户正文或凭据。
- 真机：不做真机，本轮无真机证据。
