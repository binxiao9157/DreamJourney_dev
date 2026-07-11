# P003: 升级 Widget 读取端并补齐扩展与 App Group 工程接线

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
Widget 当前读取旧无身份 schema 并显示 description，主 App 未嵌入扩展，双方缺少一致 App Group entitlement，Widget Bundle ID 也不跟随主 App，导致功能不可交付且读取端无法 fail closed。

## Success Criteria
- Widget 只解码 schema v2，并校验共享 active owner digest 与 snapshot owner digest。
- 缺失、不匹配、旧 schema 或损坏 JSON 返回空 entry；UI 不再展示事件 description，敏感摘要带系统隐私标记。
- 主 App 嵌入 Widget extension 并声明 target dependency。
- Widget Bundle ID 由主 App bundle ID 派生，两个 target 使用同一可配置 App Group build setting 与 entitlement。
- 模拟器或构建产物证据证明 `.appex` 被嵌入，generic iPhoneOS 构建可通过；真实 provisioning 明确为外部验收。

## Subproblems
- P005: 实现 Widget schema v2 身份校验与最小展示
- P006: 补齐 Widget 扩展嵌入、Bundle ID 与 App Group 配置

## Results
- R004

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R004: problems/P000/children/P003/results/R004.md
- Check C004: problems/P000/children/P003/checks/C004.md

## Follow-ups
- none
