# 建立 Legacy Receipt 转换与 Compact Privacy 兼容层

## Problem Definition

历史 full receipt 需要在数据库维护之前通过可单测的纯函数安全转换；现有 privacy maintenance 又会把缺少 mutation 的 compact V2 envelope 当作损坏数据并尝试重算 payload hash。

## Proposed Solution

新增 `knowledge_receipt_maintenance.py`，定义 legacy/full 到 compact envelope 的转换、候选识别、估算尺寸和结构化错误。复用 P001 compact helper，根据 receipt 表列传入 operation kind/id/schema，并从 legacy result 提取必要的 ID-only governance summary。修改 privacy canonicalizer 和 payload hash 逻辑：版本化 compact envelope 只做结构校验并保留现有 hash，legacy full V2 继续 canonicalize mutation 和重算 hash。

## Acceptance Criteria

- 四种 operation kind 均可从 legacy full result 转换。
- Compact 输入幂等返回，转换结果无正文/graph/mutation/重复身份字段。
- 缺失 revision、非法 result 或无法安全提取所需 governance summary 时返回明确错误。
- Privacy maintenance 识别 compact V2，不要求 mutation、不重算 hash。
- Legacy full privacy canonicalization 行为与测试不回退。

## Verification Plan

新增纯函数测试，扩充 `test_knowledge_privacy_maintenance.py`，运行相关单测、py_compile 和 diff check；后续 P007 再跑组合 smoke 与全量回归。

## Risks

- 历史 archive delete 可能没有 mutation 但有 item/cascade，需要只保留可验证的 ID-only summary，不能保留 item 正文。
- 历史异常 governance receipt 缺少可提取摘要时应跳过并报告，不应生成语义不完整 envelope。

## Assumptions

- Receipt 表列提供可信 operation identity 与 payload hash。
- P001 compact helper 是新 envelope 的唯一 writer。
