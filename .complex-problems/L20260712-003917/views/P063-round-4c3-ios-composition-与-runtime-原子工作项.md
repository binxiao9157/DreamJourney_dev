# P063: Round 4C3：iOS Composition 与 Runtime 原子工作项

Status: done
Parent: P053
Root: P000
Source Ticket: T057 (split)
Source Check: none
Package: problems/P000/children/P004/children/P053/children/P063
Body: problems/P000/children/P004/children/P053/children/P063/README.md
Ticket(s): T060

## Problem
当前 iOS 已有 Repository、Manager、Coordinator 和大量 QA guard，但依赖创建、账号 generation、Intent/ViewState、Echo/Voice/DH runtime 与通知路由仍分散在 AppDelegate、ViewController 和 singleton。需要建立渐进式 composition/runtime seam，同时保持当前 UIKit/Stitch UI 与已验证业务行为。

## Success Criteria
- 建立覆盖 Composition Root、Domain/Application typed ports、AccountLease fence、Archive/Review/QA use case、Echo runtime actor、audio owner、notification/deeplink adapter、渐进 strangler 和测试 target 的连续原子工作项。
- 每项完整填写 16 个字段，引用当前真实文件或标明新增位置；不伪造 Swift package、test target 或 adapter 已存在。
- UI 只发 Intent、渲染 ViewState；transport、owner 信任、业务 Authority 和 Provider credential 不进入 ViewController。
- 切账号、取消、后台、旧异步回调和角色切换均受 lease/generation fence；同一时刻只有一个 Echo runtime 与 audio owner。
- 不一次性重写 `EchoViewController`、不改变 Stitch 视觉或三 Tab 信息架构；按 facade/adapter/cohort 渐进替换。
- G0/G1 覆盖 unit/model/simulator/generic iPhoneOS，数字人、音频、权限与真机质量继续标 G4，不能由 mock 关闭。

## Subproblems
- none

## Results
- R057

## Latest Check
C058

## Bodies
- Problem: problems/P000/children/P004/children/P053/children/P063/README.md
- Ticket T060: problems/P000/children/P004/children/P053/children/P063/tickets/T060.md
- Result R057: problems/P000/children/P004/children/P053/children/P063/results/R057.md
- Check C058: problems/P000/children/P004/children/P053/children/P063/checks/C058.md

## Follow-ups
- none
