# WI-S0-03-01 Credential Inventory 执行与验收记录

日期：2026-07-15
Work Item：`WI-S0-03-01`
状态：`INTERNAL_READY / EXTERNAL_BLOCKED`
Decision：`GO_FOR_REVERSIBLE_G0_G1_WORK`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`RELEASED_FOR_WI-S0-03-01`

## 1. 授权来源与范围

用户于 2026-07-15 明确创建长期开发目标，并指定从 `WI-S0-03-01` 开始持续执行。该授权只覆盖以下可逆工作：

- 无值 credential taxonomy、inventory schema 和 scanner。
- source/history、APP/IPA/dSYM、response/header、runtime/oslog/QA、backup、container/build-context 只读扫描。
- fixture、自检、release QA 接入和无值 evidence 报告。

本 lease 不授权：

- 输出、复制、解密或提交 credential 原值。
- 轮换、撤销或删除真实 credential。
- 调用真实 Provider、修改生产权限、发送真实用户数据或部署后端。
- 把缺失的资产 Owner、Provider 控制台、备份或 Release artifact 证据标记为通过。

## 2. G0 进入证据

- V4 文档基线提交：`9742a07`。
- Product V4 QA：25/25 通过。
- Registry selector：`PLAN_ASSIGN_OWNER:WI-S0-03-01`。
- Work Item 无 start dependency，当前实现限制为 scanner、fixture、QA 和只读 evidence。

## 3. 验收边界

完成内部实现后，状态最高为 `INTERNAL_READY / EXTERNAL_BLOCKED`。以下证据缺失时不得标记 `VERIFIED`：

- 资产 Owner 对 secret/public identifier/unknown 分类和 containment 的确认。
- Provider 控制台 credential version/rotation 状态。
- 生产备份、真实 APP/IPA/dSYM、runtime/oslog/header capture 的覆盖证明。

本文件及 scanner 报告禁止包含 credential value、完整 Provider response、Authorization header 或私有配置正文。

## 4. 实现结果

- `credential-inventory-policy.json`：定义 Provider/system/public identifier taxonomy、Owner、scope、containment、replacement path、占位符和双人 allowlist 规则。
- `credential-inventory-scanner.py`：支持 source/history、APP/IPA/dSYM、response/header、runtime/oslog/QA、backup、container/build-context；报告仅保留类型、无值指纹、位置、状态和 evidence ID。
- `run-credential-inventory-scan.sh`：统一 iOS/Backend 与外部 artifact/capture 根目录，支持 Release artifact coverage enforcement。
- `product-v4-credential-inventory-check.py`：覆盖 secret、public identifier、placeholder、code reference、private key、依赖目录、源码二进制、重复 generic 分类和 enforcement 正负样本。
- `run-release-regression.sh`：提供 `RUN_CREDENTIAL_INVENTORY_SCAN=1`；Release handoff 强制启用无值扫描。

scanner 会跳过依赖缓存和源码二进制，但会在 APP/IPA/dSYM artifact surface 扫描二进制可打印片段。具体候选只允许在无值报告内按 fingerprint 交给资产 Owner 复核。

## 5. 本地基线证据

最终无值报告：

`tmp/visual-qa/prd-stitch-ui/credential-inventory/20260715-wi-s0-03-01-final/credential-inventory.json`

- SHA-256：`9a5a1aec046c6cd684d3d2d53106f3c9ddea47970a9979832cff012508b0b5b9`
- 覆盖：`SOURCE / HISTORY / CONTAINER / APP / IPA / DSYM / QA`
- 唯一候选：316
- 唯一阻断候选：183
- observation：1,362，其中 `SECRET=450`、`UNKNOWN=269`、`PUBLIC_IDENTIFIER=246`、`PLACEHOLDER=208`、`REFERENCE=189`
- APP/IPA/dSYM 唯一阻断候选分别为 34/13/14；这些只是待 Owner 分类的无值 fingerprint，不能据此声称已确认真实 secret。
- 每条 observation 均有 `owner / containment / replacementPath / rotationStatus / rotationAction`，报告不含 `value/rawValue/context` 字段。

Release artifact 构建证据：

`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260715-wi-s0-03-01-release-artifacts/report.md`

- Release generic iPhoneOS build：通过。
- Bundle ID：本机覆盖 `com.yxj.dreamjourney.app`。
- `.app`、`.dSYM` 和仅用于扫描的 `.ipa` 已进入同一轮 inventory。

## 6. 验证结果

- credential inventory contract：通过。
- release QA package check：通过。
- shell syntax 与 Python compile：通过。
- Release generic iPhoneOS build：通过。
- `git diff --check`：提交前执行。
- Release enforcement：按设计因 183 个唯一阻断候选返回 STOP；资产 Owner 分类、containment/rotation receipt 未完成前不得放行。

## 7. 外部门与后续动作

以下 surface 未伪造本地证据，继续标记 `EXTERNAL_BLOCKED`：

- `RESPONSE / HEADER / RUNTIME / OSLOG`：需要受控环境 capture，且必须先经过 redaction。
- `BACKUP`：需要生产备份访问授权和只读扫描窗口。
- Provider 控制台：需要资产 Owner 核对 credential version、有效性和 rotation/revoke 状态。

`WI-S0-03-01` 已完成内部 scanner、Release 接线和可重复 artifact 证据，因此释放本 Work Item lease。下一执行项是 `WI-S0-03-02`；它只能实施 response kill switch/no-store 和测试，不得借本回执自行轮换或披露真实 credential。
