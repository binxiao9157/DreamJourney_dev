# 知识本地存储与语义缓存隔离状态

日期：2026-07-11
状态：非真机实现、完整回归与远端交付完成。

## 已完成

- embedding cache 绑定不可逆 owner digest 和 KBLite user generation；账号切换/登出会清空 cache 并使旧 warm task 失效。
- cache key 包含 entity kind、entity ID fingerprint 和 searchable text fingerprint；跨类型 ID 冲突和同 ID 内容更新不再复用旧向量。
- active scope 与 cache 字典全部由锁保护；异步计算前后都复核 scope。
- generation Context 先按 expected persona、privacy scope 和 evidence status 构造候选图，再执行 semantic/keyword ranking；排名后仍保留二次过滤。
- graph、remote base、pending mutation、governance outbox 和 legacy sync history 统一使用 `KnowledgeLocalStoragePolicy`。
- 写入采用 atomic + `completeUntilFirstUserAuthentication`，原子替换后重新加固最终 inode，并设置 `isExcludedFromBackup`。
- 既有文件在加载时 best-effort 补强属性，文件名、路径和 JSON envelope 不变。

## 自动化证据

```bash
Scripts/QA/prd-stitch-ui/run-knowledge-semantic-cache-isolation-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-semantic-cache-isolation-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-local-storage-protection-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-local-storage-protection-check.sh
Scripts/QA/prd-stitch-ui/run-knowledge-persona-ranking-prefilter-check.sh
```

以上 gates 已接入默认 release regression 和 release QA package。完整报告：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task23-knowledge-storage-cache-final3/report.md
```

Simulator、generic iPhoneOS、Archive -> Echo smoke 和延迟回信通知 smoke 均通过。独立复核发现的旧摘要 fallback、post-commit 加固结果歧义和并发 cache activation 排序问题均已修复；仅保留 Pods/Kingfisher 的既有 Swift 6 whitespace warning。

## 边界

- 不迁移现有 JSON 路径，不引入向量数据库或网络 embedding provider。
- 不改变知识页、Echo 或 Stitch UI。
- 真机锁屏前后 Data Protection 与系统备份行为仍需后续设备验收，本轮不宣称完成。
- legacy sync history 所属的整库分享仍默认关闭；本轮只保护文件，不重新开放产品能力。
- 后端没有代码或合同变化，不需要重新部署。

## 交付版本

- iOS 分支：`feature/prd-stitch-ui-adaptation`
- 实现提交：`f0ee683 feat: isolate local knowledge cache and storage`
- 远端状态：已推送至 `origin/feature/prd-stitch-ui-adaptation`
- 后端：本轮无代码或合同变化，无需部署
