# Round 3C3C Provider Effect、Credential 与 Exit 迁移

## Problem

当前外部能力状态、credential、调用、callback、删除和本地 runtime 含义不统一；Provider timeout 可能已产生不可逆 effect，adapter 又可能被误认为资产可迁移。需要为 10 类 Provider 定义安全 credential、stable request、query/reconcile、callback、delete、canary 和 exit 迁移。

## Success Criteria

- 10 类 Provider 逐项编制 current→target→cutover→rollback/exit 矩阵。
- 长期 credential 全部服务端化；客户端只接真短期 scope credential或走代理。
- stable providerRequestId、request hash、receipt、query/callback binding 和 unknown outcome 明确。
- 不支持 idempotency/query/delete 的操作进入 manual review，不盲重试或假删除。
- 区分 accepted/terminal/business usable/external verified/deleted 等状态。
- 定义 Provider shadow/sandbox/canary、quota/cost/circuit breaker 和 asset exit。
- 至少 15 个 timeout、重复 callback、credential rotation、quota、删除和供应商退出场景。
- 增加静态门禁并同步 Evidence Matrix/Decision Register。
