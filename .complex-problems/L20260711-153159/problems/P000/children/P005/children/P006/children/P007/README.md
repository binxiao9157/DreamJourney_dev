# 家庭授权刷新状态与前台同步顺序

## Problem

服务端撤销或刷新失败不能及时失效进程内 accepted family snapshot；foreground 会直接开始知识同步。

## Success Criteria

- FamilyRepository 暴露 owner-bound refresh generation/state，成功、失败、账号切换都会更新 generation。
- foreground 先异步刷新家庭 authority，再启动知识同步；失败时 family authorization fail closed。
- accepted family 集合变化清理旧 knowledge base/pending 并从 revision 0 重拉。
- 模型/静态 smoke 覆盖成功、撤销、失败和 stale response。
