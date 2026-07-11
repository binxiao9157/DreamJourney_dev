# Knowledge Mutation / Receipt 隐私 Canonicalization

## 目标

客户端传入的 `privacyMetadata.sourceRefs[].title` 不得原样进入知识 mutation 首次响应、change feed、operation receipt、duplicate replay 或持久化 JSONB。服务端只保留 source `kind/id` 证据身份，并按 `kind` 生成安全标题。

## 已实现

- V2 mutation 在 fingerprint、graph merge、response、change 和 receipt 之前统一 canonicalize。
- raw title 与 canonical title 的相同 operation ID 重试保持幂等；kind/id/正文变化仍产生 payload conflict。
- 新增历史 Postgres 维护入口，覆盖 snapshot graph、change graph/mutation 和 receipt result。
- 只有 V2 `kb.mutation` receipt 会按 canonical mutation 重算 hash，其他 operation hash 不猜测修改。
- 维护支持 dry-run、显式 apply、第二次 apply 零变更、无效记录拒绝和单事务回滚。
- 聚合报告不包含 user/source/entity ID、正文或 token。

## 本地回归

```bash
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
  Scripts/QA/prd-stitch-ui/run-knowledge-privacy-maintenance-gate.sh
```

Release regression 默认运行该本地 fixture gate，也可以显式设置：

```bash
RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE=1 \
RUN_ID=<run-id> \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

该 gate 不连接生产数据库、不读取部署 token，并且不自动执行生产 --apply。

## 生产执行边界

后端部署后，必须先确认可恢复备份，再在服务器私密环境中执行：

```text
dry-run -> apply -> dry-run
```

- 首次 dry-run 的 `invalidRecordCount` 必须为 0，否则停止，不允许局部跳过。
- apply 必须显式传 `--apply`。
- post-apply dry-run 的所有 `changed` 计数必须为 0。
- 只保存脱敏聚合 JSON，不把用户、知识正文、source ID 或 token 写入报告。

## 验证状态

- 新写入合同与维护单元测试：8 个定向测试通过。
- 后端全量、FastAPI、knowledge delta/V2/evidence smoke：267 个测试及全部 smoke 通过。
- 跨仓 gate 与 release QA package：通过。
- 完整 release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task20-knowledge-privacy/report.md`。
- Archive -> Echo Simulator smoke：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task20-knowledge-privacy/archive-to-echo-smoke/20260711-task20-knowledge-privacy/01-archive-to-echo-completed.png`。
- Echo delayed reply Simulator smoke：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task20-knowledge-privacy/echo-delayed-reply-notification-smoke/20260711-task20-knowledge-privacy/01-echo-delayed-reply-notification-smoke.png`。
- generic iPhoneOS build：通过，bundle ID 为 `com.yxj.dreamjourney.app`。
- 双仓提交、服务器部署和生产 Postgres 清洗：下一步骤执行。

## 非目标

- 不改 Stitch UI，不做真机。
- 不处理 Widget/Family/semantic cache/change-feed compaction。
- 不迁移历史 source identity。
