# Round 4E2B：Roadmap 总 Checker 与负向验收

## Problem

路线执行注册表完成后，需要一个不依赖分散旧 checker 结论的总检查，统一验证 13 Package、115 Work Item、1840 字段、typed metadata、依赖 DAG、跨 Lane 不变量和确定性 selector，并证明典型错误会失败。

## Success Criteria

- 新增 `Scripts/QA/product-v4/product-v4-roadmap-check.py`，独立解析 roadmap、execution registry 和 Work Item 正文。
- 验证数量/唯一性/16字段、枚举、父子、引用、start/exit dependency、无环 DAG、Gate/Ceiling、状态/Owner/Authority lock 一致。
- 验证 P0/Optional/Owner core/MIG 边界和 G0/G1 不关闭 G2-G4。
- `--self-test` 至少覆盖缺字段、悬空依赖、依赖环、非法枚举、Optional 混入 core、MIG 第二 Authority、双 next action、expired evidence 未重排八类负向变体。
- 固定相同输入多次运行 selector 输出一致，真实 roadmap 总检查通过。
- 全部 Product V4/links checks 与 `git diff --check` 通过。
