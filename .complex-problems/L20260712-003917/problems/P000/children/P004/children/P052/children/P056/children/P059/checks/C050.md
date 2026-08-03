# Round 4B1A Account/Local Isolation 与 Release Scope 检查

## Summary

结论为 `success`。R049 使用当前源码和QA证据将两个package拆成16个可实施、可验证且外部门清晰的Work Item，没有把局部generation或本地flag误称为目标能力已完成。

## Criteria Map

- Atomic Work Items：满足，`WI-S0-01-01..08` 与 `WI-S0-06-01..08` 连续唯一。
- 16字段：满足，共256个必填字段。
- 账号/本地隔离：满足，覆盖session、refresh、lease、store/quarantine、global key、optional runtime和lifecycle。
- Release Scope：满足，覆盖server authority、TTL/offline、default-off、route/command、五轴状态、QA、release gate和retirement。
- 真实路径：满足，独立审计核实当前Swift/QA路径；新增类型明确标注为新增。
- 外部门：满足，G0/G1与G2/G3/G4分离，无Provider/真机/产品伪完成。

## Stress Test

- 明确旧版本auto-claim不能作为rollback；store迁移采用dual-read/single-write和quarantine。
- 明确refresh callback、delete callback、Voice timer和message cache都需account generation，不只覆盖登录页。
- 明确Provider ready不等于release visible，offline/expired不能沿用持久化true。

## Residual Risk

- Work Item尚未实施；真实A/B、Keychain/App Group、notification与真机边界仍待后续开发验收。
- S0-02 session/principal合同和S0-03 credential边界将在P060细化。

## Result IDs

- R049
