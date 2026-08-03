# Round 4E2A：路线执行注册表与确定性 Next Selector

## Problem

115 个 Work Item 已有完整执行正文，但缺少一份机器可读的当前状态、typed 依赖、Authority lock、release class、适用 Gate/evidence 和 selector rank 注册表；相同路线事实仍可能因人工判断选择不同下一项。需要在不改变产品范围和实现状态的前提下建立唯一执行元数据与重排规则。

## Success Criteria

- 路线图新增与 13 Package / 115 Work Item 精确一一对应的 typed execution registry，字段使用有限枚举且不复制 16 字段正文。
- start/exit dependency、authority lock、release class、lifecycle、decision、owner、required gate/evidence state 和 stable rank 可机器解析；所有引用存在。
- 明确 P0 Owner text core 不依赖 Optional，Optional default-off，MIG 只拥有迁移 evidence/go-no-go record 而不拥有业务 aggregate。
- 定义确定性 selector、tie-break、`NO_EXECUTABLE_ACTION`、incident/evidence expiry/open decision/dependency变化时的降级与重排规则。
- 当前基线按规则只给出唯一允许的 next action，不越过未关闭依赖或外部门。
- header/第6节更新为 Round 4 工作项与静态验收完成但仍待 Round 5，且不误报工程实现。
