# Round 3：目标架构与增量迁移路径

## Problem

现有工程已有 Archive、KBLite、Echo、Family、Voice、Digital Human 等大量能力，不能按新名词推倒重来；同时 Publication/Visitor、Source processing 等新目标需要明确权威数据和迁移边界。

## Success Criteria

- iOS、后端、对象存储、异步任务和 provider adapter 的目标边界明确。
- 每个领域对象都有权威来源、ID、状态机、权限、删除和审计责任。
- 现有模块被标为保留、重命名适配、抽取、替换或后置，且有理由。
- 数据迁移保持 backward compatibility、feature flag、回滚和双读/双写边界。
- Hermes/AOS 可借鉴机制仅在有证据和实际收益时进入方案。
