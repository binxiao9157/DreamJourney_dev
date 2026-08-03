# Round 4E2B1：独立 Roadmap 总 Checker 与八类负向 Fixture

## Problem

Execution Registry 和 Selector 已完成，但仍需不导入生成器的独立 checker 复算 Package controls、inventory依赖、13/115/1840、START/EXIT与WI DAG、Gate/evidence/状态和唯一selector，并证明错误会失败。

## Success Criteria

- Roadmap新增13行Package Control Registry，作为生成器与checker共同读取但不共享代码的显式权威。
- 新增`product-v4-roadmap-check.py`，独立验证Roadmap/Registry/Trace Matrix三方一致与全部执行不变量。
- `--self-test`覆盖缺字段、悬空依赖、DAG环、非法枚举、Optional进入Core、MIG第二Authority、双next action、expired/failed evidence仍promotion至少八类变体。
- 真实Roadmap总检查通过，但Header仍保持E2B pending，等待独立发布门。
