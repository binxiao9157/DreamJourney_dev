# Round 4E1B2 独立追踪检查器执行结果

## Summary

已新增不导入矩阵生成器的独立检查器，并证明六类负向变体会被拒绝。检查器对真实矩阵运行后发现中文紧邻 Gate 未被生成器识别，当前矩阵存在 84 项 Gate 差异和 55 项 Ceiling 差异，因此本次执行只能记录为部分完成，不能宣称追踪矩阵通过。

## Done

- 新增 `Scripts/QA/product-v4/product-v4-traceability-check.py`，独立解析 Product Spec、实现证据矩阵、决策登记册、Round 3 评审响应、V4 Roadmap 与生成矩阵。
- 覆盖 36 FR、41 DR、22 Finding、12 CR、13 Package、115 Work Item 的集合与双向关系检查。
- 覆盖 FR primary/deferred/supporting、DR 状态/关系/Owner/Gate、Finding→CR→Package→WI、Package/WI 父子、Work Item Gate/Ceiling/Lifecycle/Decision/Owner 检查。
- `--self-test` 已证明孤儿 Work Item、FR 反向边缺失、非法 ID、Finding 下钻错误、DR 状态漂移、无证据 `VERIFIED` 六类负向变体都会失败。
- Gate token 使用 ASCII 边界识别，能识别 `G4产品`、`G2真实` 等中文紧邻写法。

## Verification

- `python3 -m py_compile Scripts/QA/product-v4/product-v4-traceability-check.py`：通过。
- `python3 Scripts/QA/product-v4/product-v4-traceability-check.py --self-test`：通过，六类负向变体全部触发预期错误；基线错误数为 139。
- `python3 Scripts/QA/product-v4/product-v4-traceability-check.py`：按预期失败，共 139 项，其中 `GATE_MISMATCH=84`、`CEILING_MISMATCH=55`。
- 除 Gate/Ceiling 外，FR、DR、Finding、CR、Package、115 Work Item 的其他追踪检查没有报错。

## Known Gaps

- 当前生成器仍使用 Unicode `\b` 提取 Gate，会漏掉中文紧邻 token，生成矩阵尚未通过独立检查。
- 独立检查器当前会把 `无G2/G3/G4`、`G3不适用` 等否定语境也识别为适用 Gate；后续修复必须同时为生成器与检查器建立独立但语义一致的否定规则，不能只替换正则。
- 需要重新生成矩阵、重新计算 Ceiling、验证确定性，并运行全部 Product V4 checks 与 `git diff --check`。

## Artifacts

- `Scripts/QA/product-v4/product-v4-traceability-check.py`
- 本结果文件。
