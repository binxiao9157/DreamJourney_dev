# WI-S0-07-01 最小 Event Envelope 与四类事件 Schema

日期：2026-07-16  
Work Item：`WI-S0-07-01`  
状态：`INTERNAL_READY / G0_VERIFIED / PERSISTENT_SINK_NOT_STARTED`  
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`  
Authority lock：`OPERATIONS_EVIDENCE`  
Lease：`ACTIVE`

## 本轮完成

- 后端新增版本化 `operation`、`rights`、`incident`、`providerCost` 四类事件模型。
- 公共 Envelope 固定为 `eventId/schemaVersion/type/operationId/correlationId/principalHash/resourceType/resourceIdHash/state/reason/attempt/occurredAt/env/build/redactionVersion`。
- 分类字段只接受机器码；route 不接受 query；hash 字段只接受 64 位十六进制摘要；时间必须带时区。
- Pydantic `extra=forbid` 拒绝正文、prompt、token、手机号、raw identity、媒体和音频字段。
- ReleasePolicy bounded recorder 保留原兼容响应，同时 shadow 输出 `operationEvents`。
- iOS 新增 Echo runtime 本地 mapper；Owner、turn 和 trace 在进入 envelope 前先做命名空间摘要。
- 建立 Stage 0 package mapping owner 清单：`2026-07-16-wi-s0-07-01-event-mapping-manifest.json`。

## 当前边界

- 本项只定义 schema、validator、mapper 和 shadow evidence，不建立通用 analytics 平台。
- 后端事件仍随现有 bounded recorder 生命周期存在；append-only 持久化、retention、受限查询属于 `WI-S0-07-02`。
- iOS mapper 只服务本地 QA diagnostics，不上传正文，不成为业务 Authority。
- Knowledge receipt、auth deny、rights receipt 和 provider cost 只有 mapping owner，本轮没有批量复制旧数据或开启新 writer。
- `WI-S0-06-08` 的 168 小时零使用观察不能靠进程内 recorder 完成；需在 `WI-S0-07-02` 接入持久化 sink 后重新建立可跨重启窗口。

## 验证

- 后端四类 schema 正例、extra-forbid、正文/secret/media/prompt 负例、时区和 hash 约束通过。
- ReleasePolicy shadow mapper 确定性与 value-free 字段检查通过。
- 后端 `STORE_BACKEND=memory` 全量 `347` 项测试通过。
- iOS operations evidence 静态 guard 通过。
- Release QA package 检查通过。
- iOS Debug 模拟器通用目标构建通过。
- `git diff --check` 在提交前执行。

## 下一步

进入 `WI-S0-07-02`：通过 versioned migration 建立 append-only evidence sink、retention class 和 system-only 查询；先接 release-policy 单一低风险 writer，并证明 API 重启后观察窗口仍连续。不得在该持久化门完成前删除 legacy runtime alias。
