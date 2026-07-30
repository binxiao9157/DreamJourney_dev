# WI-S1-01-07：同请求 V1/V4 Context 对照 G0

状态：`VERIFIED_LOCAL / QA_ONLY / DEFAULT_OFF / NOT_DEPLOYED / NO_CUTOVER`

后端提交：`DreamJourneyBackend main@9907365`

## 目标

为旧版 `POST /context/build` 与 Owner Truth V4 Projection Context 建立同一次、同一归一化 Owner 请求下的无正文对照证据。该能力只用于 QA；它不改变公开 Context 的权威来源，也不把旧版结果作为 V4 的兜底输入。

## 已实现

- 新增隐藏路由：`POST /v2/vaults/{vault_id}/context-shadow/compare`。
- 仅允许 Owner Truth QA 上下文访问；QA 默认关闭、跨 Vault 访问拒绝。
- 只接受空 intent 或 `echo_chat`；请求会归一化为同一 `intent/query` 后分别构建 V1 与 V4。
- 旧版构建强制绑定当前 Owner：`userId`、`digitalHumanId`、`personaScope=personal` 和 `lifecycleMode=sunlight` 都不接受调用方越权覆盖。
- 返回仅包含请求哈希/长度、计数、authority state、fallback 数量和 V4 typed citation 完整性；不返回原始 query、档案文本、KBLite facts、关怀内容、generation text 或 citation 标识。
- V4 Projection 先执行；只有先通过 Owner/Vault 边界后才会读取当前 Owner 的旧 Context。
- 旧 `/context/build` 响应、公开 Echo、Authority、Projection 写入和 Provider 调用均未改变。

## 本地验证

- 关联聚焦测试：`79/79` 通过。
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh`：`1653` 项后端单测及既有 G0/FastAPI/编译/差异检查 gates 通过。
- 测试同时断言：未启用的 V4 shadow 不读取旧 KBLite；compare 输出不含请求或 Candidate 正文；未就绪 Projection 只报告 `v4_no_personal_memory`；不支持 intent、跨 Vault 与 QA 未启用均失败关闭。

## 边界与后续

- 本轮没有 PostgreSQL、部署、真实 Provider、真机、上下文质量或公开切换证据。
- V1/V4 之间目前只对照请求关联、边界和结构性安全信号，未宣称语义等价或召回质量达标。
- 任何候选 cohort 切换仍须按 V4 计划完成独立的 PostgreSQL、观测、回滚和产品 Gate，不能由本对照路由推进。
