# iOS Governance 串行提交与 Generation Gate

## Problem

持久化动作仍需与普通知识同步共享网络 owner，并处理 revision conflict、服务端成功后的权威 graph、user/persona 切换。

## Success Criteria

- coordinator 提供 performGovernance，先写 outbox 再发请求。
- 普通 sync 与 governance 不并发；成功、失败、409 状态正确推进。
- 同 operation ID 重试，成功删除 outbox并保存 base。
- user/persona 旧 callback 不直接写当前图谱；服务端已成功时走 change feed 收敛。
- static/model smoke 和 Simulator build 通过。
