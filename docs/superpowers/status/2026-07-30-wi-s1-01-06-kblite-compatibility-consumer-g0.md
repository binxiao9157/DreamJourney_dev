# WI-S1-01-06 KBLite Compatibility Consumer G0

日期：2026-07-30

## 范围

本轮补齐 Owner Truth KBLite compatibility read envelope 在 iOS 侧的受控消费路径：

```text
QA-only read envelope
-> typed parse
-> AccountLease request/commit/runtime fence
-> isolated compatibility cache
```

新增 `OwnerTruthKBLiteCompatibilityProjectionUseCase`。它只可在
`DJEnableOwnerTruthKBLiteCompatibilityQA` 开启时使用，并且只调用现有隐藏
`/v2/vaults/{vaultId}/kblite-compatibility/read-envelope` 合同。

## 已实现

- 请求前校验 QA gate、Vault 和当前 `AccountLease`。
- completion 前重新校验 lease；账号、session、generation 或 authority epoch 变化时，
  删除隔离缓存并忽略旧 completion。
- `ready` envelope 只写入既有
  `owner_truth_kblite_compatibility_v1.json`；QA view state 仅保留 epoch、checkpoint
  和 fact count，不把 confirmed fact 正文放入 UI state。
- `rebuilding`、错误、无效合同、gate 关闭或 lease 失效均 fail closed。
- 新增延迟回调、QA 关闭和独立缓存三组 XCTest，并将合同检查加入既有 KBLite QA gate。
- 修正该 gate 的宿主测试方式：原 `swift test` 无法在 macOS host 编译 UIKit XCTest，
  现改为 iOS Simulator XCTest，保留 generic iPhoneOS `build-for-testing`。

## 明确未做

- 未接入、读取、写入或合并 legacy `kb_graph`、`/kb/sync`、`/kb/mutations`、
  `KnowledgeSyncCoordinator` 或 `KBLiteManager`。
- 未把 compatibility facts 注入 `/context/build`、DialogEngine、Echo、Archive 或公开 UI。
- 未进行 KBLite cutover、legacy writer retirement、后端迁移、部署、Postgres、Provider 或真机验收。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
bash Scripts/QA/product-v4/run-ios-owner-truth-kblite-compatibility-gate.sh
```

通过内容：

- Projection-only static contract check。
- 原有 compatibility typed/cache static check。
- iPhone 17 Simulator `OwnerTruthContractsTests`：132 passed，包括本轮 3 条新用例。
- generic iPhoneOS Debug `build-for-testing`。

该结果仅构成 `WI-S1-01-06` 的本地 G0 兼容消费证据；正式 Projection-to-KBLite
cutover、legacy writer retirement 和所有适用 G1/G2/G3/G4 仍未完成。
