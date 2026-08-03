# Round 3A2a 后端现状与部署证据审计结果

## Summary

已基于 `DreamJourneyBackend main@4c0538b` 完成后端代码、部署合同和四条代表链路的证据审计，并写入 Product Spec 第 23.1 至 23.5 节及实现证据矩阵。当前后端可复用大量路由、receipt、lease 和 provider adapter，但不具备 V4 生产安全与模块边界；认证 fail-open、弱身份、静态 provider credential、跨 Owner 通用 upsert 和单连接 Postgres 是明确前置阻断项。

## Done

- 核对当前 58 条已登记 FastAPI 业务路由、18 张 Postgres 表和 30 个组件证据行。
- 形成 iOS/API/Postgres/host timer/mock storage/external provider 的 CURRENT EVIDENCE 拓扑和信任边界。
- 追踪 Owner Archive/Context、TimeLetter、Voice Clone/Tencent Audio Drive、Tencent Digital Human 四条当前链路。
- 明确 Git 可证明与必须由服务器/真机/provider 外部证据证明的边界。
- 记录三个生产 blocker：认证缺省 fail-open、手机号登录/恢复无强身份证明、静态 provider credential 下发。
- 记录 Postgres 单连接跨请求复用、通用 upsert 跨 owner、JSONB/无 typed API、非原子 job、副作用缺 outbox、mock storage 和 provider lifecycle 等高风险。
- 记录应保留的 route ownership、KB receipt/revision、refresh rotation、owner conflict、DH lease 和 dry-run maintenance 控制。
- 新增 `product-v4-backend-evidence-check.py`，后端 commit、route/table/组件基线变化时要求重新审计。

## Verification

- `product-v4-backend-evidence-check.py` 通过：commit `4c0538b`、58 routes、18 tables、30 component rows。
- `product-v4-docs-check.py` 通过：36 requirements、21 conflicts、39 decisions、43 review responses、4 lifecycle banners。
- 临时 venv 按后端 `requirements.txt` 安装依赖；`STORE_BACKEND=memory` 下 304 个单测通过。
- `git diff --check` 通过。
- 两个独立只读 reviewer 分别完成组件/安全审计和部署/运行拓扑审计；其 blocker/high 已并入成果物。

## Known Gaps

- 本机没有 Docker CLI，未运行本地 Postgres/Compose 集成测试；304 个通过的单测不能证明真实事务竞争和 schema 行为。
- 本轮未 SSH 服务器，未复核线上 checkout、`.env`、容器、Nginx、systemd timer、备份和 provider 配额。
- 未运行真实对象存储、APNs、视觉 provider、火山或腾讯 provider E2E。
- 审计只定义当前事实和风险；目标模块、commands/queries/events 与迁移顺序由 P027 完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-backend-evidence-check.py`
- `docs/plans/task_27_round_3a2a-backend-evidence.md`
- `docs/plans/task_27_round_3a2a_solution.md`
- `docs/plans/task_27_round_3a2a_result.md`
