# 线上 Receipt Apply、幂等与关联 Smoke

## Problem

Dry-run 通过后，需要小批最小化历史 result，证明 identity/hash 不变、二次运行幂等，并复验在线知识与其他维护合同。

## Success Criteria

- Apply status=ok、failed=0，updated 与 dry-run candidate 一致。
- 前后 count/byKind/identityHash 完全一致，result bytes 不增加。
- Second dry-run candidate=0，second apply updated=0。
- Deployed knowledge smoke、privacy maintenance dry-run和change-feed compaction dry-run通过。
- 脱敏报告保存，状态文档更新。
