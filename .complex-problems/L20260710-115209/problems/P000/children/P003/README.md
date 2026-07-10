# 更新 iOS 逻辑 ID、QA 护栏和交接文档

## Problem

iOS 仍把新建逻辑 profile 命名为 `S_...`，容易与真实火山 speaker 混淆；状态文档也未记录独占槽和容量边界。

## Success Criteria

- iOS 新建 profile 使用 provider 无关的 `vp_...` ID，旧本地 `S_` ID 仍可读取。
- QA 静态检查阻止恢复哈希分配和真实槽默认值。
- runtime/部署文档说明 exclusive slot、retire-on-delete、容量耗尽和旧 profile 兼容策略。
- 最新实现/分支状态文档更新到当前提交口径。
- 后端验证、相关 Swift 检查、iOS Debug build 和两个仓库 `git diff --check` 通过。
