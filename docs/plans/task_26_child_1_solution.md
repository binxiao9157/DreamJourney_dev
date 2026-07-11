# 实现 Compact Receipt 双读与权威快照重放

## Problem Definition

新旧 receipt 必须可并存；旧 result 含完整 graph，新 compact envelope 不含正文。Reader 要在验证 fingerprint 后优先用关联 change 重建，change 已压缩时使用当前 snapshot，并保持 mutation/governance/archive delete 合同。

## Proposed Solution

在 knowledge store 层定义版本化 compact envelope helper。新 receipt 写入即最小化；Postgres 和 in-memory replay 同时接受 legacy/compact。Compact replay 查询 operation change，缺失时查询 current snapshot，V2 返回空 mutation，governance 使用 envelope 中 ID-only summary。匿名 legacy sync no-op 不再生成无意义 receipt。

## Acceptance Criteria

- 四种 operation kind 双读通过。
- 同 payload verified duplicate，异 payload conflict。
- compact result 不含 graph/upserts/实体正文。
- governance/archive duplicate 不重复副作用。
- 现有 iOS parser 合同不变。

## Verification Plan

扩充 knowledge store、governance、core/postgres 单测，运行后端相关与全量测试，并执行现有 knowledge smoke。

## Risks

- change 已压缩后的 duplicate graph 是当前 snapshot，而非历史时点 snapshot；响应显式标记 receiptCompacted，客户端将其作为最新权威状态。
