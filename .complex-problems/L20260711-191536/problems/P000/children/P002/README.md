# iOS snapshot fallback 与游标恢复

## Problem

让 iOS 在后端明确报告 change-feed compacted 时只执行一次权威 snapshot 恢复，并继续现有三方合并和本地 pending push。

该问题属于父任务，因为服务端明确 410 后，iOS 必须安全恢复权威 snapshot，不能把历史断档当普通网络错误或覆盖本地待同步修改。

## Success Criteria

- snapshot 响应严格校验 user、revision 和 graph。
- client 能识别结构化 410，并提供 snapshot GET。
- coordinator fallback 受 generation/pull-session 保护，失败不推进本地状态。
- model/static smoke 和非真机构建通过。
