# 委托 iOS/客户端独立架构复审

## Problem Definition

需要获得一份不由 Product Spec 编写者自证的 iOS 评审报告，验证目标分层与迁移是否契合当前 UIKit 工程，并识别全局状态、账户竞态、网络信任、runtime 生命周期和过度设计问题。

## Proposed Solution

委托独立 explorer 只读 Product Spec、Evidence Matrix、当前 iOS source、project/QA 和最近架构状态。要求其用 `IAR-01...` 编号，按 BLOCKER/HIGH/MEDIUM/LOW 输出证据、影响、建议、分类，并至少覆盖 composition、account/session、store、network/AuthZ、Echo/Voice/DH、Widget/notification 和 migration。

## Acceptance Criteria

- 报告至少引用 8 个具体 iOS 文件/脚本和 5 个 Product Spec 章节。
- 每项发现包含 ID、严重度、证据、影响、建议和分类。
- 显式检查双 Authority、客户端 owner/principal、跨账号 callback/store、global secret/flag、旧客户端兼容和过度设计。
- 给出“目标正确但实现尚缺”与“目标本身需修正”的区别。
- 提供至少一个压力场景和残余风险；不修改工作区文件。

## Verification Plan

主控检查报告引用文件存在、发现字段完整、严重度分布和覆盖主题；不在本票处理发现，只记录独立结果，由 3D4 综合。

## Risks

- 评审者可能只读文档不读源码；提示中强制源码引用与反证。
- 评审者可能把所有未实现都报为架构错误；要求分类并说明目标/实现差异。

## Assumptions

- Agent 为只读 explorer，不修改或回退工作区。
- 评审结果允许存在争议，3D4 才做 disposition。
