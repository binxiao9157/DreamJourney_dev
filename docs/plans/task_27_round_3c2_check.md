# Round 3C2 iOS、API 与 AuthZ 双轨 Rollout 成功检查

## Summary

R030 满足 P032 的文档级目标。设备内 account generation/store 隔离与服务端 typed API/Identity/AuthZ/Capability 已通过同一 lease/epoch/policy 合同闭合，不再依赖错误响应或本地 user 决定 Authority。

## Evidence

- R028/C028：Product Spec 第 29 节。
- R029/C029：Product Spec 第 30 节。
- 17 stores、20 iOS scenarios、11 API waves、20 security scenarios。
- Evidence Matrix 6.3/7.5 与静态门禁。

## Criteria Map

- iOS account/session/store：29.0–29.7。
- API/Identity/AuthZ/Capability：30.0–30.11。
- Compatibility/rollback：29.5、30.7–30.9。

## Execution Map

- 先测试/Actor/store scope，再移 credential/强身份/AuthZ；read shadow 和 command dry-run 通过后才与 W08 同步切 Authority。

## Stress Test

- A/B session/callback、global cache、shared token、404 fallback、AuthZ error、capability expiry和old client均有 fail-closed路径。

## Residual Risk

- 真实实现、独立组合安全复审、部署和产品参数仍未完成；这些进入 Round 3D/4，不得用本检查支持上线声明。

## Result IDs

- R028
- R029
- R030
