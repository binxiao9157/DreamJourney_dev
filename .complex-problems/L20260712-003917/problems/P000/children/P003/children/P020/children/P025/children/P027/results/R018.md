# Round 3A2b 后端目标拓扑与模块边界结果

## Summary

已基于 P026 的真实现状证据形成 DreamJourney V4 推荐后端架构：保留 FastAPI/Postgres 的模块化单体，同仓库同镜像分离 API/Worker 进程，引入私有对象存储、typed `/v2` contract、模块数据所有权、transactional outbox/job 与 provider adapter。目标方案优先修复生产安全/事务 blocker，并证明关闭所有可选域后文字 Owner Truth Loop 仍可独立运行。

## Done

- 定义 API、Worker、Postgres、Object Storage、Migration 与 External Provider 六类部署单元及 readiness。
- 定义 12 个业务/平台模块的 authority、commands、queries/events 和允许依赖。
- 明确跨模块写、万能 store、客户端 system/provider secret、optional-to-core 反向依赖等禁止项。
- 定义同步 command receipt、异步 outbox/job lease/provider receipt 和幂等合同。
- 给出 7 类关闭测试，证明 AI、Voice/DH、Family/Care/TimeLetter、Publication、APNs、对象存储不可用时文字核心仍能运行。
- 将 21 个当前组件映射到目标模块和迁移动作，保留 route registry、receipt/revision、refresh rotation 和 DH lease 等已有控制。
- 给出 0 至 9 的渐进实施顺序，先止损再 shadow/cutover，旧 58 route 作为兼容 facade。
- 为微服务、Redis、专用向量库、Agent runtime 和 Kafka 定义重新评估证据，近期不引入。
- 扩展静态检查，验证目标章节、模块、关闭测试、迁移矩阵和非目标进入门。

## Verification

- `product-v4-backend-evidence-check.py` 通过：58 routes、18 tables、30 current components、12 target modules、21 migration rows。
- `product-v4-docs-check.py` 通过。
- `git diff --check` 通过。
- 方案逐项覆盖 P026 的 auth fail-open、弱身份、static credential、owner upsert、single connection、JSONB/no typed model、job/outbox 和 provider lifecycle 风险。

## Known Gaps

- 字段级 schema、API/AuthZ 和 job/provider contract 留给 Round 3B；本轮不提供可直接生成 migration 的完整 DDL。
- 迁移 cutover、backfill、rollback 和数据校验细节留给 Round 3C。
- 本轮启动的独立 reviewer 未在限定时间内完成，已停止；Round 3D 必须使用新的独立 reviewer 对 iOS/后端组合架构做严格复审。
- 本轮未修改后端生产代码或服务器，目标方案不代表已实施。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `Scripts/QA/product-v4/product-v4-backend-evidence-check.py`
- `docs/plans/task_27_round_3a2b-backend-target-boundaries.md`
- `docs/plans/task_27_round_3a2b_solution.md`
- `docs/plans/task_27_round_3a2b_result.md`
