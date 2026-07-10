# iOS 知识三方合并与 Delta 同步

## Problem Definition

iOS 当前以本地 graph 全量覆盖远端，无法区分本地修改、远端修改和远端删除；多设备同步可能覆盖另一端数据，`localOnly` 内容也缺少明确的三方合并保护。

## Proposed Solution

新增纯 Foundation 的知识同步引擎，为每个用户持久化最近一次同步的远端 revision 与 graph 基线。按实体类型和 ID 比较 base/local/remote：单边变化保留，双方变化采用明确的 local-wins 策略并产生仅含类型/ID 的 QA 冲突摘要。由 base 到当前本地 graph 生成 v2 upsert/tombstone，调用新后端合同；当服务端不支持 v2 时回退现有 v1 全量同步。`localOnly` 或缺失同步 metadata 的实体始终只留在本地。

## Acceptance Criteria

- 每用户基线落盘，不跨用户复用；首次升级能建立基线而不把远端实体误判为删除。
- 四类实体按类型+ID 三方合并，覆盖本地单改、远端单改、双方改、双方删和远端删。
- 仅同步许可实体进入 v2 delta；本地私有实体不上传，也不因远端缺失被删除。
- 客户端支持 v2 request/response/change metadata，并在旧后端拒绝 v2 时兼容回退 v1。
- 冲突日志不包含知识正文，只记录计数、实体类型和 ID。

## Verification Plan

- 新增独立 Swift model smoke，覆盖基线升级、三方冲突、tombstone、隐私过滤、v1 fallback 判定和用户隔离。
- 运行相关静态检查、`git diff --check` 与 iOS Simulator/Generic build。
- 将 model smoke 接入 release QA 的可选 gate。

## Risks

- 当前策略为确定性的 local-wins，不等同于字段级 CRDT；冲突摘要必须保留，便于后续产品化升级。
- 老后端 fallback 只能保持既有全量同步语义，不能获得 tombstone 精度。

## Assumptions

- 远端 v2 mutation 返回权威 graph 和 revision。
- 可同步 scope 继续沿用现有 `generationAllowed` 与 `familyCircle` 合同。
- 本轮不改公开 UI，不引入向量数据库或设备依赖。
