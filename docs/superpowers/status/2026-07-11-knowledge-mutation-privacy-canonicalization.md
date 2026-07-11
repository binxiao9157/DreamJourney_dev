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
- 后端提交：`e1f06a8 feat: canonicalize knowledge privacy metadata`；生产锁等待修订：`d6d13be fix: bound knowledge maintenance lock wait`。
- iOS/QA 提交：`190d65f test: guard knowledge privacy canonicalization`。
- 生产部署：服务器及 API 容器运行 `d6d13be`，health 为 production/Postgres。
- apply 前 full Postgres 备份：`/opt/backups/dreamjourney/task20-pre-maintenance-20260711-144201.dump`，权限 600，大小 71985 bytes，SHA-256 `971db1d39ba8795900b273f94d1ace460bf7bca3e8d901ed96859970e2f095e6`。
- pre-dry-run：21 users、21 snapshots、12 changes、7 receipts；待处理 4 个 change mutation、2 个 receipt result、2 个 V2 receipt hash；`invalidRecordCount=0`。
- apply：上述 8 个 metadata/hash 更新一次完成，`invalidRecordCount=0`。
- post-apply dry-run：所有 `changed` 计数为 0。
- 线上新 V2 mutation smoke：首次响应、duplicate receipt replay、change feed 的 canonical mutation 完全一致；raw title 不出现，raw/canonical 同 operation ID 重试保持幂等。
- sentinel 写入后的最终 dry-run：22 users、22 snapshots、13 changes、8 receipts；所有 `changed` 计数仍为 0。
- 生产报告只保存在服务器权限 600 的私密目录，未提交 Git，未记录 token、用户/source/entity ID 或知识正文。

## 非目标

- 不改 Stitch UI，不做真机。
- 不处理 Widget/Family/semantic cache/change-feed compaction。
- 不迁移历史 source identity。
