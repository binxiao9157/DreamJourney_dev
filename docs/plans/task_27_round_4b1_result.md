# Round 4B1 账号、身份、凭据与发布止损结果

## Summary

`WP-S0-01/02/03/06` 已基于两份独立代码审计完成路线细化，共29个单结果Work Item、464个必填字段。四包通过AccountSession/user token/server principal/ReleasePolicy/credential broker形成单向依赖，没有重复创建session、owner、flag或secret Authority。

## Done

- Account/Local Isolation：8项。
- Release Scope Stop-Loss：8项。
- Identity/AuthZ Enforce：6项。
- Credential Stop-Loss：7项。
- 明确R0先做scan/contain/default deny，R1再做strong identity/account/route/resource enforce，最后drain/revoke/retire。
- 明确所有rollback保持signed-out/read-only/feature-off/forward rotation，不恢复auto-claim、anonymous/system、shared token或静态Providercredential。

## Verification

- R049/C050：iOS account/release路线通过。
- R050/C051：backend identity/credential路线通过。
- 合计29个唯一Work Item、464字段；架构/API/AuthZ/rollout/diff检查通过。
- 两份独立审计未读取或输出credential值，并保留G2/G3/G4未验证边界。

## Boundary

- 本结果是工程路线，不是安全修复已上线。
- 强身份Provider、真实Postgres、生产route canary、artifact抓包和Providerbroker仍为外部门。

## Child Results

- R049
- R050
