# 生成 typed 路线执行注册表并固定 Selector 语义

## Problem Definition

Roadmap 的 13 Package/115 Work Item 正文足以供人阅读，但执行器仍需从自由文本推断 package class、Authority lock、依赖、Gate、当前状态和优先级。没有机器注册表和固定 selector，agent 可能在相同事实下选择不同任务，或把 `STOP/NO_GO/UNASSIGNED` 误解为自动执行授权。

## Proposed Solution

1. 新增 `generate-product-v4-execution-registry.py` 和生成的 `DreamJourney_V4_路线执行注册表_V1.0.json`。生成器从 roadmap 精确抽取 13 Package、115 Work Item、16 字段、直接 Work Item 依赖和适用 Gate；只人工维护 13 个 Package 的有限枚举元数据（release class、authority lock、selector band、start/exit package dependencies）。
2. 每个 Work Item 输出 `packageId/priorityClass/releaseClass/authorityLock/lifecycle/decision/executionOwner/requiredGates/gateEvidence/directDependencies/stableRank`。当前状态全部来自路线事实，不伪造执行 owner 或通过证据。
3. 在 roadmap 增加 registry schema、生成边界、确定性 selector、tie-break、`PLAN_ASSIGN_OWNER` 与 `NO_EXECUTABLE_ACTION` 语义、incident/evidence expiry/open decision/dependency变化时的状态回退和 replan 规则。
4. 当前基线选择 `PLAN_ASSIGN_OWNER(WI-S0-03-01)`：它是无 start dependency 的 P0 credential stop-loss；这只是建议分配 Owner，不代表自动开始实现。`WI-MIG-01-01` 保持唯一可并行只读 inventory 候选，MIG 仅拥有 evidence/go-no-go record。
5. 更新 roadmap header/第6节，明确 Round 4 工作项与静态验收完成后仍待 Round 5 独立复审。

## Acceptance Criteria

- 生成 registry 精确包含 13 Package、115 Work Item、1840 Work Item 字段，ID/父子/依赖无缺失。
- 枚举与 authority lock 明确，Owner core、Optional、Migration 三种 release class 不混淆。
- 每个 WI 的 required gates、lifecycle/decision/owner 和 stable rank 可机器读取；相同输入重复生成 JSON 字节一致。
- Selector 当前输出唯一 `PLAN_ASSIGN_OWNER:WI-S0-03-01`，不把它标成 `IN_PROGRESS/GO/VERIFIED`；MIG C00 只作为次级只读候选。
- incident、expired/failed evidence、dependency/open decision 变化的回退与重排规则完整，G0/G1 不关闭 G2-G4。
- roadmap header 与 Round 4E 状态准确，仍是 Working Draft、待 Round 5。

## Verification Plan

运行生成器 self-test 和双次 SHA-256；抽查 S0-03、S1-01、S3-01、V0-01、MIG-01 的 class/lock/gate/dependency；验证 selector 输出及 `UNASSIGNED` 安全语义；运行已有 canonical/traceability/Stage1/Optional checks 和 diff gate。总 DAG/负向 fixture 由后续独立 checker 闭环。

## Risks

- 生成 JSON 不是新的产品范围权威；生成器必须声明 roadmap 正文和 Package 元数据映射的权威边界。
- 从自由文本提取 direct dependency 可能遗漏别名；总 checker 必须对无法分类的依赖 token 失败，而不是静默丢弃。
- 当前 `STOP/NO_GO` 不允许 selector 直接执行，只能产出 planning action。

## Assumptions

- `WI-S0-03-01` 作为当前首个 planning action 与既有 R0 critical path/credential stop-loss 一致。
- 所有真实实现、部署和外部门证据仍未由本轮产生。
