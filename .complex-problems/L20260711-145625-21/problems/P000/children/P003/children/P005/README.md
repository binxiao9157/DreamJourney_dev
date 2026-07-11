# 实现 Widget schema v2 身份校验与最小展示

## Problem

Widget provider 直接信任旧共享 JSON，并将事件 description 放进 timeline entry 和界面，无法拒绝旧 schema、跨账号或损坏快照。

## Success Criteria

- Shared model 与主 App schema v2 字段一致，并提供可纯测试的 snapshot acceptance policy。
- provider 只有在 schema 与 active owner digest 匹配时返回事件，其余情况为空。
- entry/view 不再携带或显示 description，placeholder 使用通用非真实内容。
- 事件内容标记 `.privacySensitive()`，不改 App 主页面视觉。
- 读取策略模型 smoke 覆盖匹配、缺 owner、错 owner、旧 schema 和损坏数据。
