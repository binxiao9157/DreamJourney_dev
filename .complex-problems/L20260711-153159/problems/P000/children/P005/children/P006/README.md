# 收紧运行期家庭授权新鲜度与异步快照

## Problem

Task 22 已实现默认拒绝、账号级同步授权与冷启动 bootstrap，但服务端撤销关系在 App 长期运行期间不能及时使同步、extraction/governance 和 Echo 当前角色 fail closed。

## Success Criteria

- 前台恢复和知识同步启动前刷新家庭 authority；刷新失败或过期时不得继续使用旧 family persona 进行新同步。
- extraction 与 governance 在异步开始前捕获授权 identity/generation，完成时只比较不可变快照，不从后台线程读取 FamilyRepository。
- 当前 family context 被撤销时主动回退 self、持久化并发送 context change，Echo 取消旧 gate/runtime 请求。
- 新增模型/静态 smoke 覆盖撤销、刷新失败、账号切换和 stale callback，并重新通过全量 release regression 与非真机构建。
