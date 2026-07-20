# WI-S0-07-09 Stage 0 严格就绪判定 G0 基础

日期：2026-07-21
Work Item：`WI-S0-07-09`
状态：`G0_CONTRACT_VERIFIED / G2_G4_OPEN`

## 本轮范围

新增 `stage0_strict_readiness.py`，将 Stage 0 的 Gate 证据输入统一为
value-free 的 `GateResult`：

- 字段固定为 `gate`、`applicability`、`required`、`status`、`evidenceId`、
  `reason`、`checkedAt`、`expiresAt`。
- 只有 `required + applicable + passed + evidenceId + 当前有效 TTL` 才能计入
  当前通过。
- `skipped` 会标准化为 `notRun`；`unknown`、`missing`、`expired`、
  `blocked`、`failed` 都会阻止完成。
- 输入 schema、数组结构、重复 gate、无效时间窗和非机器码 reason 一律
  fail-closed，且不会回显未受约束的原始文本。
- 结果给出稳定的单一 `nextAction`，例如 `runRequiredGate`、
  `attachRequiredEvidence`、`reissueEvidence` 或 `resolveExternalBlocker`。

release regression 默认运行该**契约 gate**；它只验证判定规则没有漂移，不读取
线上生产数据，也不把尚未执行的 G2/G4 验收伪记为通过。

## 本轮不包含

- 不宣称 `WI-S0-07-09` 完成，不变更执行登记的完成数量。
- 不汇总真实 Provider、真机、Privacy/Legal 或生产演练证据。
- 不修改公开 UI、Echo、数字人、声音复刻或业务数据。
- 不替代已有 Evidence Manifest、Postgres smoke、release handoff 或人工发布审批。

## 验证

```bash
python3 -m py_compile \
  Scripts/QA/product-v4/stage0_strict_readiness.py \
  Scripts/QA/product-v4/stage0_strict_readiness_contract_check.py
bash Scripts/QA/product-v4/run-stage0-strict-readiness-gate.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
git diff --check
```

契约覆盖：全部当前通过、`skipped -> notRun`、缺失 evidence、过期 TTL、
not-applicable、重复 gate、非结构化 reason、输入 schema/shape 失配，以及
strict CLI 的非零退出行为。

## 当前验证阻断

完整 `run-release-regression.sh` 已尝试执行，但在本轮 gate 之前被既有的
`archive-context-snapshot-check` 编译清单阻断：
`MemoryArchiveItemFactory.swift` 已依赖 `ArchiveMediaMetadata`，而该静态
fixture 没有纳入其媒体存储依赖。该失败不由本 Work Item 引入，也没有在本轮
通过扩张 archive fixture 范围来掩盖。严格就绪专项 gate、release package
静态校验和 `git diff --check` 均已通过；总回归必须在该 archive QA fixture
单独修复后再重跑。

## 下一步

将现有 Echo readiness、Evidence Manifest 和部署 smoke 的**摘要**映射为此输入
格式，再在有真实 G2/G4 artifact 时做只读聚合。聚合器本身不能关闭外部 Gate。
