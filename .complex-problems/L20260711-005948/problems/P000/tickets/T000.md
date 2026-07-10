# 知识 Mutation V2 与三方合并实施票

## Problem Definition

现有 revision/change-feed 能防止整图静默覆盖，但无法表达实体删除；当本机和远端同时改变时，客户端只能整体 local-wins，删除可能被恢复、单侧更新也可能被覆盖。需要在不破坏 v1 客户端和当前 Echo 主链路的前提下，建立实体级 delta 与稳定三方合并。

## Proposed Solution

将实施拆成三个相互独立的闭环：后端扩展 `POST /kb/mutations` v2 upserts/tombstones，并在 change feed 持久化 mutation metadata；iOS 增加每用户 remote base、纯数据三方合并和 v2 delta 生成，并保留旧后端 fallback；最后由主控增加跨仓库 smoke/release gate、状态文档和部署说明。公开 UI、向量检索和真机流程不变。

## Acceptance Criteria

- v2 upsert/tombstone 在 InMemory 和 Postgres 中原子应用，operationId 幂等、baseRevision 409 不回归。
- change feed 兼容返回权威 graph 和可选 mutation metadata，历史 v1 change 仍可读取。
- iOS 持久化 per-user remote base，以 base/local/remote 按 ID 三方合并并生成下一次 delta。
- local-only/无授权实体不上传且不被远端 tombstone 删除。
- 单侧更新、单侧删除、双方同改、malformed feed、用户切换均有非真机检查或测试。
- 原有 v1 smoke、release regression、模拟器与 generic iPhoneOS build 继续通过。

## Verification Plan

后端运行全量 unittest、FastAPI/delta/v2 smoke 和 diff check；iOS运行专用 Swift model/static gate、现有 knowledge pipeline gate、release regression 和 generic iPhoneOS build；用本地 FastAPI 模拟两个客户端执行 A 更新、B 删除、重复 operation 和 stale revision。线上部署不在本票执行范围。

## Risks

- 三方合并若把 local-only 混入 remote base 会造成隐私或误删，必须使用 scope 过滤并按用户分文件。
- mutation metadata 是新增 nullable 字段，数据库迁移必须幂等且历史行可读。
- 双方同时修改同一实体暂采用 local-wins，只能作为确定性策略并留 QA conflict trace，不能宣称自动解决业务冲突。

## Assumptions

- 服务端继续保存权威完整 graph，v2 delta 只改变 mutation 输入和 change metadata，不引入新数据库。
- 实体 ID 在所属类型内稳定且非空。
- 当前 P1 只做数据合同和 QA，不开放用户可见冲突处理界面。
