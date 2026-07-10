# Principal 绑定与 iOS 调度收敛

## Problem

多数 owner/system 路由只记录 shadow mismatch，user bearer 仍可能访问其他用户资源；iOS 仍主动触发全局时间信件 dispatch。

## Success Criteria

- owner-bound mismatch 和 user 调用 system-only 即时 403，global mode 仍为 shadow。
- owner match、delegated family/time-letter/invitation 和 legacy system token 继续通过。
- iOS mailbox refresh 不再调用 dispatch-due。
- profile/archive/mailbox/voice/KB/session/push/echo/family 等代表性读写有负向测试。
