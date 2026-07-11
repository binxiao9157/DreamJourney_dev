# iOS snapshot fallback 成功检查

## Summary

P002 满足严格解析、精确错误分类、单次恢复、并发身份保护和恢复后继续同步的全部标准。

## Evidence

- model smoke 与 coordinator static check 通过。
- 跨仓库 change-feed gate 通过。
- Simulator Debug build 成功。
- 主控审查修复了历史 partial graph 兼容缺口并补测试。

## Criteria Map

- snapshot 合同：typed parser smoke 覆盖身份、revision、时间、graph 类型与历史 partial graph。
- 单次 fallback：pull-session fallback ID 和静态检查覆盖。
- 非 compacted 错误不恢复：policy matrix smoke 覆盖。
- stale callback 不落盘：current pull guard 与静态顺序检查覆盖。
- 成功后继续 push：coordinator 顺序检查覆盖。

## Execution Map

- R001 对应 P002 唯一 one-go ticket T002。
- 改动仅涉及 iOS service 和专项 QA，不影响公开 UI。

## Stress Test

- 覆盖 410 code/status 不完全匹配、目标漂移、格式 gap、用户切换以及 fallback 重入预算。

## Residual Risk

- 真实部署合同与两个非真机构建的最终组合证据归 P003，不阻断 P002 成功。

## Result IDs

- R001
