# 两轮独立复审、发现处置与五份成果物定稿

## Problem Definition

Round 1-4已经形成产品定义、实现证据、决策、可执行路线、追踪矩阵与Execution Registry，但这些内容主要由同一主控流程逐轮推导，仍可能存在共同假设、术语漂移、证据过度外推、路线过度设计或外部门被文字掩盖。必须进行两轮独立复审，并把所有P0/P1发现闭环到权威成果物和最终验收清单。

## Proposed Solution

1. **Round 5A 第一轮独立复审**：并行启用三个互不代写成果物的审查者，分别审查：
   - 产品价值、用户闭环、PRD需求、信息架构、范围与决策一致性；
   - 当前iOS/后端证据、目标架构、迁移路线、测试/部署/回滚可执行性；
   - 隐私伦理、安全、数据权利、供应商成本/退出、运维、延迟与过度设计。
2. 每个发现必须具备稳定ID、严重度`P0/P1/P2`、文件/章节证据、可复现的不一致、影响、建议处置和建议Owner；禁止只给泛化评价。
3. **Round 5B 主控处置**：合并重复发现，逐项标记`ACCEPTED/FIXED/DECISION_REQUIRED/EXTERNAL_REQUIRED/REJECTED_WITH_REASON`；P0必须修复，P1必须修复或进入Decision Register并明确Gate，P2可登记后续。
4. 生成第五份成果物`docs/product/DreamJourney_V4_评审与验收清单_V1.0.md`，包含：成果物版本/边界、Review Finding disposition、FR/DR/CR/Package验收摘要、P0失败模式、不可逆决策、外部门、执行前检查、G0-G4证据要求、发布/回滚/退出条件、当前未授权事项。
5. **Round 5C 第二轮盲审**：使用未参与第一轮处置的新审查者，从三种视角复核修正后的五份成果物；只接受可定位的新发现或对既有处置的反证。
6. **Round 5D 最终收敛**：处置第二轮P0/P1，统一五份成果物的术语、状态、链接、版本、权威边界和当前实现成熟度；新增独立finalization checker，验证第五成果物、review disposition、双轮证据、哈希/链接/追踪与非过度声明。
7. 运行全部Product V4检查、生成确定性、最终checker、链接和`git diff --check`；只有全部通过后才能把五份成果物标记为`REVIEWED_BASELINE`，仍不得声称115项工程路线已实现。

## Acceptance Criteria

- 至少完成两轮有时间顺序和独立审查者证据的复审；第一轮至少覆盖产品、工程、安全/运维三种视角，第二轮不得由主控自审替代。
- 每条发现有稳定ID、severity、evidence、impact、disposition和verification；P0无开放项，P1无无理由开放项。
- 五份固定成果物全部存在，Product Spec、Evidence Matrix、Decision Register、Roadmap、Acceptance Checklist相互链接且权威边界一致。
- 36 FR、41 DR、22 Finding、12 CR、13 Package、115 Work Item仍保持精确追踪；开放Decision、EXTERNAL_REQUIRED与G2-G4不被错误关闭。
- P0失败模式、不可逆操作、数据权利、供应商退出、成本/并发/延迟、部署/rollback和真实设备/Provider门均进入最终验收清单。
- finalization checker能检测：缺少任一成果物、缺少任一复审轮、P0未处置、P1无理由、状态过度声明、数量漂移、链接断裂、Registry/Trace stale。
- 全部Product V4 checks、finalization checker正负自测、生成确定性和`git diff --check`通过。

## Verification Plan

1. 冻结Round 4哈希和当前五项成果物输入，记录两轮审查的审查者、时间、范围与文件基线。
2. 第一轮三个并行审查输出独立Markdown报告；主控只合并和处置，不改写原报告。
3. 修正成果物后运行所有现有checker，并生成第五成果物。
4. 第二轮使用新审查上下文复核所有五份成果物和第一轮disposition；对新增P0/P1继续处置。
5. 实现finalization checker及至少以下负例：删除成果物、删除review wave、未处置P0、P1无理由、把外部门标Done、计数漂移、链接断裂、Trace/Registry stale、把Working Draft误标工程已完成。
6. 最终执行全量脚本、双次生成哈希、链接扫描、敏感信息扫描和diff gate。

## Risks

- 多审查者可能产生重复或相互冲突发现；以证据和权威来源优先级做disposition，不以票数决定。
- 为追求“零发现”可能隐藏真实外部门；允许`DECISION_REQUIRED/EXTERNAL_REQUIRED`，但必须有Owner、Gate和禁止过度声明。
- 第五成果物若复制大量正文会产生新漂移；只收敛验收控制、引用权威ID和当前基线，不复制完整PRD/路线内容。
- Final状态容易被误解为工程完成；最终文案只能是文档`REVIEWED_BASELINE`，115个WI仍保持计划态。

## Assumptions

- 本轮不修改iOS/后端生产代码、不部署、不跑真机，只复审并定稿产品/架构/路线成果物及QA检查。
- 审查者只能读取仓库和输入资料，不能把未验证推断提升为事实。
- 无真实组织Owner、法律结论、Provider SLA或生产Gate证据时，相关项保持开放或外部依赖。
