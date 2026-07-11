# Widget / App Group 知识隐私生命周期

日期：2026-07-11

分支：`feature/prd-stitch-ui-adaptation`

状态：非真机实现与验证完成；真实 App Group provisioning/Widget Gallery 验收待外部执行。

## 完成内容

- `KBPrivacyMetadata.widgetVisibility` 为独立显式授权，历史数据和默认值均为 deny。
- 只有当前 owner、`generationAllowed`、`summaryAllowed`、personal、confirmed 事件可以生成 Widget 摘要。
- schema v2 仅包含 owner digest、generatedAt、event digest、title、year/month；不包含 raw owner/event/source ID、description 或 sourceRefs。
- `KnowledgeWidgetSnapshotStore` 用 owner digest + KBLite UUID generation 拒绝账号切换前的延迟保存。
- 登出/切换先使旧快照失效，再删除/发布并调用 `WidgetCenter.reloadTimelines(ofKind: "TodayInHistory")`。
- Widget provider 校验 schema 与 active owner digest；缺失、错账号、旧 schema、损坏或非法字段均为空态。
- Widget timeline/view 已移除 description，真实摘要使用 `.privacySensitive()`。
- 主 App 已嵌入 Widget extension；Bundle ID、Team、App Group build setting 与 entitlement 已同源。

## 默认发布边界

- 当前没有公开“允许在 Widget 展示”设置页，因此历史数据和新知识默认都不会出现在 Widget。
- 本轮不允许 familyCircle、数字人角色知识或描述正文进入系统 Widget。
- Widget shell 可随 App 构建，但知识内容只有未来显式设置 `summaryAllowed` 后才会显示。

## 自动验证

```bash
Scripts/QA/prd-stitch-ui/run-knowledge-widget-privacy-policy-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-widget-snapshot-store-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-widget-snapshot-reader-model-smoke.sh
swift Scripts/QA/prd-stitch-ui/knowledge-widget-privacy-lifecycle-check.swift .
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
```

以上检查已通过。Simulator 与 generic iPhoneOS Debug 无签名构建均通过，两个产物都包含：

```text
DreamJourney.app/PlugIns/DreamJourneyWidget.appex
```

完整默认 release regression 通过，报告：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task21-widget-privacy-rerun/report.md
```

本地覆盖验证：

```text
App bundle ID:    com.yxj.dreamjourney.app
Widget bundle ID: com.yxj.dreamjourney.app.widget
App Group:        group.com.dreamjourney.shared
```

## 外部验收边界

1. Apple Developer Portal 为主 App 与 Widget App ID 注册 `group.com.dreamjourney.shared`。
2. 刷新两个 target 的 provisioning profile。
3. 真机安装后在 Widget Gallery 添加“历史上的今天”。
4. 用 A/B 两账号验证 A 登录、登出、B 登录后旧内容立即消失。
5. 验证锁屏/桌面隐私脱敏和系统 timeline 刷新行为。

这些条件未执行，因此不能把真机 Widget 交付声明为已验收。
