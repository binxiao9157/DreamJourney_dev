# 新 V2 mutation 单一 canonical 隐私合同

## Problem

新 V2 mutation 的 graph 与 mutation metadata 分叉，客户端原始 source title 会进入响应、change feed 和 receipt，并影响 operation payload hash。

## Success Criteria

- normalize/fingerprint/apply/persist/response 使用同一 canonical mutation。
- raw/canonical title 重试幂等，kind/id/正文变化仍冲突。
- InMemory 与 Postgres sentinel tests 覆盖 response/change/receipt/replay，无 raw title。
