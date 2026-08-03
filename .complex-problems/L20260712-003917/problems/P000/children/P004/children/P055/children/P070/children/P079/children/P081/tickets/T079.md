# 从 Roadmap 生成确定性 typed Execution Registry

## Problem Definition

需要把 Roadmap 中的人类可读 Work Item 和 13 个 Package 的执行控制属性转换为稳定 JSON，供 selector 与独立总 checker 使用。生成物不能成为第二套产品范围，也不能把所有未分配任务自动授权为可执行。

## Proposed Solution

新增生成器，复用已验证的 Work Item 16 字段解析和 Gate 语义，但独立维护 13 个 Package 的小型 typed control map：`releaseClass/authorityLock/selectorBand/defaultExposure/startPackageDependencies/exitPackageDependencies`。直接 Work Item 依赖从 `Dependencies` 字段展开完整 ID、范围和同前缀简写；未能分类的自然语言保留为 `dependencyNotesHash`，不伪造成结构边。输出 canonical JSON（sorted keys、固定缩进、UTF-8、末尾换行），附 schemaVersion、sourceHash、generated content counts 和 baseline state。所有 WI 当前为 `PLANNED`、`STOP`（Migration 为 `NO_GO`）、`UNASSIGNED`，Gate evidence 为 `MISSING`。

## Acceptance Criteria

- 生成器验证 13 Package、115 WI、16 字段/1840 总字段后才写 JSON。
- direct dependency 的所有结构化 ID 存在；同一 WI 无重复/self dependency。
- 13 个 authority lock 唯一归属业务/平台状态；`MIGRATION_EVIDENCE` 明确不拥有业务 aggregate。
- `CORE/OPTIONAL/MIGRATION` 分类准确，Optional default-off，stable rank 唯一。
- Gate 与纠错后的 traceability matrix 一致；状态仍为计划/阻断/未分配。
- `--self-test` 覆盖依赖展开、Gate、枚举和 deterministic JSON；双次 SHA-256 一致。

## Verification Plan

运行 syntax 与 `--self-test`；生成 JSON 两次并比较 hash；检查 counts 和五类代表 Package；与 traceability matrix Gate/parent/state 抽样对照；运行 canonical/traceability/Stage1/Optional checks 与 diff gate。

## Risks

- 自然语言 Package dependencies 需人工 typed map；map 只覆盖 start/exit 控制，不改正文定义。
- 直接 WI 依赖解析不应把 FR/DR/CR 或 C07 等迁移阶段误当 WI。
- JSON 生成时间不得进入内容，否则破坏确定性。

## Assumptions

- 当前全部 Gate evidence 为 `MISSING` 是保守事实；已有文档/静态检查不能自动升级。
- selector 语义由 P082 定义，本票只提供数据。
