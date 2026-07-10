# iOS KBLite 用户隔离、同步与后端提取

## Problem

KBLite 单例只在初始化时加载图谱，进程内切换用户可能继续持有旧用户内存数据；`syncKnowledge` 没有稳定业务触发点；知识提取默认仍直连客户端 DeepSeek。需要在不重写现有知识 UI 的前提下补生命周期、同步协调和 backend-first extraction。

## Success Criteria

- `switchUser(to:)` 原子保存/清空/加载对应用户图谱，登出后不保留上一用户数据。
- 知识提取完成、登录/用户切换和前台恢复可以触发去重的同步。
- 正常路径调用 `/kb/extract`，后端失败或离线才执行本地规则降级。
- 客户端可提交 mutation 并按 revision 拉取变更，旧服务端仍可降级使用 `/kb/sync`。
- 静态/launch-arg smoke 覆盖用户隔离、backend-first 和降级行为。
