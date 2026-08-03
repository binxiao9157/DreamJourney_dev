# Round 3A1 iOS 目标分层与当前模块迁移方案

## Problem Definition

iOS 当前具备稳定 UIKit UI、TabCoordinator、Archive/Echo/Profile 功能和大量 runtime/QA service，但 ViewController 与 service 直接知道本地存储、后端 payload、feature flag 和 provider 状态。需要建立不改变画面的可测试分层和渐进迁移 seam。

## Proposed Solution

1. 保留 AppDelegate/Scene/TabCoordinator/UIKit，AppShell 只负责生命周期、导航、account scope 和 release policy。
2. Feature 层按 Capture/Archive Review、Owner QA、Profile/DataRights 和可选 Beta/Future 划分；ViewController 只绑定 ViewState/Intent。
3. Domain 层使用纯 Swift typed models/policies，不依赖 UIKit、URLSession、UserDefaults、AVFoundation 或 provider SDK。
4. Application/Repository 层编排 use case、authority API、local draft/cache/projection，不暴露 transport DTO。
5. Infrastructure 层放 backend client、DTO mapper、Keychain/files/SQLite-KBLite compatibility、analytics/receipt。
6. Runtime Adapter 层隔离 ASR/TTS/AudioSession/Tencent Digital Human/Photos 等设备与 provider。
7. 对当前模块分类并给出 Strangler 顺序：先 protocol/mapper/contract tests，再迁 feature，不重写 Stitch UI。

## Acceptance Criteria

- 六层依赖方向和 forbidden dependencies 明确。
- 核心 feature 与 Beta/Future feature 不形成反向依赖。
- local-only、cache/projection 和 authority 清楚区分。
- 至少 12 个现有模块映射到目标位置和迁移动作。
- 每步可在不改视觉和不破坏旧客户端合同下验证/回滚。

## Verification Plan

1. 抽查 imports/调用图验证 Domain 不依赖 UIKit/provider/store。
2. 以 Archive→Review→QA→Correction 路径映射每层责任。
3. 对账号切换、离线 draft、旧 KBLite 和 Voice runtime 检查 ownership/lifecycle。
4. 独立 iOS reviewer 评估是否会形成空壳 wrapper 或大爆炸重构。

## Risks

- 把现有 service 一一包 repository，重复而不减复杂度。
- ViewState 被后端 DTO 或 provider 状态污染。
- 可选功能的 model 继续进入 Owner 核心。

## Assumptions

- 本轮只写架构成果物，不移动生产 Swift 文件。
