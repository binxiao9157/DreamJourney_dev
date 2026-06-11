# DreamJourney 阶段2第二批 Scope/Guard Design

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

## 背景

阶段2第一批已完成三块基线：`MockDialogEngine`、`SafetyGuardClient`、`MemoryPrivacyScope`。第二批的目标不是一次性改完所有 UI/export/family 流程，而是先把两个基础能力接到真实数据入口：

- 对话与 KBLite 实体要能携带 privacy scope 与 source refs。
- DeepSeek/图片/回忆录/TTS 等远端入口要能被 SafetyGuard 包装或阻断。

## 可选方案

### 方案 A：全链路一次性改造

一次性改 `ConversationMemory`、`KBLiteGraph`、export、widget、care、family sync、DeepSeek、Memoir、TTS。

优点：理论上最接近最终目标。

缺点：文件范围过大，回归风险高，worker 冲突概率高；难以在一轮内用稳定测试证明每条链路。

### 方案 B：模型接入优先，输出过滤后置（推荐）

本批只把 scope/guard 接到真实数据入口，并补验证脚本；下一批再改 export/widget/care/family 的 sanitized 输出。

优点：边界清晰，可并行；能先建立 provenance 和 guard 入口，后续过滤有可依赖的数据结构。

缺点：本批结束时仍不是完整隐私闭环，需文档明确剩余风险。

### 方案 C：只写文档和接口，不动业务代码

继续只扩展 spec 和模型，不接真实入口。

优点：风险最低。

缺点：阶段2开发进度不足，无法推动实际闭环。

## 选定设计

采用方案 B。

## 架构边界

### Memory/KBLite Scope 主线

新增 `ConversationTurn.privacyMetadata`，默认普通对话为 `.localOnly`。`Stage1MailboxMemoryInput` 增加 `privacyMetadata`，保持旧调用兼容。

`KBLiteGraph.version` 升级到 2。`KBPerson`、`KBPlace`、`KBEvent`、`KBFact` 增加 `privacyMetadata`。旧数据 decode 时默认 `.localOnly`，不自动获得 prompt/export/family/widget 权限。

`KBLiteManager.extractFromTranscript` 只允许 `.generationAllowed` turn 进入远端 LLM prompt；local-only turn 可走本地 quick extract，但新实体仍带对应 scope，不能被默认外发。

### Remote SafetyGuard 主线

新增 DeepSeek 层 guard helper，最小目标是把 chat、knowledge extraction、image analysis 三类远端调用统一经过 `SafetyGuardClient` 风险判断。

当前 `SafetyGuardClient` 只有 transport 协议，尚无真实网络实现。本批使用 fail-closed 骨架与 mock transport 验证：

- 本地 high 直接短路，不调用远端。
- guard 不可用时远端目标 fail closed。
- allow response 才继续 DeepSeek 请求。

回忆录和 TTS 本批先通过 DeepSeek/Memoir 服务层包装，不直接改 UI 调用点。

## 数据流

1. UI 或业务层调用 `Stage1MemoryFacade.recordUserTurn(input)`。
2. 输入生成 `ConversationTurn(role,text,timestamp,privacyMetadata)`。
3. `finishConversationSession()` 把 transcript snapshot 交给 KBLite。
4. KBLite 根据 `PrivacyScopePolicy` 过滤可进入 remote extraction 的 turn。
5. 远端 extraction 前调用 SafetyGuard；未 allow 则走本地 fallback。
6. 合并出的 KBLite 实体带 `privacyMetadata` 和 `sourceRefs`。

## 验收

本批验收以纯 Swift 验证和 iPhoneOS build 为准：

- Privacy scoped turn 编解码兼容旧 JSON。
- generationAllowed 可进入 remote extraction，localOnly/privateOnly 不进入 prompt。
- KBLite 新实体携带 scope metadata。
- SafetyGuard allow 时 DeepSeek wrapper 放行。
- SafetyGuard high/unavailable 时 DeepSeek wrapper fail closed，不发远端请求。
- `Scripts/verify_phase2.sh` 统一执行所有新增验证。

## 本批明确不做

- 不改 Widget/App Group 输出。
- 不改 JSON/PDF/export/family sync。
- 不改 CareDashboard 输入过滤。
- 不引入真实 `/v1/safety/evaluate` 网络客户端。
- 不解决完整 Simulator app build 的 `SpeechEngineToB` slice 问题。

这些项进入下一批实现。
