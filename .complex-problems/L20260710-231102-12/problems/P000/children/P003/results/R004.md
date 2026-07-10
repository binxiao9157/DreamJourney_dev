# Context Packet 驱动真实 Echo 生成结果

## Summary

已完成后端可生成上下文合同和 iOS 每轮 Echo RAG 注入：后端把经过权限与业务规则筛选的 selected context 形成稳定、可追踪的 `generationContext`，iOS 将其绑定到当前最终 ASR turn 并提交给火山 Dialog；请求失败或短超时时按当前 query 使用当前用户 KBLite 降级。

## Done

- 后端 `/context/build` 兼容返回 `generationContext`，包含版本、文本、来源引用、来源计数、稳定哈希、长度上限和截断标记。
- 生成文本只使用最终 selected 的 archive、KB fact、persona、care 内容，并执行 `generationAllowed` 隐私过滤。
- failed 空分析、草稿或未到期时间信件、无效家庭关系等内容不会进入生成上下文；voice/digital-human runtime 只保留运行态，不进入知识文本。
- iOS 在最终 ASR 后创建 turn gate，优先等待后端 0.9 秒，失败后使用当前 query 的 KBLite fallback。
- lifecycle、用户、turn 和单次提交门禁阻止迟到回调与重复 RAG；延迟回信只记录 trace。
- Echo turn-scoped 模式关闭启动期旧知识摘要注入，避免 backend context 与 local recent summary 叠加。

## Verification

- 后端 182 个单元测试、FastAPI smoke、knowledge delta smoke 通过。
- Context V2/generation contract smoke 通过。
- iOS 知识管线、Context Packet、Dialog/Archive 集成静态检查通过。
- 全量 release regression 通过，包含模拟器构建、通用 iPhoneOS 构建、Archive -> Echo smoke 和延迟回信通知 smoke。

## Known Gaps

- 火山线上 ChatRagText 的实际接收时序与回答内容相关性仍需后续真机验收；本轮非真机合同与降级路径已闭环。

## Child Results

- P005 / R002：后端生成上下文合同。
- P006 / R003：iOS 每轮 Echo RAG 注入。
