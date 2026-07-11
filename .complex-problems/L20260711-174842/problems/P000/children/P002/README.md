# 统一知识本地文件保护策略

## Problem

知识 graph、remote base、pending mutation、governance outbox 和 legacy sync history 的写入策略分散；虽然多数使用 atomic write，但文件保护、目录保护和 backup exclusion 不完整，无法形成统一静态数据保护合同。

## Success Criteria

- 新增统一 `KnowledgeLocalStoragePolicy` 处理目录准备、backup exclusion、文件保护和 atomic write。
- graph/base/pending/outbox/sync history 全部通过该策略写入。
- 保留现有文件路径、文件名、JSON envelope 和临时目录注入能力。
- 既有文件在读取/写入时可 best-effort 加固，不自动删除或迁移。
- 新增静态 gate 并通过 Simulator/generic iPhoneOS build。
