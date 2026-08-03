# 独立复算 Roadmap、Execution Registry、DAG 与 Selector

## Problem Definition

生成器自测和分散 checker 不能证明 typed Package controls、115项 registry、START/EXIT DAG、状态 ceiling 与 selector 没有共因错误。需要把 Package control map写回 Roadmap 可读权威表，再由不导入生成器的总 checker 独立复算并用负向变体证明失败能力。

## Proposed Solution

1. 在 Roadmap 6.2 增加 13 行 Package Control Registry，明确 `releaseClass/authorityLock/selectorBand/defaultExposure`；start/exit依赖继续由 Package Inventory 解析，MIG authorization由6.2文字约束。
2. 新增 `product-v4-roadmap-check.py`，独立读取 Roadmap、Execution Registry JSON 和 Traceability Matrix；验证13/115/1840、16字段、有限枚举、source hash、package controls/inventory依赖、START/EXIT milestone DAG、WI start DAG、Gate/evidence/Ceiling、rank、状态/Owner/lock和selector baseline。
3. 对Package Inventory的`S0-*/S1-*`简写独立展开；S1-01对MIG只验证`WI-MIG-01-08:authorization`，不把整个MIG包放入exit DAG。
4. `--self-test`在内存构造至少八类变体：缺字段、悬空依赖、WI/DAG环、非法枚举、Optional进入Core start、MIG第二Authority、双next action、expired/failed evidence仍promotion。
5. 总checker通过后，把 Roadmap header/第6节和baseline JSON的`round4Acceptance`从`E2B_TOTAL_CHECK_PENDING`更新为`ROUND4_STATIC_ACCEPTANCE_PASSED_ROUND5_PENDING`，仍不宣称工程实现。

## Acceptance Criteria

- Checker不import registry/trace生成器，精确复算13 Package、115 WI、1840字段和registry source hash。
- Package control表、inventory start/exit依赖、registry三方一致；milestone DAG与WI start DAG无环。
- WI parent/priority/gates/evidence/direct dependencies/stableRank/state/decision/owner/lock一致，任何外部门缺失时不能`VERIFIED`。
- Core不以Optional为start dependency；S3/V0/MIG default-off；MIG只拥有migration evidence。
- 相同baseline唯一输出`PLAN_ASSIGN_OWNER:WI-S0-03-01`，secondary candidate未选中；无双action。
- 八类负向fixture均触发明确错误类别。
- 全部Product V4 checks、registry/matrix确定性和`git diff --check`通过；Header仅标Round4静态验收通过、Round5待审。

## Verification Plan

运行checker与`--self-test`；分别篡改Roadmap/JSON内存副本；连续生成registry与trace matrix并比较hash；运行`Scripts/QA/product-v4`全部非生成脚本；运行links/docs checks和diff gate。最后人工抽查S0-03、S1-01/02、S3、V0、MIG及baseline action。

## Risks

- Markdown table parser必须按section/header识别，不能把其他表误作Package controls。
- Package start/exit不能合并成单节点图，否则会把合法阶段关系误判为环。
- 更新Header必须在总checker真实通过之后执行，不能为了通过检查提前改状态。

## Assumptions

- Registry当前没有真实evidence manifest，全部`MISSING`是保守事实。
- Round5仍负责产品、工程、安全三方独立复审，Round4静态通过不等于可实施或可发布。
