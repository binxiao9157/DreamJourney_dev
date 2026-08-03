# Round 3C：Legacy 迁移、rollout、rollback 与退役

## Problem

Archive/KBLite/JSONB/本地会话已有真实与 mock 数据，不能全部升级或丢弃；新旧客户端和 provider callback 也会并存，需要 per-owner 可回滚切换而非永久双写。

## Success Criteria

- 定义 inventory、legacy status mapping、quarantine、migration receipt 和数据质量报告。
- 新 authority 单写，outbox 生成兼容 Projection；shadow 双读不形成双 authority。
- per-owner authorityEpoch、cohort、feature/release policy、kill switch 和 rollback 条件明确。
- 旧客户端兼容、最低版本、API deprecation 和 Projection 退役条件明确。
- 账号删除/RightsRequest/第三方异议同时覆盖 legacy quarantine。
- 每阶段有 precheck、迁移、验证、观察、rollback、exit criteria 和不可逆点。
- 该问题属于 T017，因为安全迁移决定架构能否在当前工程落地。
