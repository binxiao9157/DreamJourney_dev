# P3-S2：V4 完整非真机 Evidence Snapshot

日期：2026-08-06  
范围：M0、Stage 2、M1、M2 的既有非真机 gate 汇总；不启用默认关闭能力，不改变公开 UI 或发布策略。

## 本轮结论

统一 evidence runner 已在同一轮快照中通过四条 lane：

| Lane | 默认状态 | 通过的既有 gate |
| --- | --- | --- |
| M0 Owner Truth | `publicCore` | 后端 M0 evidence + iOS M0 非真机 release gate |
| Stage 2 私有媒体 | `closedPilotDefaultOff` | 后端媒体处理合同 + iOS Stage 2 UIQA |
| M1 本人私有声音 | `closedPilotDefaultOff` | 后端 Voice/DH readiness + iOS readiness + account lifecycle |
| M2 Publication / Visitor / 在世数字人 | `closedPilotDefaultOff` | 后端生命周期传播 + 外部清理合同 + 两条 iOS QA-only UIQA |

统一 manifest：

```text
runId=p3-s2-full-dea13b1-182984
iosRevision=182984f9d6d50f2b9bf61f20373b6a454063bbd4
backendRevision=dea13b1ff5189674d560b768d2eeb80903151b63
executionStatus=passed
releaseDecision=NO_GO
releaseDecisionReason=nonDeviceEvidenceCannotCloseExternalOrDeviceGates
```

临时、脱敏证据目录：

```text
/tmp/dreamjourney-p3-s2-unified/p3-s2-full-dea13b1-182984/manifest.json
/tmp/dreamjourney-p3-s2-unified/p3-s2-full-dea13b1-182984/report.md
```

## M0 后端证据

M0 先在当前 Backend 提交执行完整验证，再在已部署 API 容器内执行隔离 PostgreSQL 与部署态 smoke。最终 manifest 为：

```text
/tmp/dreamjourney-p3-s2-m0-deployed-manifest.json
backendCommit=dea13b1ff5189674d560b768d2eeb80903151b63
status=passed
stepCount=15
```

这 15 步包含迁移 replay、正式 Candidate 确认、访谈重放、家庭贡献、Context V2、`/ready`、鉴权 refresh、自然输入、路由认证、Owner A/B 隔离、数据权利、事件生命周期和公开范围默认关闭。

## 本轮 QA 修正

部署态 M0 执行发现 `backend-owner-truth-family-contribution-formal-postgres-smoke.py` 把历史家庭授权迁移 `0072` 错误地当作“必须始终是全局 schema head”。`0073` 至 `0083` 是后续的正常增量迁移，因此该断言会在正确数据库上产生假失败。

后端提交 `dea13b1` 将校验收敛为：

1. `migrator.verify()` 必须为 `ready`，继续保证当前 schema head 正确；
2. `0072` 必须存在于 `appliedVersions`，保证家庭授权合同没有缺失。

该补丁已推送并部署到服务器。没有放宽迁移一致性，也没有改动生产数据或 feature flag。

## 执行边界

本轮所有日志按统一 runner 的环境变量脱敏规则保存，原始临时日志已删除。通过不代表发布批准：

- M0：仍缺真实身份 Provider 与物理设备验收；
- Stage 2：仍缺真实对象存储/处理 Provider 与媒体设备验收；
- M1：仍缺真实训练/删除回执与真机音频质量、路由验收；
- M2：仍缺公开索引/外部清理回执、长会话设备验收，以及成年人安全/法务准入。

这些项需要作为独立外部或真机 Gate 处理，不能由 mock、shadow、默认关闭能力或模拟器结果关闭。
