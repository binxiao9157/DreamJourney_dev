# Round 4D：Publication、Voice/DH 与组合迁移工作包

## Problem

`WP-S3-01`、`WP-V0-01`、`WP-MIG-01` 分别涉及公开副本、高敏 Provider runtime 和跨域迁移。它们不能阻塞 Owner 核心，也不能因已有原型或 Runbook 就被当成可公开/可生产。

## Success Criteria

- 为三个 package 建立稳定 atomic work items，明确独立 lane、default-off、外部门和退出条件。
- Publication 只使用独立 snapshot/Public Index/Visitor grant，不复用私人 Projection 过滤。
- Voice/DH 覆盖 consent/purpose、profile/sample/generated audio/provider receipt、credential broker、quality acceptance、delete/exit 和真机边界；禁止默认音色冒充复刻或真实高敏 dual-send。
- Composite Migration 只编排 W/I/P/Q/O/V/C 现有门和证据，不创建第二 runner/Authority；覆盖 C00 inventory、restore drill、go/no-go、retirement manifest。
- 产品、Privacy/Legal、Provider、真机和生产门保持显式阻塞状态，内部合同完成不能关闭这些门。
