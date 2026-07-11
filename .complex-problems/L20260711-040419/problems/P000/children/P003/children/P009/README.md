# iOS 治理 Schema、Metadata 与 Backend Client

## Problem

iOS 无法强类型表达四类治理 action，KBLite Codable 会丢弃后端 governance metadata，也没有治理 endpoint consumer。

## Success Criteria

- 强类型 action/correction/reference/summary 模型覆盖 confirm/reject/correct/deleteSource。
- 四类实体 optional governanceMetadata 可往返编码。
- Backend client 编码 schemaVersion=1、解析权威 graph/revision/summary。
- Archive delete client 支持稳定 operationId。
- Swift model smoke 和静态 guard 通过。
