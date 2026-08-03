# Round 3B 数据、API、授权、任务与 provider 合同方案

## Problem Definition

Round 3A 已固定模块责任，但开发仍缺字段级 authority、typed `/v2` 请求响应、可执行 AuthZ、异步 job/outbox、对象存储和 provider 合同。若一次设计全部内容，容易让身份、安全和异步一致性互相掩盖，需要按可独立检查的合同面拆分。

## Proposed Solution

1. 数据合同：定义 Subject/Persona/Source/Candidate/MemoryVersion/Conversation/Citation/Rights/Optional aggregates 的关系模型、ID/owner/version/state/evidence/policy/timestamp 和约束；JSONB 仅留扩展元数据。
2. API/AuthZ 合同：定义 typed `/v2` commands/queries、principal context、OTP/session/service identity、ProcessingBasis/Consent/AccessGrant/WorkAuthorization/DataRightsAuthorization/RetentionHold、错误/幂等/并发/分页和 legacy facade。
3. Jobs/Provider 合同：定义 transactional outbox、job lease/retry/dead-letter/reconciliation、对象存储 upload/scan/delete、AI/OCR/ASR/TTS/Voice/DH/APNs adapter、provider capability/receipt 和 secret 边界。
4. 所有合同明确 optional module 的独立表和依赖，不向 Owner 核心 aggregate 添加可选必填字段。
5. 输出写入 Product Spec，并增加结构检查；本轮不生成生产 migration 或修改 API。

## Acceptance Criteria

- 核心 authority 对象有字段、状态、约束、owner/tenant 和版本规则。
- `/v2` 至少覆盖 Identity、Source、Candidate/Memory、Conversation、DataRights 的 command/query 合同。
- 六类 authorization object 与 user/machine/service principal 的判定可执行。
- outbox/job/object/provider 具有稳定 idempotency、lease、retry、receipt、delete 和 privacy 合同。
- optional modules 使用独立 schema/API，并可关闭。
- 当前 blocker/high 均能映射到明确合同和后续任务。

## Verification Plan

1. 用创建 Source、确认 Candidate、Owner QA、Correction、Export/Delete 五条核心流程走查字段和 API。
2. 用跨账号读取、撤权后 data-rights job、provider timeout、重复 command、worker crash 检查安全与幂等。
3. 用 TimeLetter、Voice/DH、Publication 三个 optional 场景检查核心表无污染。
4. 运行 Product V4 结构检查、后端 evidence check 与 `git diff --check`。
5. Round 3D 由独立 security/data/backend reviewer 复核。

## Risks

- 把完整 SQL/OpenAPI 写得过早，反而冻结未确认产品决策。
- 为所有未来模块统一抽象，形成巨大 polymorphic JSONB。
- service principal 或 DataRightsAuthorization 变成通用 system 绕过。
- provider receipt 记录过多用户正文或敏感样本。

## Assumptions

- 本轮产出逻辑 schema、API shape 与约束；具体 migration SQL 在 Round 3C/路线图实现。
- 未确认产品项保留 nullable/extension port 或默认 disabled，不作不可逆公开承诺。
