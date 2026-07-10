# iOS 时间信件调度职责收敛

## Problem

iOS mailbox refresh 会主动调用全局 `/archive/time-letters/dispatch-due`，与服务器已启用的定时调度重复，也要求普通用户具备 system-only 能力。

## Success Criteria

- iOS mailbox refresh 只拉取当前用户 mailbox，不再触发全局 dispatch。
- backend client 的 system API 可保留给 QA/运维，但不在公开 App 生产路径调用。
- 静态检查固定该边界，相关时间信件 QA 不回归。
