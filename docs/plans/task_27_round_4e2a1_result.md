# Round 4E2A1 typed Execution Registry 结果

## Summary

已新增确定性执行注册表生成器和 canonical JSON，精确覆盖 13 Package、115 Work Item、1840 个源字段。复核时将 Package DAG 从错误的单节点合并模型修正为 `START/EXIT` milestone DAG，因此既保留 S1-01 与 S1-02/03 的阶段依赖，也不会制造 readiness 循环。

## Done

- 新增 `generate-product-v4-execution-registry.py`，自包含解析 16 字段、Gate 正/负语义、紧凑/范围 WI 依赖、priority 和 canonical JSON。
- 新增 `DreamJourney_V4_路线执行注册表_V1.0.json`，包含 schema、source hash、counts/enums、13 Package controls、115 Work Item controls 和保守 baseline。
- 每个 Package 有 releaseClass、authorityLock、selectorBand、defaultExposure、start/exit dependencies 和 migrationGateRefs。
- 每个 Work Item 有 priorityClass、releaseClass、authorityLock、PLANNED/STOP|NO_GO/UNASSIGNED、requiredGates/MISSING evidence、directDependencies 和唯一 stableRank。
- Optional 全部 `DEFAULT_OFF`；MIG 仅拥有 `MIGRATION_EVIDENCE`，不拥有业务 aggregate。
- `WI-S1-01-12` 对 `WI-S1-02-11` 的 exit 依赖不进入 start DAG；原文语义通过 `dependencyNotesHash` 保留。
- Package start/exit 分为 milestone 节点，保留 S0-01、S1-02、S1-03 的真实 start dependency 与 S1-01 的 exit dependency。

## Verification

- `python3 -m py_compile`：通过。
- 生成器 `--self-test`：通过；13 Package / 115 WI / 1840 fields。
- Work Item start DAG 与 Package milestone DAG：无悬空、自引用、重复或环。
- 双次生成 SHA-256 均为 `f1d919aa33d8f5c56b5d40beef81607db1132b9ea5981bc52015f18bc6992535`。
- `--check` canonical byte 校验：通过。
- canonical reference、traceability、Stage 1、Optional/Migration checks：通过。
- `git diff --check`：通过。

## Known Gaps

- Roadmap 后续加入 selector 章节后 source hash 会变化，需要重新运行生成器；这是预期的 stale detection，不是数据漂移。
- Selector action 与 replan 语义由 Round 4E2A2 定义；当前 JSON 不会自行把 STOP/NO_GO 升级为执行授权。
- Package typed control map 仍需后续独立总 checker 与 roadmap inventory 交叉验证。

## Artifacts

- `Scripts/QA/product-v4/generate-product-v4-execution-registry.py`
- `docs/product/DreamJourney_V4_路线执行注册表_V1.0.json`
