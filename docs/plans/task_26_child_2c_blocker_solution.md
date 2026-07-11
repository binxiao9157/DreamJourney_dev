# Canonical Compare 与有界 Keyset 扫描

## Problem Definition

当前维护器把所有版本化 envelope 直接视为已压缩，无法清理伪 compact 脏数据；operation ID 和 user ID 的首页游标边界也不完整。

## Proposed Solution

对每一行统一调用 `compact_persisted_knowledge_receipt_result`，以转换结果和原 result 的深度相等作为 alreadyCompact 判定；不同则作为 candidate。Operation 分页首批使用无下界 SQL，后续页才追加 `operation_id > %s`，从而覆盖空字符串。用户发现改为 `user_id` keyset 分页，每页受 batch-size 限制，逐页结束后释放 coordinator 事务，再进入既有分用户维护。

## Acceptance Criteria

- Dirty compact 夹带 graph/mutation/身份/私有 summary 时不会跳过。
- Apply 后 dirty compact 转为 canonical envelope，第二次运行幂等。
- 空 operation ID 被扫描并按安全转换结果处理。
- 用户发现至少跨两页且无漏重，不一次 fetchall 全量用户。
- 报告计数和 bytes 在 canonical compare 后正确。
- 专项和全量回归通过。

## Verification Plan

扩充 fake Postgres fixture 与测试，运行 receipt maintenance smoke、后端全量 verify、py_compile 和 diff check。

## Risks

- 用户 keyset 分页仍依赖数据库扫描；线上 created_at 索引属于独立运维优化，不在 startup schema 中直接创建。
- 历史空 operation ID 不符合当前 API 合同，但维护必须显式处理而非漏扫。

## Assumptions

- P005 转换 helper 对 canonical compact 输入幂等，并能清除脏 compact 夹带字段。
