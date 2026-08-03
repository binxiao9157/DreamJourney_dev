# Round 4D 状态、跨 Lane 优先级与 Optional/Migration 静态门

## Problem

Round4D主体已完成，但路线图状态仍旧、缺少Publication/Voice/DH/MIG跨lane优先级与专用checker，可能把Optional原型误开放或在C00/C01前推进不可逆迁移。

## Success Criteria

- 更新header和第6节，明确Round4D已合入32项/512字段，同时保持Publication/Voice/DH/MIG当前blocked/no-go。
- 增加跨lane规则：Voice credential/default-on立即contain；Owner text优先；Publication、Voice/DH独立promotion；MIG只有C00可立即开始。
- 增加stop-the-line：private Projection公开、长期credential进client、假consent/delete/ready、dual-send、C10 removal、post-cutover旧writer回滚均阻断。
- 新增Round4D checker验证32项/512字段、状态、default-off、private/public隔离、Voice/DH门、C00–C11和Owner核心独立。
- 运行全部Product V4检查与`git diff --check`。
