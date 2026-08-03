# Round 4B：Stage 0 七个安全止损工作包

## Problem

`WP-S0-01` 至 `WP-S0-07` 是当前 BLOCKER/HIGH 的生产前置，但尚未拆成可领取的小闭环；账号、AuthZ、credential、DB、删除、release policy 和 operations 之间的顺序若不明确，会互相覆盖或过早宣称完成。

## Success Criteria

- 为 `WP-S0-01` 至 `WP-S0-07` 分别建立稳定 atomic work item ID。
- 每项完整填写目的、风险/FR/DR/finding、依赖、iOS/后端/DB/运维路径、合同、迁移、flag、测试、部署、回滚、DoD、外部门和非目标。
- 明确可在无外部 Provider/真机时完成的内部止损，以及必须由强身份 Provider、真实 Postgres restore、凭据资产 Owner、Privacy/Legal 关闭的门。
- 给出 Stage 0 内部顺序和可并行项，不把增长指标、Publication 或 Voice 质量塞入 P0。
- 每个 package 至少形成一个可独立验证、失败可停止的 release increment。
