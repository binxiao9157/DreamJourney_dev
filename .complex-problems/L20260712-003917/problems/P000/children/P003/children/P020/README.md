# Round 3A：系统上下文与 iOS/后端模块边界

## Problem

现有 iOS ViewController/Services 和后端单文件路由承载了多个业务含义，需要在不重写 UIKit 或拆微服务的前提下定义清晰模块、依赖方向和当前代码迁移定位。

## Success Criteria

- 给出客户端、API、worker、Postgres、对象存储和 provider 的系统上下文与部署单元。
- 定义 iOS AppShell/Feature/Domain/Repository/Infrastructure/Runtime 层及允许依赖方向。
- 定义后端 Identity、Source、Memory、Conversation、Projection、DataRights/Jobs/Audit 和可选模块边界。
- 当前关键模块逐项标记保留、适配、兼容投影、后置或退役。
- 不引入无指标证明的微服务、Redis、专用向量库或通用 Agent runtime。
- 该问题属于 T017，因为数据合同和迁移需要稳定模块责任边界。
