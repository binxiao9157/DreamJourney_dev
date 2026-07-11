# Task 21：P0 Widget / App Group 知识隐私生命周期

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_21_p0-widget-app-group-knowledge-privacy-lifecycle.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 21：P0 Widget / App Group 知识隐私生命周期

## 目标

让“历史上的今天”Widget 只读取当前已登录用户明确允许公开到系统 Widget 的最小摘要；退出、切换账号、旧异步保存或快照损坏时必须 fail closed，不能继续显示上一用户知识。完成 App Group 工程接线、身份绑定快照、timeline 失效和非真机回归，不改变 App 公开页面视觉。

## 现状审计

- `KBLiteManager.writeToAppGroup` 当前把全部 `graph.events` 的 title/description/year/month 写入共享 JSON，没有检查 owner、persona、evidence 或 Widget 授权。
- `switchUser(to:)` 会写新图谱或登出空图谱，但共享文件没有 schema/owner identity，Widget 无法证明快照属于当前登录用户。
- 主 App 与 Widget target 都没有配置 App Group entitlement；现有 `containerURL` 在真实签名环境没有可靠合同。
- 写入后没有 `WidgetCenter.reloadTimelines`；WidgetKit 已缓存的旧 entry 可能持续到下一次系统刷新。
- 旧用户的延迟 `save()` 没有独立的 Widget publication generation，可能与切换/登出清理竞态。
- Widget 直接信任共享文件并显示 description；没有 schema、active owner digest 或最小字段 allowlist。
- 现有 release QA 只检查 `writeToAppGroup(graph: loadedGraph)` 存在，没有覆盖授权、跨用户、缓存失效或 entitlement。

## P0 合同

1. 主 App 与 Widget target 使用同一可配置 App Group identifier，并正确声明 entitlement；Widget bundle ID 跟随主 App bundle ID。
2. 新共享快照使用版本化 schema，包含不可逆 owner digest、生成时间和最小事件摘要；不得包含 raw user/event/source ID、description、sourceRefs 或其他知识正文。
3. 事件默认不允许进入 Widget。只有同时满足以下条件才导出：
   - `privacyMetadata.scope == generationAllowed`
   - `privacyMetadata.widgetVisibility == summaryAllowed`
   - `ownerUserId` 精确匹配当前用户
   - `personaScope == personal`
   - `evidenceStatus == confirmed`
4. App Group `activeOwnerDigest` 必须与快照 owner digest 一致；缺失、不匹配、旧 schema、解码失败一律展示空态。
5. KBLite 用户 generation 同时约束 Widget publication；旧用户延迟保存不能覆盖新用户或登出清理。
6. 登出先撤销 active owner，再删除共享快照并 reload Widget timeline；账号切换先使旧快照失效，再发布新用户快照。
7. 每次成功发布、撤销或失败清理都调用指定 Widget kind 的 timeline reload，避免旧 entry 长时间缓存。
8. App Group 文件使用原子写入和 `completeUntilFirstUserAuthentication` 文件保护；失败时保持 fail closed。

## 实现范围

### iOS 主 App

- 为 `KBPrivacyMetadata` 增加向后兼容的 `widgetVisibility` 可选字段，默认 deny。
- 新增纯 `KnowledgeWidgetPrivacyPolicy` 与共享快照模型。
- 新增 generation-bound `KnowledgeWidgetSnapshotStore`，负责 active owner、原子写入、文件保护、清理和 timeline reload。
- `KBLiteManager` 的 init/save/switchUser 接入新 store，移除无条件 JSON 导出。
- 补齐主 App/Widget entitlements、build setting、Info.plist App Group 配置及扩展 bundle ID 继承。

### Widget Extension

- 升级共享模型到 schema v2。
- Provider 同时校验 schema、active owner digest、快照 owner digest和字段边界。
- placeholder 使用通用示例，不冒充真实家庭记忆；生产 snapshot 失败时只显示空态。

### QA / 文档

- 新增纯模型 smoke：默认拒绝、唯一允许组合、跨 owner/persona/evidence/scope 拒绝、字段脱敏和 owner digest。
- 新增静态 gate：entitlement、bundle ID、generation、logout clear、reload、provider fail-closed。
- 接入 release regression 和 release QA package，运行 Simulator/generic iPhoneOS build。
- 状态文档明确真实设备仍需在 Apple Developer Portal 注册 App Group 并刷新 provisioning profile。

## 验收清单

- [ ] 默认/legacy event 不进入 Widget；只有显式 summaryAllowed + confirmed personal owner event 可进入。
- [ ] 编码快照不含 raw owner/event/source ID、description 或 sourceRefs。
- [ ] owner digest 不匹配、登出、旧 schema、损坏文件都返回空 entry。
- [ ] 旧 generation publish 在切换/登出后被拒绝。
- [ ] publish/clear 触发 `reloadTimelines(ofKind:)`。
- [ ] App/Widget entitlement、bundle ID 和 App Group build setting 一致。
- [ ] 模型 smoke、静态 gate、release QA、Simulator/generic iPhoneOS build、git diff check 通过。
- [ ] 提交推送；不做真机、不改 Stitch UI。

## 非目标

- 不在本轮新增公开 Widget 授权设置页；在产品入口明确前保持默认 deny。
- 不开放 familyCircle/家庭数字人知识到 Widget。
- 不做真机 Widget Gallery/锁屏展示验收；Apple Developer Portal App Group 与 provisioning 属于外部验收。
- 不处理 semantic cache、change-feed compaction、公开知识治理 UI 或历史 source identity 迁移。


## Success Criteria

- Recursive ledger reaches next_action=none.
- Relevant implementation and verification evidence is recorded.
- A compact status checkpoint is synced back to Lodestar progress.md.
