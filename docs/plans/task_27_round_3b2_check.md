# Round 3B2 Identity、AuthZ 与 /v2 API 合同成功检查

## Summary

R022 满足 P029 的文档级目标。强身份、session/principal、六类授权、36 个 `/v2` endpoint、错误/幂等/并发/分页/cutover 均有可执行合同；当前实现 blocker/high 已明确标为未完成。

## Evidence

- Product Spec 第 25.0 至 25.10 节。
- API/AuthZ static check：6 principals、36 endpoints、10 errors、13 scenarios。
- 独立安全 reviewer 对照当前 `main.py`，确认目标覆盖 fail-open、weak identity、system token、shadow/fallback、enumeration 和 missing `/v2`。

## Criteria Map

- Principal/fail-closed：25.0 至 25.3。
- OTP/session/service credential：25.1、25.2。
- 六类 authorization object/formula：25.4。
- `/v2` 核心 command/query：25.5、25.6。
- command/error/pagination/cancel/concurrency：25.5 至 25.7。
- legacy/system/provider secret 退役：25.9。

## Execution Map

- 先定义身份与 principal，再定义 AuthZ 公式，最后将公式映射到 endpoint/error/cutover。
- reviewer 发现的 production shadow 和枚举风险已补入 target 与 current evidence。

## Stress Test

- 跨 vault 404 + DB/repository deny；machine 无 WorkAuthorization deny；delete job 使用专用 DataRightsAuthorization。
- refresh reuse revoke family；不同 payload 同 commandId 409；并发 expectedVersion 只一方成功。
- AuthZ 未登记/异常/fallback 在 production deny。

## Residual Risk

- 目标 API 尚未实现，首发 identity provider 未确认。
- 真正 rollout、old-client threshold 和 token/security test 需路线图任务。

## Result IDs

- R022
