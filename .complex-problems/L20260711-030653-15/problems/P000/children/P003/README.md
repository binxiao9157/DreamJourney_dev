# iOS Proposal 消费与 Identity-bound 合并

## Problem

iOS 当前只解码 extraction 并随机生成 ID，且会话结束提取没有捕获 persona identity。

## Success Criteria

- iOS 可解码 proposal/persona metadata 并优先使用 proposal ID、关联和来源字段。
- 异步完成时 user/persona/digital-human identity 不匹配则丢弃结果。
- 旧 extraction 和旧本地 KBLite 文件保持兼容，family 不推断旧 personal 数据。
