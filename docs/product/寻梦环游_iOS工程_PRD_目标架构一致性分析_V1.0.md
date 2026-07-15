# 寻梦环游：当前 iOS 工程、PRD 与目标架构一致性分析

> **文档生命周期（Task 27，2026-07-12）**
> - 状态：`HISTORICAL_ANALYSIS_INPUT`，是 V4 的历史分析输入，不是完整代码审计或最终开发范围。
> - 可用于：追踪早期术语冲突、模块映射和迁移问题。
> - 不可用于：证明当前工程成熟度、替代当前源码/测试证据，或直接决定公开范围与重构顺序。
> - 当前权威：[V4 Product Spec](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)、[实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md)、[产品决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)。
> - 变更说明：本次只增加生命周期与权威说明；历史正文保留。V4 定稿后状态更新为 `SUPERSEDED_BY_V4`。

**版本：V1.0（初步评审版）**
**日期：2026-07-12**
**适用对象：产品、iOS、后端、算法、测试、架构评审**

> 说明：本文档基于当前已提供的 PRD、此前整理的 Cognitive Memory Platform / CFL 方案，以及对当前 iOS 工程的初步结构判断整理。
> 由于尚未完成对整个 iOS 工程源码的逐文件审查，本文中的“工程现状”应视为初步判断，不能替代正式代码级 Architecture Review。

---

# 1. 文档目的

本文档用于回答以下问题：

1. 当前 iOS 工程、现有 PRD、以及目标架构之间是否存在冲突；
2. 哪些差异只是产品命名和工程命名不同；
3. 哪些差异已经形成领域边界风险；
4. 哪些内容应保留，哪些内容应统一，哪些内容建议重构；
5. 如何建立一套 PRD、iOS、后端、API 和数据库共同使用的统一领域模型。

---

# 2. 总体结论

当前三部分分别代表不同层级：

| 来源 | 主要作用 | 当前状态 |
| --- | --- | --- |
| 当前 iOS 工程 | 已实现或正在实现的客户端产品 | 现实实现 |
| PRD | 产品规则、权限、流程和 MVP 边界 | 产品基准 |
| Cognitive Memory Platform / CFL 方案 | 后端和认知系统的目标架构 | 演进目标 |

三者不要求完全一致，但以下内容必须逐步统一：

- 核心领域对象；
- 对象职责；
- 生命周期；
- 权限边界；
- 数据归属；
- 命名体系；
- iOS 与后端 API 的对象映射。

当前最主要的问题不是“功能方向相悖”，而是：

> **多个概念开始表达相近的数据与能力，但职责尚未完全统一。**

最明显的重叠集中在：

- Archive；
- Memory；
- Memoir；
- Knowledge；
- Persona / Profile；
- Conversation / Echo；
- Digital Human；
- Voice。

如果继续扩展而不先统一，未来容易出现：

- 同一数据在多个 Repository 中重复保存；
- UI 名称被误当成 Domain；
- 后端对象和 iOS 对象无法一一映射；
- 权限和状态由客户端推导；
- Memory、Knowledge 和 Memoir 互相调用；
- 功能增加后难以判断代码应放在哪个模块。

---

# 3. 三类差异的判断标准

## 3.1 可以保留：产品名称与领域名称不同

例如：

```text
Echo
```

可以是产品层名称，而底层领域对象仍然是：

```text
Conversation
RealtimeVoiceSession
Message
```

这类差异不构成冲突。

---

## 3.2 需要统一：同一概念存在多个名称

例如：

```text
Memory
Memoir
Knowledge
ArchiveItem
```

如果它们指向同一个后端对象或相互持有同一事实，就必须统一。

---

## 3.3 建议调整：UI 模块正在承担事实源职责

例如：

```text
ArchiveRepository
KnowledgeRepository
MemoirRepository
```

如果这些 Repository 都在保存用户人生事实，就会和 PRD 中的 Source / Memory 模型冲突。

UI 名称可以保留，但 Domain 和 Repository 应按事实对象划分。

---

# 4. 主要一致性与冲突分析

## 4.1 Archive 的定位

### 当前工程倾向

Archive 可能同时承担：

- 资料归档；
- 记忆展示；
- Memoir 展示；
- Knowledge 展示；
- 入口聚合。

### PRD 定义

PRD 中没有把 Archive 定义成核心领域对象，而是使用：

```text
Source
→ Memory Candidate
→ Confirmed Memory
→ Publication
```

### 目标架构定义

Archive 更适合被定义为：

> 一个聚合展示入口，而不是新的事实对象。

它可以组合展示：

- Source；
- Memory；
- Timeline；
- Episode；
- Reflection；
- Publication。

### 结论

**存在职责偏移风险，建议调整。**

建议：

```text
Archive = Feature / UI
Source / Memory / Publication = Domain
```

不建议继续扩展新的 Archive Domain Model、Archive Runtime 或 Archive 事实表。

---

## 4.2 Knowledge 的定位

### 当前工程倾向

Knowledge 可能已承担：

- 生成；
- 合并；
- 同步；
- 本地存储；
- 策略；
- Widget 快照。

这说明 Knowledge 已经接近平台级能力。

### PRD 定义

Knowledge 仅是 Memory Item 的一种类型：

```text
knowledge
```

并不是独立事实源。

### 目标架构定义

更合理的关系是：

```text
Source
→ Canonical Memory
→ Knowledge Projection
```

Knowledge 可以包括：

- 面向检索的结构化投影；
- 摘要；
- 主题索引；
- Widget Snapshot；
- 缓存；
- 派生上下文。

但它不应保存无法重建的唯一用户事实。

### 结论

**存在明显领域边界风险，建议尽快统一。**

建议：

- 保留 Knowledge 作为平台能力或 Projection；
- 不让 Knowledge 成为用户事实源；
- Knowledge 数据应能从 Source / Memory 重建；
- iOS 中的 Knowledge Sync 应明确是派生同步，而不是主数据同步。

---

## 4.3 Memory 与 Memoir

### 当前工程倾向

工程中可能同时存在：

```text
Memory
Memoir
```

### PRD 定义

PRD 使用：

```text
Memory Item
story
experience
event
```

没有独立 Memoir 领域对象。

### 建议定义

推荐：

```text
Memory = 正式记忆
Memoir = 面向用户的叙事或故事展示
```

Memoir 如果保留，应更接近：

- Story View；
- Episode Narrative；
- AI 生成后经用户确认的人生故事；
- 多条 Memory 的叙事聚合。

不建议让 Memoir 与 Memory 各自保存一套独立事实。

### 结论

**不是直接冲突，但必须定义派生关系。**

推荐：

```text
Canonical Memory
→ Episode
→ Memoir / Story Presentation
```

---

## 4.4 Persona 与 Profile

### 当前工程倾向

Profile 更多是用户资料与设置入口。

### PRD 定义

Persona 是数字人格容器，包含：

- 名称；
- 头像；
- 简介；
- 语言；
- 回答风格；
- 公开配置；
- 知识域；
- 声音授权。

### 目标架构定义

Persona 还会继续包含：

- Persona State；
- Value；
- Preference；
- Boundary；
- Communication Style；
- Public Persona Projection。

### 结论

**没有本质冲突，但需区分 UI 与 Domain。**

建议：

```text
Profile = 页面 / Feature
Persona = 领域对象 / Runtime
```

Profile 页面可以编辑 Persona，但不应取代 Persona Model。

---

## 4.5 Echo 与 Conversation

### 当前工程倾向

Echo 是产品中的核心交互能力，可能包含：

- 文字对话；
- 实时语音；
- 延迟回复；
- 陪伴式交互；
- 数字人对话。

### PRD 定义

PRD 使用的是通用领域语言：

- Conversation；
- Message；
- Realtime Voice Session；
- Owner Chat；
- Visitor Chat。

### 结论

**不存在冲突。**

建议保留：

```text
Echo = 产品层名称
Conversation / Message / VoiceSession = 领域层名称
```

需要避免的是在数据模型里使用 `EchoMessage`、`ChatMessage`、`VoiceMessage` 三套互不兼容结构。

---

## 4.6 Digital Human 与 Persona

### 当前工程倾向

Digital Human 可能作为独立 Feature 和服务接入存在。

### PRD 定义

数字分身由以下能力组合形成：

```text
Public Persona
+ Published Knowledge
+ Voice Profile
+ Visitor Conversation
```

### 目标架构定义

Digital Human 更适合是执行和呈现层：

- Avatar；
- Lip Sync；
- Realtime Session；
- TTS；
- Visual Rendering。

而不是独立事实源。

### 结论

**不冲突，但需明确依赖方向。**

推荐：

```text
Persona / Publication / Voice
        ↓
Digital Human Runtime
        ↓
Avatar / Realtime UI
```

不建议 Digital Human 自己保存长期 Memory 或公开知识副本。

---

## 4.7 Voice 与 Digital Human / Echo

### 当前工程倾向

声音能力可能分散在：

- Echo；
- Digital Human；
- Audio；
- Voice Clone；
- TTS / STT。

### PRD 定义

PRD 对 Voice 有明确独立生命周期：

- Consent；
- Sample；
- Validation；
- Training；
- Preview；
- Active；
- Pause；
- Delete；
- Private/Public Authorization。

### 目标架构定义

Voice 应作为独立 Runtime，由 Echo 和 Digital Human 调用。

### 结论

**存在未来重复实现风险。**

建议统一为：

```text
VoiceRuntime
├── AudioSession
├── ASR
├── TTS
├── VoiceClone
├── RealtimeSession
├── BargeIn
└── Route / Interruption
```

Echo 和 Digital Human 不直接管理底层声音供应商状态。

---

# 5. 领域模型层面的主要偏差

## 5.1 当前工程可能更偏 Feature-first

现有工程中各模块可能已经形成：

- 自己的 Repository；
- 自己的 Storage；
- 自己的 Context；
- 自己的 Sync；
- 自己的 Policy。

这种方式前期开发效率较高，但随着功能增加，会出现重复能力。

### 目标方向

推荐逐步演进为：

```text
Features
├── Home
├── Echo
├── Archive
├── Profile
├── DigitalHuman
└── Family

Domains / Runtimes
├── Identity
├── Source
├── Memory
├── Conversation
├── Persona
├── Publication
├── Voice
└── Context
```

Feature 负责用户体验，Domain / Runtime 负责业务事实和能力。

---

## 5.2 Repository 边界可能与页面绑定

如果出现：

```text
HomeRepository
ArchiveRepository
EchoRepository
MemoirRepository
KnowledgeRepository
```

需要判断它们是否只是聚合 Facade，还是各自保存事实。

### 推荐 Repository

```text
SourceRepository
MemoryRepository
ConversationRepository
PersonaRepository
PublicationRepository
VoiceRepository
ReflectionRepository
```

页面需要组合数据时，可以增加：

```text
HomeQueryService
ArchiveViewDataProvider
```

但不要再创造新的事实源。

---

## 5.3 客户端不能推导服务端状态

以下状态必须以后端为准：

- Memory Candidate 是否已确认；
- Publication 是否已发布或撤回；
- Voice Consent 是否有效；
- Voice Profile 是否 Active；
- Visitor 是否可以使用克隆声音；
- Source 是否处理完成；
- Memory 是否已被 Superseded；
- Account 删除是否完成。

客户端只缓存，不自行决定最终状态。

---

# 6. PRD 中建议补充的部分

## 6.1 Reflection 作为独立对象

PRD 已有 Reflection 思想，但建议补充：

```text
Reflection
├── type
├── evidence
├── time_range
├── confidence
├── status
├── version
└── expires_at
```

状态建议：

```text
draft
confirmed
rejected
expired
superseded
```

---

## 6.2 Persona State

建议增加：

```text
Persona State
├── identity
├── value
├── preference
├── communication_style
├── boundary
├── topic_policy
└── public_projection
```

并区分来源：

```text
configured
confirmed
inferred
published
```

---

## 6.3 Episode

多条 Memory 需要聚合成更完整的人生片段：

```text
Episode
├── title
├── time_range
├── members
├── entities
├── summary
└── status
```

Memoir 可以建立在 Episode 上，而不是和 Memory 平行。

---

## 6.4 敏感度与发布状态拆分

建议将原有类似：

```text
private
sensitive
never_share
publishable
published
```

拆成两个维度。

敏感度：

```text
normal
sensitive
highly_sensitive
never_share
```

可见性 / 发布状态：

```text
private
publication_candidate
published
withdrawn
```

这样更利于 iOS、API 和数据库统一。

---

# 7. 推荐的统一领域模型

```text
Owner
  │
  └── Persona
        │
        ├── Source
        │     └── Source Fragment
        │
        ├── Memory Candidate
        │     └── Evidence
        │
        ├── Canonical Memory
        │     ├── Memory Version
        │     ├── Timeline Event
        │     ├── Entity
        │     ├── Relation Observation
        │     ├── Episode
        │     └── Reflection
        │
        ├── Persona State
        │
        ├── Publication
        │     └── Publication Version
        │
        ├── Voice Profile
        │     └── Voice Consent
        │
        └── Conversation
              ├── Message / Turn
              └── Realtime Voice Session
```

---

# 8. iOS 推荐分层

## 8.1 Feature 层

```text
Features/
  Home/
  Echo/
  Archive/
  Profile/
  DigitalHuman/
  Family/
```

这些名称可继续保持产品感。

---

## 8.2 Domain 层

```text
Domains/
  Identity/
  Source/
  Memory/
  Conversation/
  Persona/
  Publication/
  Voice/
  Reflection/
```

---

## 8.3 Platform 层

```text
Platform/
  Networking/
  Persistence/
  Realtime/
  Upload/
  Audio/
  Sync/
  Observability/
  DesignSystem/
```

---

## 8.4 Application Runtime

```text
Runtime/
  ContextRuntime/
  VoiceRuntime/
  KnowledgeProjectionRuntime/
  SyncRuntime/
```

Runtime 数量应保持克制，不建议每个 Feature 建一个 Runtime。

---

# 9. 一致性矩阵

| 主题 | 当前工程倾向 | PRD | 目标架构 | 判断 |
| --- | --- | --- | --- | --- |
| Archive | 业务模块 + 数据聚合 | 未定义为 Domain | UI 聚合入口 | 需要收敛 |
| Memory | 已存在 | 核心事实对象 | Canonical Memory | 保留并统一 |
| Memoir | 独立概念 | 无独立对象 | Episode/Story 派生 | 需定义关系 |
| Knowledge | 可能接近事实源 | Memory Type | Projection / Runtime | 优先调整 |
| Echo | 产品能力 | Conversation | 产品名 + Domain 对象 | 一致 |
| Profile | 用户页面 | Persona 配置 | UI 层 | 一致但需区分 |
| Persona | 可能较弱 | 明确定义 | Persona Runtime | 需要增强 |
| Digital Human | 独立 Feature | 公开数字分身 | 执行 / 展示层 | 一致但需约束 |
| Voice | 分散能力 | 独立生命周期 | Voice Runtime | 建议整合 |
| Reflection | 可能已有展示 | 定义较轻 | 独立对象 | 需要补齐 |
| Timeline | 产品能力 | 有需求 | Memory Projection | 一致 |
| Publication | 可能未完全独立 | 核心 P0 | 独立公开副本 | 必须对齐 |
| Family | 产品扩展模块 | MVP 外 | 后续角色与授权 | 暂不冲突 |

---

# 10. 调整优先级

## P0：先统一，不立即大规模重构

1. 确认统一领域模型；
2. 明确 Archive、Knowledge、Memoir 的职责；
3. 明确 Memory 是唯一正式记忆事实主体；
4. 确保 Publication 使用独立公开副本；
5. 确保 Voice Consent 独立；
6. 统一 iOS 与后端 API 命名；
7. 建立状态枚举映射表。

---

## P1：逐步调整工程边界

1. Repository 从 Feature 导向转为 Domain 导向；
2. Voice 底层能力合并到 VoiceRuntime；
3. Knowledge 降级为 Projection / Runtime；
4. Digital Human 不直接持有长期事实；
5. Profile 与 Persona 分层；
6. Memoir 改为 Episode/Story 派生能力；
7. Context 构建从各 Feature 收敛到统一入口。

---

## P2：后续增强

1. Reflection 独立建模；
2. Episode 聚合；
3. Timeline Engine；
4. Persona State；
5. Family 授权；
6. TimeLetter；
7. Visitor / Public Persona 更细粒度权限；
8. Graph Projection。

---

# 11. 不建议现在做的事情

当前阶段不建议：

- 为统一命名进行一次性全工程重写；
- 立即拆成大量 Swift Package；
- 引入复杂 Redux 或全局 Event Bus；
- 把所有 Manager 重命名为 Runtime；
- 提前上 Graph DB；
- 为 Memoir 单独设计一套与 Memory 平行的后端；
- 让 iOS 本地 Knowledge 成为后端事实；
- 为 Archive 建立独立后端聚合数据库；
- 通过 Prompt 解决权限问题。

---

# 12. 推荐执行方式

建议按以下步骤推进。

## 第一步：建立领域词典

形成一份统一表格：

| 中文产品名 | 英文 Domain 名 | iOS 类型 | API 类型 | DB 表 |
| --- | --- | --- | --- | --- |
| 原始资料 | Source | `Source` | `source` | `sources` |
| 候选记忆 | Memory Candidate | `MemoryCandidate` | `memory_candidate` | `memory_candidates` |
| 正式记忆 | Canonical Memory | `MemoryItem` | `memory` | `memory_items` |
| 公开内容 | Publication | `Publication` | `publication` | `publications` |
| 数字人格 | Persona | `Persona` | `persona` | `personas` |

---

## 第二步：制作工程映射表

逐个列出当前工程中的：

- 文件夹；
- Model；
- Repository；
- Store；
- Coordinator；
- Service；
- Runtime。

并映射到统一领域对象。

结果分类：

```text
Keep
Rename
Merge
Move
Deprecate
Needs Review
```

---

## 第三步：只重构高风险边界

优先处理：

- Memory / Memoir / Knowledge；
- Publication；
- Voice；
- Persona / Profile；
- Digital Human 对事实数据的依赖。

低风险 UI 和导航不必同步重构。

---

## 第四步：前后端合同统一

建立：

- OpenAPI；
- 状态枚举；
- 错误码；
- Event 名称；
- ID 命名；
- 时间格式；
- 权限规则。

---

# 13. 最终判断

当前工程、PRD 和目标架构之间没有方向性相悖。

真正的问题是：

> **当前工程的产品模块已经自然生长出来，但 PRD 与目标架构使用的是更严格的领域语言，两者尚未完成正式映射。**

可保留的部分：

- Echo；
- Archive 作为产品入口；
- Digital Human 作为独立体验；
- Family 作为后续扩展；
- 当前 Feature-first UI 结构。

需要尽快统一的部分：

- Archive 不能成为事实源；
- Knowledge 不能取代 Memory；
- Memoir 必须定义为 Memory / Episode 的派生；
- Persona 必须与 Profile 分层；
- Voice 必须具备独立授权与生命周期；
- Publication 必须是独立公开副本；
- iOS 与后端必须使用统一状态和对象名称。

因此当前最值得做的不是继续增加抽象，而是：

> **完成一次基于真实源码的 Unified Domain Mapping 与 Architecture Review。**

该评审完成后，再决定具体哪些目录、Repository 和 Model 需要改动，可以避免不必要的大规模返工。

---

# 14. 后续正式评审输出建议

下一份文档建议为：

**《寻梦环游 iOS 工程与 PRD / Backend 一致性矩阵 V1.0》**

它应基于完整源码逐项列出：

- 当前真实类名和文件路径；
- 当前职责；
- 对应 PRD 条目；
- 对应后端领域对象；
- 是否一致；
- 风险等级；
- 建议动作；
- 改动影响；
- 推荐排期。

这将成为客户端重构与前后端对齐的直接执行依据。

---

**文档结束**
