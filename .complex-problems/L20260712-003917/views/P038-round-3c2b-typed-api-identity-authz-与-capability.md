# P038: Round 3C2B Typed API、Identity/AuthZ 与 Capability Rollout

Status: done
Parent: P032
Root: P000
Source Ticket: T031 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P032/children/P038
Body: problems/P000/children/P003/children/P022/children/P032/children/P038/README.md
Ticket(s): T033

## Problem
当前 iOS 使用未版本化 route 和宽字典，用户请求可附 shared/system token；后端存在弱身份、ownership shadow/fallback；404/405 等错误又可能触发 legacy mutation fallback。需要设计从 legacy facade 到 typed `/v2`、强身份、fail-closed AuthZ 和稳定 capability snapshot 的双轨切流，避免旧客户端产生第二 Authority。

## Success Criteria
- 定义 typed domain client、legacy facade、route policy 和 request auth mode。
- 用户业务请求不携带 shared/system/provider credential；生产缺身份/策略 fail closed。
- 定义 challenge/verify、session/refresh CAS/reuse、logout/revoke 与 account lease 对接。
- 明确 read shadow、command dry-run、cohort cutover、legacy facade forwarding 和 `upgrade_required`。
- 401/403/404/409/5xx/timeout/unknown schema 不触发旧 mutation fallback。
- 定义 ReleasePolicy/Capability snapshot 字段、TTL、minimum client、cohort、四维成熟度和 optional feature 默认关闭。
- AuthZ shadow/enforce、route coverage、error neutrality 和 emergency pause 有可执行门。
- 至少 12 个路由/身份/AuthZ/capability/旧客户端故障场景。
- 增加静态门禁并同步 Evidence Matrix/Decision Register。

## Subproblems
- none

## Results
- R029

## Latest Check
C029

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P032/children/P038/README.md
- Ticket T033: problems/P000/children/P003/children/P022/children/P032/children/P038/tickets/T033.md
- Result R029: problems/P000/children/P003/children/P022/children/P032/children/P038/results/R029.md
- Check C029: problems/P000/children/P003/children/P022/children/P032/children/P038/checks/C029.md

## Follow-ups
- none
