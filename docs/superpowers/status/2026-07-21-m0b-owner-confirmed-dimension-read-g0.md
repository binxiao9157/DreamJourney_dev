# M0-B Owner-confirmed Knowledge Dimension Receipt Evidence

日期：2026-07-21

## 本轮范围

后端 `main@8ee1b34` 将 M0-B 知识维度覆盖的确认边界收敛为独立、追加式的
Owner 确认回执：

```text
当前、可访问的 MemoryVersion
  + 精确 contentHash
  + Vault Owner 显式确认回执
  -> 可计入知识维度覆盖
```

`OwnerTruthKnowledgeDimensionReadService` 只读取现有 Owner Truth
`MemoryProjection` 和与其当前版本精确匹配的回执，输出仍仅包含无值的维度、
facet、计数和原因码。

此前的只读基线 `main@9869fa2` 曾接受嵌入 `MemoryVersion.payload` 的
`knowledgeDimensionEvidence`。该做法无法证明是独立的 Owner 确认，现已被
明确废弃：内嵌标注、KBLite facts 和模型标签均不能增加覆盖。

## 独立确认合同

隐藏 QA 路由：

```text
POST /v2/vaults/{vaultId}/memory-versions/{memoryVersionId}/knowledge-dimension-confirmations
```

它默认不可见，且要求同时满足：

1. `OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=true`；
2. `OWNER_TRUTH_KNOWLEDGE_DIMENSION_CONFIRMATION_QA_ENABLED=true`；
3. 已认证的 Vault Owner；
4. `X-DreamJourney-QA-Owner-Truth: 1`。

迁移 `0035` 新增 `owner_truth.knowledge_dimension_confirmation_receipts`：

- 不存储记忆原文、用户回答、Provider 输出或通用 JSON payload；
- 绑定 Vault、Owner/actor、authority epoch、当前 MemoryVersion、精确内容哈希、
  固定维度/facet 与确认方法；
- `(vault_id, command_id_hash)` 保证相同命令幂等；
- `(vault_id, memory_version_id, dimension)` 禁止覆盖同一版本的既有确认；
- 数据库拒绝更新和删除；
- 当 MemoryVersion 被替换后，旧回执自动不能参与当前覆盖，历史记录不被改写。

## 明确非目标

- 没有公开 API、公开知识地图、推荐文案、完成度百分比或 iOS/Echo UI 改动；
- 没有 Source、Candidate、DecisionReceipt、MemoryVersion 或 Projection 的写入；
- 没有 Provider 调用、模型抽取或从记忆文本自动推断维度；
- 没有把本 sidecar 计入当前 `WI-S1-01-03` 的完成状态。

## 验证证据

本地 G0：

```text
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
1040 tests passed

Owner Truth knowledge dimension confirmation gate
25 tests passed

git diff --check
passed
```

服务器 G2：

- 后端部署为 `main@8ee1b34`，API 镜像已重建；
- `migrate_db.py --verify` 报告 `expectedHead=0035`、`appliedHead=0035`、`status=ready`；
- 隔离临时 Postgres smoke 通过：默认隐藏、创建、幂等重放、内容哈希失效拒绝、
  追加不可改以及替换 MemoryVersion 后旧回执不再计入覆盖；
- `https://dreamjourney-api.liftora.cn/ready` 返回 `ready`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 通过 | 单测、负向校验、静态 Gate 与完整后端验证已通过 |
| G2 | 通过 | `0035` 已部署，隔离 Postgres smoke 已通过 |
| G1 | 未开始 | 尚无公开或 QA iOS 确认界面 |
| G3 | 不适用 | 本切片不调用 Provider |
| G4 | 未开始 | 不代表公开知识地图或产品发布决策 |

该证据只说明 M0-B 的安全确认边界已可验证，不代表 V4、M0-B 或当前 Registry
Work Item 的整体完成比例。
