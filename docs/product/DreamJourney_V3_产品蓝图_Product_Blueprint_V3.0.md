
# DreamJourney V3 产品蓝图（Product Blueprint）

> **文档生命周期（Task 27，2026-07-12）**
> - 状态：`BLUEPRINT_WORKING_INPUT`，是 V4 的历史方向输入，不是目标 IA、阶段或架构的最终批准版本。
> - 可用于：追踪 Source/Memory/Conversation/Publication 等候选领域方向。
> - 不可用于：要求四 Tab 重构、把“认知平台”当 MVP 验收，或采用“完全可信/完全可控”等绝对承诺。
> - 当前权威：[V4 Product Spec](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)、[实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md)、[产品决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)。
> - 变更说明：本次只增加生命周期与权威说明；历史正文保留。V4 定稿后状态更新为 `SUPERSEDED_BY_V4`。

**版本：V3.0（Blueprint Draft）**
**目标：统一当前 iOS 工程、最新 PRD 与 Cognitive Memory Platform 架构。**

---

# 一、产品定位

DreamJourney 不是聊天机器人，也不是知识库。

它是一个围绕用户一生构建的 Personal Cognitive Platform（个人认知平台）。

核心闭环：

```text
记录
→ 理解
→ 确认
→ 形成长期记忆
→ 与自己对话
→ 授权分享
→ 数字分身
```

---

# 二、产品北极星

一句话：

> 帮助用户持续沉淀人生记忆，并在完全可控的前提下形成可信、可追溯、可分享的数字分身。

---

# 三、统一产品架构

```text
DreamJourney

├── Source
│   ├── Text
│   ├── Voice
│   ├── Image
│   ├── PDF / DOCX
│   └── Import
│
├── Memory
│   ├── Candidate
│   ├── Canonical
│   ├── Timeline
│   ├── Episode
│   ├── Reflection
│   └── Entity / Relation
│
├── Conversation
│   ├── Echo
│   ├── Owner QA
│   ├── Voice
│   └── Digital Human Runtime
│
├── Persona
│   ├── Identity
│   ├── Style
│   ├── Preference
│   ├── Voice Profile
│   └── Public Persona
│
├── Publication
│   ├── Draft
│   ├── Publish
│   ├── Withdraw
│   └── Public Index
│
├── Visitor
│   ├── Public Chat
│   ├── Public Voice
│   └── Share
│
└── Future
    ├── Family
    ├── Care
    ├── TimeLetter
    └── Digital Legacy
```

---

# 四、当前工程映射

## 可以直接保留（🟢）

- Echo
- Voice Runtime
- Digital Human Runtime
- Upload
- Account
- Sync
- Audio
- Provider 管理
- 多账号隔离

## 可以迁移（🟡）

- Archive → Source + Memory 入口
- KBLite → Memory Runtime / Knowledge Projection
- Memoir → Episode / Story
- Knowledge → Projection
- Profile → Persona UI

## 建议新增（🔵）

- Memory Inbox
- Canonical Memory
- Publication
- Visitor
- Persona State
- Reflection
- Episode

## 后置能力（⚪）

- Family
- Care
- TimeLetter
- Digital Legacy

---

# 五、推荐 iOS IA

```text
首页
│
├── 今日摘要
├── 最近记忆
├── 待确认
└── 继续对话

记录
│
├── Echo
├── Voice
├── Upload
└── New Memory

记忆
│
├── Candidate
├── Memory
├── Timeline
├── Reflection
└── Episode

分身
│
├── Persona
├── Publication
├── Visitor
├── Voice
└── Share
```

---

# 六、统一领域模型

```text
Owner
└── Persona
    ├── Source
    ├── Memory Candidate
    ├── Canonical Memory
    ├── Timeline
    ├── Episode
    ├── Reflection
    ├── Publication
    ├── Voice Profile
    └── Conversation
```

任何新功能都应挂载到以上模型，而不是新增平行 Domain。

---

# 七、实施路线

## Phase A（立即）

- Source
- Memory Candidate
- Memory Review
- Canonical Memory
- Echo

## Phase B

- Publication
- Visitor
- Public Persona
- Voice Consent

## Phase C

- Reflection
- Timeline
- Episode
- Persona State

## Phase D

- Family
- Care
- TimeLetter
- Digital Legacy

---

# 八、统一原则

1. Source 是唯一原始证据。
2. Canonical Memory 是唯一正式记忆。
3. Knowledge 是 Projection，不是真相。
4. Archive 是 UI，不是 Domain。
5. Profile 是页面，Persona 是领域对象。
6. Publication 永远独立于 Private Memory。
7. Visitor 永远只访问 Public Domain。
8. Voice 授权分为 Private 与 Public。

---

# 九、最终产品形态

```text
记录生活
      ↓
AI 提取候选记忆
      ↓
用户确认
      ↓
形成长期记忆
      ↓
AI 帮助回忆与思考
      ↓
用户主动发布
      ↓
数字分身服务家人、朋友和访客
```

这就是 DreamJourney V3 的统一产品蓝图。
