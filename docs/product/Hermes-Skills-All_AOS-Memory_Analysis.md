# Hermes-Skills-All / AOS Memory 分析报告

> **文档生命周期（Task 27，2026-07-12）**
> - 状态：`STATIC_ANALYSIS_INPUT`，是 V4 的外部静态分析输入，不是 DreamJourney 最终产品或架构规范。
> - 可用于：定位 Hermes/AOS 局部概念、缺失证据和可借鉴原则。
> - 不可用于：证明完整 AOS 可构建/可部署、要求照搬 MemoryStore/Slot/TimeRiver，或导入该目录的配置、凭据和 memory 数据。
> - 当前权威：[V4 Product Spec](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)、[实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md)、[产品决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)。
> - 变更说明：本次只增加生命周期与权威说明；历史正文保留。V4 定稿后状态更新为 `SUPERSEDED_BY_V4`。

> 基于用户提供的 `Hermes-Skills-All.zip`
> 的静态分析，仅针对压缩包内容，不包含对任何远程服务器的访问或验证。

## 1. 总体判断

该压缩包不是单一项目源码，而更像一个 **Hermes Agent
工作环境快照**，包含：

-   Hermes Skills（约百个 Skill 文档）
-   AOS Memory 部分源码
-   配置文件
-   长期 Memory 数据
-   部分设计文档

**未发现完整的 Git 仓库。**

------------------------------------------------------------------------

## 2. 与 AOS Memory 的关系

发现了如下 MCP 配置线索：

-   服务名称：`aos-memory`
-   默认端口：`8720`
-   用于作为 Agent 的长期记忆服务。

压缩包体现的是：

    LLM
     ↓
    MCP
     ↓
    Memory
     ↓
    Skill

而不是把全部历史上下文直接发送给模型。

------------------------------------------------------------------------

## 3. 架构设计（已确认）

### AOS Memory

包含设计信息：

-   MCP Tool 层
-   HTTP API
-   MemoryStore
-   SlotManager
-   ForwardIndex
-   ScatterEngine
-   CodeIndex
-   InfoPool（黑板）
-   EventBus
-   TimeRiver
-   SkillLibrary

主要思想：

-   长期记忆
-   图关联
-   三温区 Memory
-   槽位自治
-   技能沉淀

------------------------------------------------------------------------

### Agent 执行链

    Screen
     ↓
    Perception
     ↓
    EventBus
     ↓
    Skill
     ↓
    Rule
     ↓
    LLM
     ↓
    Action
     ↓
    Verify
     ↓
    Memory

代码能够确认：

-   感知
-   点击
-   输入
-   滚动
-   验证
-   Skill Distill

------------------------------------------------------------------------

## 4. Go 工程线索

压缩包没有：

-   `.git`
-   `.git/config`
-   `go.mod`
-   GitHub Actions
-   Docker Compose

但源码 import 暴露了 Go module：

``` go
github.com/xiaoqi/aos-memory/internal/rizhi
github.com/xiaoqi/aos-memory/zhishiku
github.com/xiaoqi/aos-memory/zhishiku/eventbus
github.com/xiaoqi/aos-memory/zhishiku/multimodal
```

因此可以推断原项目名称应为：

    github.com/xiaoqi/aos-memory

但**无法确认该仓库是否公开存在**。

------------------------------------------------------------------------

## 5. 推测的项目结构

    aos-memory
    ├── cmd
    ├── api
    ├── mcp
    ├── internal
    ├── storage
    └── zhishiku
        ├── eventbus
        ├── multimodal
        ├── slot
        ├── scatter
        ├── skill
        └── memory

这是根据 import 推断，不代表压缩包中完整存在。

------------------------------------------------------------------------

## 6. 已包含内容

可确认包含：

-   Hermes 配置
-   Skill 文档
-   部分 Go 源码
-   Memory 文档
-   架构说明

未包含：

-   完整 MCP Server
-   完整 MemoryStore
-   完整 Go Repo
-   完整部署工程

------------------------------------------------------------------------

## 7. 安全观察

压缩包中包含了真实运行环境相关配置，应谨慎处理。

建议：

-   不公开包含敏感配置的原始包
-   将凭据迁移到环境变量
-   分享前统一脱敏

------------------------------------------------------------------------

## 8. 当前结论

可以确认：

-   这是 Hermes + AOS Memory 的工作环境快照。
-   可以确认大量设计理念与部分实现。
-   可以推断原 Go module 为 `github.com/xiaoqi/aos-memory`。
-   **不能仅凭压缩包确认存在可访问的 GitHub
    仓库，也不能据此判断远程服务器状态。**

## 9. 后续建议

建议继续开展：

1.  还原完整 Go 工程结构。
2.  梳理 MCP Tool 与 HTTP API。
3.  还原 MemoryStore 数据模型。
4.  分析事件总线与 SkillLibrary 的调用关系。
5.  输出完整 AOS Memory 架构白皮书。
