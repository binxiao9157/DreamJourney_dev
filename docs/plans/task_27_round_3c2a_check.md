# Round 3C2A iOS AccountSession、Generation 与本地 Store 迁移成功检查

## Summary

R028 满足 P037 的文档级目标。账号/session、异步 lease、本地 store、draft、runtime、Widget 和通知已被纳入同一安全生命周期，当前 reviewer 发现的设备内 blocker/high 均有明确目标动作和验收场景。

## Evidence

- Product Spec 29.0–29.7。
- A01–A11 风险、S01–S17 store、I00–I08 waves、20 scenarios。
- DR-041 与 Evidence Matrix 6.3。
- iOS account/store rollout 及相关 V4 门禁通过。

## Criteria Map

- Actor/Lease/CAS：29.1–29.3。
- 17 类 store 与 owner proof：29.4。
- 测试/迁移/retirement waves：29.5。
- 冷启动/竞态/crash/清理：29.6。
- 本地草稿策略：29.7、DR-041。

## Execution Map

- I00 先建立测试；I01/I02 收敛账号与异步状态；I03–I06 分域迁 store/runtime；I07 保持 UI 做 canary；I08 才退 global writer。

## Stress Test

- local/session mismatch、A refresh/B login、A callback/B store、global same ID cache、crash journal、notification/widget 和 delete 均有 fail-closed预期。

## Residual Risk

- 本轮没有生产 Swift/XCTest/runtime 证明，只能作为路线图实施合同。
- 后端 Identity/AuthZ/API/capability 仍需 P038，客户端安全不能替代服务端安全。

## Result IDs

- R028
