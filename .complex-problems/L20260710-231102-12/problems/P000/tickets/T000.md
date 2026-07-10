# 收敛 KBLite、后端 KB 与 Echo Context 的 P0 主链路

## Problem Definition

iOS 本地 KBLite 与后端 KB snapshot / Context Packet V2 当前双轨运行：用户切换时本地图谱没有显式 reload；知识提取可直接依赖客户端 DeepSeek；`syncKnowledge` 没有稳定业务调用点；`/context/build` 只记录 trace，没有驱动真实 Echo 回答；旧的 `query:nil` 最近摘要仍是实际回复的主要知识来源。这会导致跨用户内存残留、本地与后端知识漂移、隐私策略不一致，以及 QA trace 与用户实际听到的回答不一致。

## Proposed Solution

在保持现有公开 UI、ownership policy、`/kb/sync`、`/kb/snapshot/{userId}` 和 Context Packet V2 兼容的前提下，完成一个 P0 统一知识管线：后端增加 revision、幂等 mutation 和 change feed；iOS 增加按用户切换的 KBLite lifecycle、自动同步协调器和后端知识提取入口；Echo 在 final 用户回合按 query 请求 `/context/build`，把 selected context 传入真实回复生成，后端失败时才使用 query-scoped 本地 KBLite；旧 recent-summary 注入只保留为显式 fallback，避免重复上下文。

## Acceptance Criteria

- 进程内从用户 A 切换到用户 B 后，内存图谱只包含 B 对应文件内容。
- 后端 mutation 使用 operation ID 幂等，同一请求重复提交不会重复增加 revision 或实体。
- 客户端可以按 sinceRevision 拉取 change feed，并能继续使用兼容 snapshot。
- 正常联网知识提取调用后端 `/kb/extract`，失败/离线时执行可观察的本地规则降级。
- Echo 正常路径将 Context Packet selected context 注入真实生成，且不会再叠加 `query:nil` 最近摘要。
- 后端 Context 构建失败时，Echo 继续使用本轮 query 的本地 KBLite 上下文。
- 错误 bearer 不能同步、读取、提取或构建其他用户的知识上下文。
- 现有 Context V2 trace、数字人、声音复刻和 QA evidence bundle 合同保持兼容。

## Verification Plan

运行后端知识库单测、ownership 单测、FastAPI smoke、mutation/change-feed smoke 与 Context V2 smoke；运行 iOS 用户切换隔离检查、知识同步/提取静态或 launch-arg smoke、Archive-to-Echo/context smoke、release regression、`git diff --check` 和 generic iPhoneOS build。检查输出明确区分 backend context、local fallback 和 extraction fallback，不包含 provider key 或跨用户原始数据。

## Risks

- Echo 上下文调用是异步的，若直接阻塞语音回复可能增加延迟；需要超时和 generation token 防止旧回调污染新回合。
- 全量 snapshot 与增量 mutation 并存期间可能产生 revision 漂移；兼容接口必须采用同一后端 revision 生成规则。
- 本地提取结果和后端模型结果可能冲突；P0 仅做确定性合并和来源保留，不实现复杂公开审核 UI。
- KBLite、Archive context 与 Context Packet 同时存在时容易重复注入；生成入口必须只有一个知识上下文参数。

## Assumptions

- 后端 Postgres 和 InMemory store 都需要实现同一合同。
- 当前 global ownership mode 继续保持 shadow，但已注册 owner 路由继续 principal-bound enforce。
- P0 不引入 pgvector、外部向量库或新的公开知识库视觉设计。
- 真机验证不属于本任务完成条件，但 generic iPhoneOS build 必须通过。
