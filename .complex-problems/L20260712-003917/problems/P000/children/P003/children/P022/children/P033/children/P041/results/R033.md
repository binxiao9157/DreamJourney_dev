# Round 3C3C Provider Effect、Credential 与 Exit 迁移结果

## Summary

已在 V4 Product Spec 中形成 Provider Effect、Credential、Callback、Canary、Fallback、Delete 与 Exit 的统一迁移设计，覆盖当前工程涉及及目标所需的 10 类外部 Provider。设计明确区分“配置存在、Provider 接收、终态成功、业务可用、外部验收、删除完成”，避免继续以单一 `ready/configured` 布尔值夸大能力；同时保持本任务边界，没有修改 iOS 或后端生产代码。

## Done

- 在 `DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md` 新增第 33 节，并明确其状态为 `RECOMMENDED TARGET / NOT IMPLEMENTED`。
- 定义 `ProviderOperationState` 与 `provider_receipts` 目标字段，覆盖 `credentialValid`、`sandboxVerified`、`accepted`、`terminal`、`businessUsable`、`externalVerified` 和 `deletionState`。
- 建立 F01-F10 Provider Migration Matrix，覆盖对象存储、扫描、OCR/Parser、ASR、LLM、Vision、TTS、声音复刻、腾讯数智人和 APNs。
- 定义 credential inventory 与 `candidate/active_for_new/draining_old/revoked/compromised` 轮换状态，明确客户端不得持有长期 Provider secret，静态 token 加伪过期时间不视为短期凭证。
- 定义稳定 `providerRequestId`、`requestHash`、unknown/manual review/dead-letter、回调签名/nonce/绑定/单调状态和事务更新规则。
- 定义 synthetic/sandbox、单 Provider 真实 canary、禁止高敏真实数据 dual-send、成本与配额熔断及 fallback 重新授权边界。
- 定义 V00-V11 Provider 迁移波次，包含 inventory、adapter、sandbox、receipt/reconcile、callback security、各 Provider cutover、delete/exit drill 和 legacy retirement。
- 定义 Provider asset portability、退出、重新采集/训练/授权和删除状态披露规则。
- 给出 22 个 Provider 验收与故障场景，并列出当前必须保持 UNKNOWN 的真实套餐、region、模型、删除 SLA、质量、成本和设备到达证据。

## Verification

- 已检查 Product Spec 存在 `## 33.` 及 `### 33.0` 至 `### 33.9` 完整章节。
- 已人工核对 F01-F10、V00-V11、credential rotation、unknown effect、callback security、fallback 和 exit 内容均落盘。
- 本轮未运行真实 Provider、真机、生产凭证或删除演练；文档明确未将这些能力标为已实现或已验收。

## Known Gaps

- 当前实现证据矩阵尚未新增 Round 3C3C 的 `7.8` 设计状态与外部验收边界。
- 尚未新增 `product-v4-provider-migration-check.py` 专用静态门，也尚未将第 32 节对象存储检查范围收口到第 33 节之前。
- 尚未执行 Round 3C3C 的完整文档检查、`git diff --check` 与问题级成功判定。
- 所有 Provider 的真实 credential scope、sandbox、质量、成本、region、idempotency、query/callback、删除和退出能力仍需后续外部验收。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md` 第 33 节。
- `docs/plans/task_27_round_3c3c-provider-effect-credential-problem.md`。
- `docs/plans/task_27_round_3c3c_solution.md`。
