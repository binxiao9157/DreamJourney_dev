# Complex Problem Ledger

Ledger: L20260711-145625-21
Schema: v6
Root: P000 - Task 21：P0 Widget / App Group 知识隐私生命周期
Status: done
Updated: 2026-07-11T07:27:24+00:00

## Problem Tree
- [done] P000: Task 21：P0 Widget / App Group 知识隐私生命周期
  - [done] P001: 定义默认拒绝的 Widget 知识快照与隐私策略
  - [done] P002: 实现 generation 绑定的 App Group 发布与账号生命周期
  - [done] P003: 升级 Widget 读取端并补齐扩展与 App Group 工程接线
    - [done] P005: 实现 Widget schema v2 身份校验与最小展示
    - [done] P006: 补齐 Widget 扩展嵌入、Bundle ID 与 App Group 配置
  - [done] P004: 将 Widget 隐私生命周期纳入发布回归并收口文档
  - [done] P007: 提交推送 Task 21 并完成闭环状态

## Active

## Blocked

## Done
- [x] P000: Task 21：P0 Widget / App Group 知识隐私生命周期
- [x] P001: 定义默认拒绝的 Widget 知识快照与隐私策略
- [x] P002: 实现 generation 绑定的 App Group 发布与账号生命周期
- [x] P003: 升级 Widget 读取端并补齐扩展与 App Group 工程接线
- [x] P004: 将 Widget 隐私生命周期纳入发布回归并收口文档
- [x] P005: 实现 Widget schema v2 身份校验与最小展示
- [x] P006: 补齐 Widget 扩展嵌入、Bundle ID 与 App Group 配置
- [x] P007: 提交推送 Task 21 并完成闭环状态

## Tickets
- [done] T000: 建立账号绑定且默认拒绝的 Widget 知识快照链路 -> P000 (split)
- [done] T001: 实现纯 Swift Widget 隐私投影合同 -> P001 (one_go)
- [done] T002: 建立可撤销且防旧写覆盖的 Widget 快照存储 -> P002 (one_go)
- [done] T003: 让 Widget fail closed 并作为主 App 扩展正确交付 -> P003 (split)
- [done] T004: 用纯校验策略升级 Widget 快照读取 -> P005 (one_go)
- [done] T005: 修复 Widget target 的可交付工程合同 -> P006 (one_go)
- [done] T006: 固化 Widget 隐私发布门并收口 Task 21 证据 -> P004 (one_go)
- [done] T007: 形成远程可共享的 Task 21 完整提交 -> P007 (one_go)

## Latest Checks
- [success] C000: P001 结果 R000 完成了 P001 要求的纯模型授权、最小快照和自动化验证；已知 IO/WidgetKit 缺口属于兄弟问题，不阻断本问题成功。
- [success] C001: P002 R001 完成了 P002 的 generation-bound 发布和账号生命周期目标；Xcode/Widget 端接线属于 P003 的明确范围。
- [success] C002: P005 R002 完整满足 P005 的读取端身份校验、fail-closed 与最小 UI 展示要求。
- [success] C003: P006 R003 满足 P006 的 target membership、扩展嵌入、配置继承与非真机构建要求，外部 provisioning 风险已明确保留。
- [success] C004: P003 R004 由两个已独立成功检查的子结果组成，完整解决 P003；真实签名门槛不在非真机任务成功定义内且已显式保留。
- [success] C005: P004 R005 满足 P004 的默认发布门、完整回归和文档证据要求；提交推送属于 Task 21 根收尾而不是该 QA 子问题的实现缺口。
- [not_success] C006: P000 R006 证明全部技术与非真机验收已完成，但原始验收清单明确要求提交推送；当前工作区仍有未提交变更，因此不能判定根问题成功。
- [success] C007: P007 R007 证明实现提交已推送且本地/远端一致，满足 P007 对可共享交付的核心要求；账本关闭后的状态提交由 Closure finalization 紧接执行。
- [success] C008: P000 R006 已证明 Task 21 的隐私投影、账号与 generation 生命周期、Widget fail-closed 读取、工程嵌入、默认发布回归和文档全部完成；R007 进一步证明实现与证据已提交并推送。两项结果合并后满足根问题全部标准。
