# 真实 Postgres Receipt Dry-run、Apply 与幂等验收

## Problem

Reader 部署后仍需验证线上历史 receipt 分布和真实 SQL。任何 apply 必须以无失败 dry-run 为硬门，并证明 identity/fingerprint 保留和二次幂等。

## Success Criteria

- First dry-run status=ok、failedUsers/failed=0、byKind 合法，脱敏保存。
- 前后 receipt 行数和 identity/hash aggregate 不变。
- 小 batch apply 成功，二次 dry-run candidate=0，二次 apply updated=0。
- Duplicate/conflict、privacy maintenance dry-run、change-feed barrier smoke 通过。
- 异常时停止 apply，不删除或猜测修复历史数据。
