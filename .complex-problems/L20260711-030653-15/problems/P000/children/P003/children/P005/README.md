# iOS Proposal Schema 与 Backend Client

## Problem

iOS 没有 proposal/persona metadata 的兼容模型，backend client 只能返回裸 `KBExtractionResult`。

## Success Criteria

- KBLite 实体 optional 增加 owner/persona/evidence/sourceTurn metadata，旧 JSON 可解码。
- 新增 proposal/envelope Codable 模型，覆盖所有 upsert/关系字段。
- backend client 请求发送 persona identity，响应优先解码 proposal 并验证基本 schema。
- Swift model smoke 覆盖完整 proposal 和 legacy extraction envelope。
