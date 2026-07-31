# WI-S1-01-07：V1/V4 Context 对照 iOS Typed Consumer G0

状态：`VERIFIED_LOCAL / QA_ONLY / DEFAULT_OFF / NOT_DEPLOYED / NO_CUTOVER`

相关后端基线：`DreamJourneyBackend main@9907365`

## 目标

为已存在的 QA-only 同请求 V1/V4 Context 对照接口提供 iOS 严格类型化消费者。该消费者只用于收集对照证据，不能改变公开 Echo 的 Context、生成、回退、权限或写入路径。

## 本轮实现

- 新增值最小化的 `OwnerTruthContextShadowCompare` DTO、请求相关性和 V1/V4 摘要类型。
- 严格校验 response/schema/policy 版本、`shadowOnly`、旧 Context 不变性、请求哈希/长度/intent 绑定、枚举状态和 typed citation 完整性。
- 递归拒绝含原始内容的字段；客户端只保留计数、哈希、状态和布尔完整性信号。
- 新增独立 `OwnerTruthContextShadowCompareClient`，通过 QA gate 调用隐藏的 `/v2/vaults/{vault_id}/context-shadow/compare`。
- 未把该调用接入公开 Echo、自动请求、generation context 或 cutover 判断。
- 按后端真实合同将 legacy `schemaVersion` 解码为整数 `1`，不假定不存在的字符串版本名。

## 验证

- `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-context-compare-check.py`：通过。
- `OwnerTruthContractsTests`（iPhone 17 Simulator）：`137/137` 通过。
- 未签名 generic iPhoneOS Debug 构建：通过。

## 明确边界

- 未请求已部署服务，未做 PostgreSQL、Provider、真实设备或公开 UI 验收。
- 本轮不声明 V1/V4 语义等价、检索质量、数据迁移或发布切换完成。
- 下一步如需接入证据包，只能在现有 QA gate 内保存值最小化摘要，仍不得将任一侧 Context 用作另一侧的 fallback 输入。
