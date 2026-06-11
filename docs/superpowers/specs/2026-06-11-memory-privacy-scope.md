# Memory Privacy Scope Spec

日期：2026-06-11

来源：阶段2 Privacy/Memory agent 只读审计结果。

## 结论

阶段1已有局部隐私边界，但还不是端到端 privacy scope。核心问题是：`isPrivate` 只存在于部分资产模型，素材进入 `ConversationMemory` 或 `KBLiteGraph` 后会丢失 provenance 和 scope，后续 prompt、export、Widget、PDF、family sync、backend sync 只能读完整 graph。

## 阶段1已做到

- `MemoryModel`、`MemoirModel` 有 `isPrivate`。
- `MemoryArchiveItem` 有 `isPrivate`，文字/照片默认私密，非私密文字才写入全局记忆。
- 档案照片支持“仅私密保存”或“分析并整理为记忆线索”。
- `TimeMailbox` 默认只本地存信，不主动写入全局记忆。
- `CareDashboard` 只展示聚合统计，并排除档案/信箱前缀文本。

## 仍可能泄露的路径

- `Stage1MemoryFacade` 入口只接收纯文本，没有 scope/source/provenance。
- `ConversationMemory` 保留最近 20 轮原文，结束会话后完整交给 KBLite 抽取。
- `KBLiteManager` 把完整 transcript 拼进 DeepSeek prompt，无 scope 过滤。
- `buildContextString`、`greetingHint`、`GapDetector` 从完整 graph 取数据。
- Widget App Group 写入所有事件标题/描述。
- JSON/PDF/backend/family sync 使用完整 graph。
- `FamilyRepository` 可能从完整 KBLite 人物同步私密人物名/关系。

## 数据模型

```swift
enum MemoryPrivacyScope: String, Codable, CaseIterable {
    case privateOnly
    case localOnly
    case familyCircle
    case generationAllowed
}

enum MemoryUseSurface: String, Codable {
    case remoteExtraction
    case prompt
    case memoirGeneration
    case timeMailboxEcho
    case export
    case widget
    case careDashboard
    case familySync
    case backendSync
}
```

默认值：

- `MemoryArchiveItem`、`TimeMailboxLetter`: `privateOnly`。
- 普通对话 turn: `localOnly`。
- 用户明确同意“用于生成/长期记忆”: `generationAllowed`。
- 未知旧数据: `localOnly`，外发面默认 deny。

## 策略

- 新增 `PrivacyScopePolicy.canUse(asset, surface)`，默认 deny unknown。
- 所有外发/展示接口只调用 `sanitizedGraph(for:)` 或 `context(for:)`。
- prompt/export/widget/care/family/backend/pdf 全部用统一策略过滤。
- scope 升级必须来自用户显式授权，不能由导入或同步自动升级。

## 迁移

- `KBLiteGraph.version = 2`。
- `KBPerson`、`KBPlace`、`KBEvent`、`KBFact` 增加 `privacyScope`、`sourceRefs`、`createdBySurface`。
- `MemoryModel/MemoirModel.isPrivate == true` -> `privateOnly`。
- `MemoryArchiveItem.isPrivate == true` -> `privateOnly`。
- 旧 KBLite 无 provenance，统一迁到 `localOnly`，并提供复核 UI。
- 旧 `ConversationMemory.recentTranscript` 不直接迁入可外发 scope。

## 最小验收矩阵

- 私密档案文字不得进入 `ConversationMemory`、KBLite、prompt、export、Widget、CareDashboard。
- 私密档案照片不得调用图片分析，不得写 KBLite。
- 分析档案照片默认不得进入 Widget/family export。
- 普通对话 localOnly 可本机摘要，不得 backend sync/export/widget。
- generationAllowed 可进入 prompt/memoir generation，但不得自动进入 family/widget。
- familyCircle 可进入家庭聚合，不得进入生成 prompt，除非另获生成授权。
- TimeMailbox 私密正文不进入 KBLite、CareDashboard、Widget、export。
- 旧 v1 数据迁移后默认不出现在 export/widget/family/prompt。
- JSON/PDF/backend/App Group sanitized 输出不含私密 sentinel 文本。

## 分级

Must:

- `Stage1MemoryFacade`、`ConversationMemoryManager` 记录 turn 时携带 scope/sourceRef。
- KBLite 实体带 scope，search/context/greeting/gap 全部过滤。
- export/PDF/widget/family/backend 改用 sanitized export。
- `CareDashboard` 改用 scope 过滤。
- v1 -> v2 schema 迁移。

Should:

- UI 补充显式授权选择。
- `FamilyRepository` 只同步 familyCircle 可见人物。
- 导入流程保留或降级 scope。

Later:

- 声音授权、persona/voice profile 分离、撤回审计。
- 服务端 privacy guard 与后端 schema。
- APNs/家庭同步历史撤回策略。
