# Round 4E1B2：建立双向追踪Checker与负向证据

## Problem

生成一份看似完整的矩阵仍可能包含孤儿、错误反向边、状态越权或finding/package下钻缺失。需要独立checker从权威文档和roadmap重新计算集合与关系，不能只相信生成器输出。

## Success Criteria

- 新增`product-v4-traceability-check.py`，独立解析矩阵和权威源。
- 验证36/41/22/12/13/115集合、WI父子、FR双向边、DR关系/状态、finding→CR→package→WI和gate/status上限。
- 验证open/failed/expired G2–G4不得升级为VERIFIED，当前无PROD_VERIFIED FR。
- 内置负向self-test至少覆盖孤儿WI、缺反向边、非法ID、finding下钻缺失、decision状态漂移和状态越权。
- 全部Product V4检查与`git diff --check`通过，并有独立agent复审结论。
