# Round 4E1A：补齐 Safety、Persona 与 Media 路线缺口

## Problem

FR追踪发现`FR-SAFE-001`没有结构化危机/AI披露工作项，`FR-ACC-002`被宽泛挂在CreateSource却没有Persona Authority，`FR-SRC-001/002`虽声明Stage2后置却没有SourceObject摄入和processor原子项。直接做矩阵会产生虚假覆盖。

## Success Criteria

- 新增`WI-S0-06-09` AI披露/危机安全策略与同步响应门。
- 新增`WI-S1-01-11` Owner Persona Authority，和Voice/DH runtime/persona display分离。
- 新增`WI-S1-01-12` SourceObject真实摄入/对象引用合同，mock/local-only不冒充uploaded。
- 新增`WI-S1-02-11` media processor job/result/retry/delete传播，模型结果只生成Candidate。
- 每项16字段完整，更新Stage0/1计数、批次、checker和状态，不改变Owner text最小核心或Optional门。
