# iOS 远端基线、三方合并与 Delta 生成

## Problem

iOS 当前只保存 revision/fingerprint，收到远端快照后无法判断本地与远端各自相对哪个基线变化，因而不能可靠处理删除和同实体双改。需要按用户持久化 remote base，并用纯数据三方合并生成 v2 delta。

## Success Criteria

- 每用户 remote base 与 revision 独立持久化，用户切换和旧回调不能跨用户读取或写入。
- base/local/remote 按类型和实体 ID 三方合并：单侧变化不丢失，双方同改确定性 local-wins 并输出 QA conflict summary。
- local-only/旧无元数据实体始终留本机，不进入 upserts，也不受远端 tombstone 删除。
- 由 base/local 生成 upserts/tombstones；v2 成功后更新 base，旧后端可降级 v1。
- 纯模型/静态检查、模拟器或 generic build 通过，不改变公开 UI。
