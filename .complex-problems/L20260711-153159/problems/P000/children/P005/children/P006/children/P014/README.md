# 对齐统一知识管线发布门与家庭授权合同

## Problem

`knowledge-pipeline-check.swift` 仍断言旧 extraction 日志和旧 foreground 直接同步行为，无法验证当前 authorization snapshot 与 refresh-before-sync 合同。

## Success Criteria

- KBLite isolation 断言改为要求授权 snapshot/generation 失效，不放宽 ownerless legacy 和 Widget 隔离。
- foreground 断言要求先 `bootstrapCurrentUserFromBackend`，completion 后触发 `foregroundAfterFamilyRefresh`。
- 逐项修正该 gate 中其他过期但已被更安全合同替换的断言。
- knowledge pipeline gate、release QA、完整 release regression、Simulator/generic iPhoneOS build 与 `git diff --check` 通过。
