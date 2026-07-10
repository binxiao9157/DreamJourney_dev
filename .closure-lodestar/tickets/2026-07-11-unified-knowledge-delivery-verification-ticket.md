# 统一知识管线跨仓库验证与交付票

## Problem Definition

统一知识管线同时修改后端 revision/change-feed/context 合同和 iOS 用户隔离、同步、提取及 Echo RAG。必须用同一套 release gate、部署态 smoke 和状态文档证明两端兼容，避免后续维护重新产生双轨数据源或跨用户数据污染。

## Proposed Solution

执行后端全量测试与知识 smoke，执行 iOS 全量 release regression 并启用通用 iPhoneOS 构建，验证 Archive -> Echo 和延迟回信模拟器流程；新增部署态 knowledge smoke 与 release regression 可选开关；最后更新 Task 12 状态文档，明确已实现边界、旧端兼容、部署命令和未完成的真机/provider/P1 工作。

## Acceptance Criteria

- 后端 182 个单元测试、FastAPI smoke、knowledge delta smoke 与 Context generation smoke 通过。
- 部署态 smoke 可验证登录、revision sync、幂等 mutation、change feed、generation context 和 stale revision 409。
- iOS 知识管线静态门、全量 release regression、Archive -> Echo smoke、延迟回信 smoke 和 generic iPhoneOS build 通过。
- 两仓库 `git diff --check` 通过，新增脚本通过语法/编译检查。
- 状态文档准确记录 schema/version、数据流、隐私边界、部署方式与 P1/P2，不宣称向量库或线上真机语义验收已完成。

## Verification Plan

运行后端 `scripts/verify_backend.sh`；本地 FastAPI 上运行部署态 knowledge smoke；运行 iOS `RUN_IPHONEOS_GENERIC_BUILD=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh`；复核生成报告、截图和两仓库 diff；最后校验 Closure Lodestar 台账。

## Risks

- 部署态 smoke 需要有效后端地址与 token，本轮可先在本地等价 FastAPI 环境证明脚本，线上执行留给部署阶段。
- 火山 ChatRagText 的真实语义吸收仍依赖后续真机/provider 验收。
- 当前 change feed 为基础版本，未包含大规模分页、压缩和长期清理策略。

## Assumptions

- 本轮目标是 P0 统一知识主链路和非真机交付，不引入向量数据库。
- 旧客户端仍可使用 `/kb/sync`，新 mutation/change-feed 是增量兼容能力。
