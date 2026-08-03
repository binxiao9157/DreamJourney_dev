# Round 3B1 核心数据与 authority 合同方案

## Problem Definition

当前 `archive_items`、KBLite graph、`memories` 与多类 JSONB payload 语义重叠。需要用可实现的逻辑关系模型明确 Owner Vault、Subject、Source、Candidate、MemoryVersion、Conversation/Citation、DataRights 和可选域，并从约束层阻断跨 Owner 关联和 legacy projection 反向成为 authority。

## Proposed Solution

1. 定义 `subject` 与 `vault`：subject 是不可枚举身份主体，vault 是单个 Owner 私密数据边界；家庭/Visitor 通过 grant，不共享 owner ID。
2. 定义 Source/Ingestion 表：source、source_object、extraction_result；本地 draft 不进入 server Source authority。
3. 定义 Memory authority：memory_candidate、candidate_evidence、decision_receipt、memory、immutable memory_version、correction_link。
4. 定义 Conversation：conversation/message/answer/citation/feedback；citation 绑定具体 MemoryVersion，assistant 输出不自动成为 Source。
5. 定义 privacy/rights/audit：processing basis、consent、grant/work authorization、rights request/execution、retention hold、audit event。
6. 为 Publication/Visitor、Voice/DH、Family/Care、TimeLetter 给出独立 schema boundary 和核心外键，不进入 Owner 核心必填字段。
7. 每个 aggregate 规定 ID、vault/owner/persona、state/version、timestamps、hash/evidence、唯一/FK/check 和 delete semantics。

## Acceptance Criteria

- 至少覆盖 20 个核心逻辑表/aggregate，并标明 authority/projection/runtime。
- Source → Candidate → Decision → MemoryVersion → Citation/Correction lineage 完整。
- 所有私密业务 FK 使用同 vault 约束；resource ID 冲突不能转移 owner。
- 状态转换和并发 version/receipt 规则明确。
- JSONB 只承载单模块、versioned、allowlisted content，不作为跨模块 polymorphic store。
- optional module 数据独立且可关闭。

## Verification Plan

1. 走查创建文字 Source、确认/拒绝 Candidate、纠正 Memory、Owner QA citation。
2. 走查重复 command、跨 vault FK、删除 Source、撤权和 retention hold。
3. 走查 legacy Archive/KBLite/memories 的可迁移与 needs-review 分支。
4. 静态检查表/字段/约束/状态/optional boundary 数量。

## Risks

- 把逻辑 schema 写成过度具体 SQL，提前冻结开放产品决策。
- 复合 vault FK 增加实现复杂度，但缺少它会把跨账号隔离只留在应用层。
- versioned content JSONB 可能再次膨胀，必须限定 schema 和索引字段。

## Assumptions

- 新 ID 由服务端生成 UUID v4；排序使用时间列，不继续从手机号派生 ID。
- 具体 DDL/migration 脚本在 Round 3C/开发路线图落地。
