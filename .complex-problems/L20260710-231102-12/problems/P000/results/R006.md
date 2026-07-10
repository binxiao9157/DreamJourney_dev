# P0 统一知识库主链路实现结果

## Summary

已完成 P0 统一知识库主链路：后端提供 revision、幂等 mutation、change feed 和可直接用于生成的受控 Context Packet；iOS KBLite 按用户隔离并通过协调器与后端同步，知识提取以后端为主、本地规则为降级；Echo 每轮最终 ASR 使用 query-scoped Context Packet 注入真实 Dialog RAG，避免旧摘要双重注入。

## Done

- P001：后端知识 revision 与增量同步合同，覆盖内存/Postgres、一致冲突与部署态 smoke。
- P002：iOS KBLite 用户隔离、旧数据迁移、App Group 隔离、后端提取与串行同步协调器。
- P003：后端 generation context 与 iOS 每轮 Echo RAG 注入，包含超时、本地 fallback、turn/lifecycle/user 隔离。
- P004：跨仓库 release gate、generic iPhoneOS build、模拟器主链路 smoke、部署说明和状态文档。
- 保留 `/kb/sync` 兼容旧客户端，新客户端可使用 mutation/change-feed；未引入无必要的向量数据库。

## Verification

- 后端 182 个单元测试、FastAPI smoke、knowledge delta smoke、Context generation smoke、py_compile 和 diff check 通过。
- 部署态 knowledge smoke 在本地等价 FastAPI 环境通过全部关键合同。
- iOS 全量 release regression、模拟器 Debug、generic iPhoneOS、Archive -> Echo 和延迟回信通知 smoke 通过。
- `Archive -> Echo` 结果确认档案上下文已进入链路。

## Known Gaps

- 后端部署后需对真实 Postgres 环境运行 deployed knowledge smoke。
- 火山 ChatRagText 真实语义吸收和时序需后续真机验收。
- change feed 分页/保留策略、服务端知识删除 tombstone、混合检索/向量检索属于 P1/P2。

## Child Results

- P001 / R000：后端知识 revision 与增量同步。
- P002 / R001：iOS KBLite 用户隔离、同步与后端提取。
- P003 / R004：Context Packet 驱动真实 Echo 生成。
- P004 / R005：统一知识管线验证与交付收敛。
