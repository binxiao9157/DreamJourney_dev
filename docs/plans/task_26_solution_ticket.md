# 实现可重建的知识操作收据压缩

## Problem Definition

`kb_operation_receipts` 永久保存 payload fingerprint 是幂等安全要求，但当前 `result` 同时永久复制完整 graph 和 mutation，造成无界增长与历史知识文本旁路。receipt 不能直接删除，否则 change feed 已压缩后旧 operationId 可能被再次执行。

## Proposed Solution

定义 compact receipt envelope，仅保留操作身份、原始 revision、schema、非文本治理摘要和压缩元数据；fingerprint 列保持不变。重放 compact receipt 时读取当前 authoritative snapshot，构造 duplicate/verified 兼容响应和空 V2 mutation，不重新执行操作。Postgres 维护采用 dry-run-first、按用户 advisory lock 和可重复 apply。

## Acceptance Criteria

- compact receipt 不含 graph 或原始实体正文。
- mutation/governance/archive delete 的同 payload 重放安全，异 payload 冲突不变。
- iOS V2 mutation/governance 解析合同继续成立。
- 维护脚本默认 dry-run，apply 可重复且用户级失败回滚。
- change-feed compaction 继续识别 receipt 行。
- 单测、跨仓 gate、release regression 和非真机构建通过。

## Verification Plan

先写 compact/replay 单测和维护 fake-Postgres 测试，再实现共享 envelope helper、Postgres replay 重建、维护方法和 CLI；运行后端全量测试、知识 deployed smoke、本地跨仓 gate、默认 release regression、Simulator/generic iPhoneOS build，并在部署前执行生产 dry-run。

## Risks

- governance response 依赖 summary，compact envelope 必须保留只含 ID/动作的治理摘要。
- V2 iOS 要求 mutation 为对象，重建响应必须返回结构合法的空 mutation而不是省略字段。
- 维护与在线 mutation/change compaction 必须共用用户 advisory lock，避免压缩半写 receipt。
