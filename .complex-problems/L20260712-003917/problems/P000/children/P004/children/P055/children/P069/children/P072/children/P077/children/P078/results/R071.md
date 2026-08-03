# Gate 语义修复与追踪矩阵重生成结果

## Summary

已修复中文紧邻 Gate 的漏解析和明确否定语境的误解析，重新生成 115 个 Work Item 的 Gate/Ceiling。生成器与独立 checker 使用不同实现复算同一公开语义；真实矩阵、负向自测、确定性、全部 Product V4 checks 和 diff gate 均通过。

## Done

- 生成器改用 ASCII Gate token 边界，能识别 `G4产品`、`G2真实`。
- 生成器排除 `无G2/G3/G4`、`无G3真实调用`、`G3不适用`、`不依赖G3`、`无需G4`、`G3不发真实effect` 等明确否定语境。
- 独立 checker 以 token offset 落入否定 span 的不同算法复算适用 Gate，没有导入生成器。
- 生成器新增 `--self-test`；checker 的 `--self-test` 增加 Gate 正向、否定和混合语境。
- 重新生成 `DreamJourney_V4_路线追踪矩阵_V1.0.md`，修正 Work Item Gate 与 Ceiling。
- 在初始矩阵结果中明确旧哈希已被纠错快照取代。

## Verification

- 两个脚本 `python3 -m py_compile`：通过。
- 生成器 `--self-test`：通过。
- checker `--self-test`：六类负向矩阵变体和 Gate 正/负语义均通过。
- 真实矩阵 checker：`PASS`，集合为 36 FR / 41 DR / 22 Finding / 12 CR / 13 Package / 115 WI。
- 生成器连续两次输出 SHA-256 均为 `bea7130f01a04a9373fc8cc5f9314915f512eaabade723af1b8d0d0a6d44abf4`。
- 21 个非生成 Product V4 checks 全部通过。
- `git diff --check`：通过。
- 人工重点抽查：`WI-S1-03-01` 只保留默认 `G0`；`WI-MIG-01-05` 不含 `G3`；中文紧邻 `G2/G4` 条目已进入矩阵并正确提升 Ceiling。

## Known Gaps

- 当前仍从自然语言字段解析 Gate；新增否定表达可能需要补规则。Round 4E2 将建立显式 typed registry 和总路线 checker，消除长期启发式依赖。
- 本次只纠正路线文档和 QA 生成物，不代表任何 Work Item 已实现、部署或通过 G2-G4。

## Artifacts

- `Scripts/QA/product-v4/generate-product-v4-traceability-matrix.py`
- `Scripts/QA/product-v4/product-v4-traceability-check.py`
- `docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md`
- `docs/plans/task_27_round_4e1b1_result.md`
