# Round 3A 系统上下文与 iOS/后端模块边界方案

## Problem Definition

当前 iOS 以 UIKit ViewController + 大量 Service 为主，后端以 FastAPI 单体和 PostgresStore 为主；它们可复用但业务责任交叉。需要定义目标模块和依赖方向，让后续 schema/API 设计有明确 owner，同时避免 SwiftUI/微服务等无关重写。

## Proposed Solution

1. 明确五个部署/运行单元：iOS App、Backend API modular monolith、Worker、Postgres、private object storage；第三方 provider 只经后端 ports。
2. iOS 保留 UIKit/TabCoordinator，建立 AppShell、Feature、Domain、Repository/Application、Infrastructure、Runtime Adapter 六层；本地只保留 draft/cache/projection/runtime，不持有 authority。
3. 后端在一个部署仓库内划分 Identity/AuthZ、Persona、Source/Ingestion、Memory Review、Projection、Conversation/Context、Data Rights/Jobs/Audit 和可选扩展模块。
4. 定义模块依赖只指向 domain contracts/ports；provider、store 和 legacy adapter 位于外层。
5. 对当前关键文件/模块逐项分类：保留、包裹适配、抽取、兼容投影、冻结/后置、退役。
6. 明确近期不引入微服务、Redis、专用向量数据库、事件总线或通用 Agent runtime 的证据门。

## Acceptance Criteria

- 系统上下文图和部署图明确数据/凭据流向。
- iOS 和后端目标模块有职责、拥有的数据/接口、允许依赖和禁止依赖。
- 当前至少 20 个关键模块/服务有迁移分类和理由。
- Public/Visitor、Voice/DH、Family/Care/TimeLetter 不进入 Owner 核心依赖环。
- 架构不要求改变当前 Stitch UI 或一次性拆分所有文件。

## Verification Plan

1. 用六条 Owner 核心用例穿过模块图，检查每步只有一个责任 owner。
2. 检查依赖图无 Domain→UIKit/provider/store 反向依赖和循环。
3. 对照证据矩阵逐项确认 current module 分类。
4. 独立 iOS/backend reviewer 检查可迁移性和过度设计。

## Risks

- 只改文件夹名称，没有改变 authority 和依赖。
- 把现有 Service 全部包一层造成重复抽象。
- Optional modules 反向污染 Owner 核心模型。

## Assumptions

- UIKit 与现有 coordinator 继续使用。
- 后端保持一个可部署单体，worker 可同仓库独立进程运行。
