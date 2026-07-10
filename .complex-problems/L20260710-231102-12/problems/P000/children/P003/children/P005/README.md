# 后端生成上下文合同

## Problem

Context Packet 只有 selected/filtered/ranking 调试结构，没有供生成引擎直接消费的稳定、受限文本合同，iOS 无法在不重复实现 policy 的情况下安全注入 Echo。

## Success Criteria

- `/context/build` 兼容新增 `generationContext`，包含版本、文本、来源引用/计数与稳定内容哈希。
- 文本仅来源于通过 Context V2 policy 的 archive、KBLite fact、persona、care 候选。
- runtime voice/digital-human 状态及被过滤内容不进入文本。
- 空上下文和最大长度行为明确，现有 Context V2 合同与测试不回归。
