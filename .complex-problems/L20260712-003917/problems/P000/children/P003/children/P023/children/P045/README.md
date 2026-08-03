# Round 3D1 iOS/客户端独立架构复审

## Problem

需要由独立评审者核对 V4 iOS 分层、AccountSession/Lease、store migration、typed client、UI/runtime 边界是否能从当前 UIKit 单 target 工程增量落地，并识别竞态、全局状态、过度拆分和迁移不可行点。

## Success Criteria

- 报告引用当前 iOS 源码/QA与 Product Spec 具体章节，不只复述目标。
- 覆盖 composition、account/session、repository/store、network/AuthZ、Echo/Voice/DH runtime、Widget/notification 和 legacy migration。
- 每项发现有唯一ID、严重度、证据、影响、建议和分类（文档缺陷/实现缺口/产品决定/外部验收）。
- 明确检查双 Authority、跨账号 callback/store、客户端 owner/principal、global secret/flag、旧客户端兼容和过度设计。
- 至少给出一个反证压力测试；无 BLOCKER/HIGH 也必须说明残余风险。
