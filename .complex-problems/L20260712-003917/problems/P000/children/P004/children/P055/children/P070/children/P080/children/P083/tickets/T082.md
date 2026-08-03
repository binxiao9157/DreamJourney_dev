# 用独立解析器证明 Roadmap 和 Registry 可执行且会安全失败

## Problem Definition

当前生成器能够自证格式，但不能独立证明 Package controls 没被交换、自然语言依赖没有漏、milestone DAG正确、selector唯一或证据过期时不会越级。需要把小型control map显式写进Roadmap，再由独立checker跨Roadmap/JSON/Trace Matrix复算。

## Proposed Solution

先在Roadmap 6.2加入13行Package Control Registry。Checker只使用标准库，不import任何生成器；按section/table和Work Item heading解析Roadmap，按canonical JSON读取registry，按Work Item reverse section读取Trace Matrix。它独立实现Gate否定语义、compact/range dependency、Package inventory简写、START/EXIT milestone图和selector复算。Validation返回稳定错误前缀，`--self-test`在内存复制并篡改输入以证明八类失败能力。

## Acceptance Criteria

- Package control表13行与registry完全一致；inventory start/exit依赖独立解析并匹配。
- 13/115/1840、16字段、source hash、schema/enums、parent/priority/gate/evidence/rank/state/decision/owner/lock全部一致。
- Package milestone DAG和WI start DAG无环；Core start不含Optional，MIG evidence-only。
- Trace Matrix与registry的WI gate/parent/lifecycle/decision/owner一致，缺G2-G4证据不得VERIFIED。
- Selector baseline JSON恰一、复算currentAction和secondary candidate一致。
- 八类negative fixture分别产生明确错误前缀，baseline真实文档零错误。

## Verification Plan

运行syntax、checker、`--self-test`；人工抽查Package Control table、S1阶段milestone、WI-S1-01-12 exit-only依赖、MIG授权和current action；运行trace/registry check与diff gate。Header保持pending，不在本票发布Round4完成态。

## Risks

- Markdown parser若不处理code/table边界会误读selector JSON或其他表。
- 独立实现不能import生成器，但允许共同遵守Roadmap公开语义；代码结构和fixture必须不同。
- 负向self-test必须比较新增错误而非依赖baseline已有错误。

## Assumptions

- 当前baseline所有状态仍保守，checker无需读取真实部署或Provider证据。
- Header最终翻转由P084在全量检查后完成。
