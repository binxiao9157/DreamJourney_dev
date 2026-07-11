# 线上 Receipt Baseline 与 Dry-run 硬门

## Problem

在任何 JSONB 更新前，需要获取不含正文的 receipt identity/hash 聚合基线，并证明 dry-run 无失败、kind 合法、报告不泄露隐私。

## Success Criteria

- 保存 count/byKind/identityHash/resultBytes baseline，不输出用户 ID或正文。
- keep-days=0 dry-run status=ok、failedUsers=0、failed=0。
- byKind 仅包含 kb.sync/kb.mutation/kb.governance/archive.delete。
- Dry-run 后 baseline count/hash 不变。
- 候选数和预计 bytes 结果明确，可据此决定 apply。
