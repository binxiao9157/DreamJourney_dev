# 知识操作 Receipt 最小化 iOS/QA 状态

日期：2026-07-11

## 范围

本文件记录 DreamJourney_dev P009 的 iOS/QA 跨仓 release gate 与非真机构建。配套后端实现位于同级 `DreamJourneyBackend` 当前未提交工作树；本轮不改变公开 UI，也不做真机验证。

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

维护只更新 `kb_operation_receipts.result`。不删除 receipt 行，不修改 operation identity、kind、schema version，不重写 payload hash。已经压缩的正文恢复依赖部署前备份；本轮不执行线上 apply、不部署后端。

## 验证

- 新增跨仓 gate：通过；后端组合 smoke 共运行 34 项 fixture tests。
- Release QA package check：通过；历史视觉证据目录缺失按既有逻辑跳过严格 evidence 校验。
- 默认 release regression：通过。报告：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task26-receipt-final/report.md`。
- Simulator 编译与 Archive -> Echo、延迟回信模拟器 smoke：通过，证据位于上述 release regression 目录。
- Generic iPhoneOS 无签名构建：通过。报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260711-task26-receipt-final-iphoneos/report.md`。
- iOS 与后端仓库 `git diff --check`：通过。
- 后端全量 verify：304 项测试、FastAPI/knowledge smokes 与 receipt maintenance 34 项组合 smoke 通过。
- 真机：不做真机，本轮无真机证据。
