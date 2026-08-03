# Round 3 目标架构与增量迁移路径结果

## Summary

Round 3 已把 Round 2 的产品模型推进为一套契合当前 iOS/FastAPI/Postgres 基线、可渐进迁移且经过独立复审的目标架构。Product Spec 第 22–34 节覆盖系统边界、数据/API/AuthZ、异步与 Provider、legacy backfill/cutover/rollback/retirement；设计明确禁止第二 Authority、大爆炸重写和用静态文档冒充生产完成。

## Done

- 建立 iOS 六层渐进边界，保留 UIKit、Stitch UI、现有 coordinator/store/runtime，通过 composition、typed port 与 AccountLease 逐步抽取。
- 建立后端模块化单体、API/Worker/Postgres/私有对象存储/Provider adapter 拓扑；微服务、Redis、专用向量库、Kafka和通用 Agent runtime 均设置进入证据。
- 定义 38 个核心逻辑对象、Source → Candidate → DecisionReceipt → immutable MemoryVersion → Projection/Conversation Authority 链及可选域边界。
- 定义强身份、6 类 principal、fail-closed AuthZ、36 个 `/v2` endpoint、错误/幂等/并发/分页和 legacy compatibility 合同。
- 定义 15 类 Job、事务 Outbox、对象存储、10 类 Provider port、业务完成与外部完成的分离语义。
- 建立 18 张后端表、12 类 iOS 状态、38 个目标组的 legacy catalog/backfill，以及 W/I/P/Q/U/O/Z/F/V/C 全套迁移波次。
- 建立 single Authority/authorityEpoch、五类 rollback plane、不可逆补偿、go/no-go、restore 和七类 legacy retirement manifest。
- 完成 iOS、后端、安全/隐私/运维三类独立复审和 22 项 finding disposition，收敛为 12 个风险与 13 个稳定 Round 4 工作包。
- 建立并通过 17 个 Product V4 静态检查器。

## Verification

- Product Spec 第 22–34 节连续完整；iOS 六层、后端 12 模块、36 FR、41 DR 均通过架构不变量检查。
- Data/API/AuthZ/Job/Provider/Object/Migration/Composite 的 ID、字段、场景和禁止模式由分域检查器验证。
- 22 项独立评审发现全部有唯一 disposition，无开放占位或未映射 BLOCKER/HIGH。
- 8 份 V4 文档的本地链接和绝对证据路径检查通过。
- 全量 17 个 Product V4 检查与 `git diff --check` 通过。

## Boundary

- Round 3 产出的是 `RECOMMENDED TARGET / NOT IMPLEMENTED`；没有修改 iOS/后端生产代码，没有执行部署、真实数据迁移、Provider、真机或生产灾备演练。
- 强身份 provider、地域/处理商、公开 Publication/Visitor、Voice/DH、Family/Care/TimeLetter 和迁移阈值仍受 Decision/External gate 约束。
- Round 4 必须保持既有 13 个工作包 ID 或提供一一映射，并将其拆成真正可执行的小闭环任务。

## Child Results

- Round 3A：系统上下文与 iOS/后端模块边界。
- Round 3B：数据、API、AuthZ、Job、对象存储与 Provider 合同。
- Round 3C：Legacy backfill、rollout、rollback、组合 cutover 与退役。
- R046：Round 3D 独立复审、处置与静态验收。
