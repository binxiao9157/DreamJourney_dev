# 对齐既有知识发布门与不可变授权快照合同

## Problem

`knowledge-proposal-persona-policy-check.swift` 仍要求旧的 `resolveCurrentPersonaIdentity()` 开始/完成双重读取，导致更安全的 generation snapshot 实现无法通过既有发布回归。

## Success Criteria

- proposal/persona gate 要求 `captureCurrentPersonaAuthorizationSnapshot()` 在后台派发前执行。
- gate 要求 extraction completion 使用 generation snapshot，且不包含 `resolveCurrentPersonaIdentity()` 或 `FamilyRepository`。
- proposal/persona、async authorization、governance coordinator 和 release QA package 检查全部通过。
- `git diff --check` 与 Workspace Simulator build 保持通过。
