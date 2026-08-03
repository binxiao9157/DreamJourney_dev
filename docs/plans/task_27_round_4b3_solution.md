# 规划最小运维证据域与 Stage 0 硬门

## Problem Definition

当前存在局部KB receipt、Echo trace、Provider log ID和静态QA，但没有统一operation/rights/incident/provider-cost事件、失败分母、严格readiness、redaction/retention与不可变evidence manifest；`skipped`还能被部分报告计为完成。`WP-S0-07`必须提供证据与stop-the-line，而不是复制各业务Authority。

## Proposed Solution

1. 建立9个 `WI-S0-07-*`：事件envelope、append-only evidence sink、route/operation分母、Rights evidence projection、Provider/cost、incident lifecycle、redaction/log治理、evidence manifest、strict readiness与R0/R1聚合门。
2. 每项填16字段，并明确业务状态仍由S0-02/04/05、S1-02和V0拥有；S0-07只消费receipt/event并形成观测证据。
3. 使用独立ops审计核实当前paths、报告与真实缺口；不输出credential或用户正文。
4. 建立Stage0七包coverage/status表、可并行顺序、首个小闭环与stop-the-line信号；无真实阈值时只定义测量字段/owner，不伪造数字。
5. 把`skipped/unknown/missing evidence`从“完成”改为对应gate的not-run/blocked/failure，并区分G0与G2–G4。

## Acceptance Criteria

- `WI-S0-07-01..09`连续唯一，144字段完整。
- 四类最小事件、分母、redaction/retention、incident和evidence manifest完整。
- Rights/Provider任务明确为projection/measurement，不创建第二Authority。
- Stage0七包均有当前判定、进入/退出、R0/R1、hard dependency和stop-the-line。
- `skipped`不再关闭required gate；无真实基线不写虚假阈值。
- 当前正文日志、伪redaction、临时Evidence和credential-like literal有明确整改与扫描任务。

## Verification Plan

1. 对照ops explorer精确路径和当前QA行为。
2. 检查9个ID、144字段与七包集成表。
3. 对照SOR-07/08、BAR-01/02/04/06/07及CR-11。
4. 运行jobs/provider、review、architecture、docs/link和diff检查；P055最终统一roadmap checker。

## Risks

- 可观测性平台化过度设计；近期只用模块化单体+Postgres append-only事件/结构化日志，不引入Kafka/独立监控平台。
- 记录过多会泄漏正文；事件字段allowlist、hash和retention先于instrumentation。
- 把无Provider/真机环境标失败会阻塞普通开发；按适用gate区分not-run与required failure，不混成passed。

## Assumptions

- 本票只写路线与Stage0 gate，不修日志或部署observability。
- 生产阈值、cost budget、RPO/RTO等待真实基线和Owner批准。
