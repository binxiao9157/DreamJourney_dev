# 家庭成员与账号注销生命周期闭环

Date: 2026-06-21

Branch: `feature/prd-stitch-ui-adaptation`

## 本轮目标

根据最新 PRD 明确两条公开规则：

- 家庭成员通过手机号邀请；展示邀请中、已加入、失败；不可删除家人；退出/解除关系暂不做。
- 账号注销需要两次确认；不支持数据导出；数据保留 30 天；同手机号 30 天内可恢复 1 次；超期不可逆删除。

## iOS 实现

- `FamilyCircleViewController`：新增手机号邀请弹窗、手机号校验、邀请中/失败/已加入状态展示；非已加入成员不可切换回响对象。
- `FamilyRepository` / `MemoryModel`：新增 `accessStatus`、`invitationStatus`、`invitationError`，失败邀请会写入本地失败态；`remove(id:)` 按 PRD 保持 no-op。
- `DreamJourneyBackendClient`：新增 `/family/invite`、`/auth/delete`、`/auth/restore` client 合同。
- `ProfileViewController`：账号注销改为两步确认，文案明确不支持导出、30 天恢复期、仅 1 次恢复机会；成功后退出登录。
- `MemoryArchiveTextEntryViewController`：时间信件收件人只取已加入家人，避免邀请中/失败成员被选为投递对象。
- `FeatureFlagService`：`accountDeletion` 纳入默认公开 feature set，schema version 升到 7。

## 后端实现

- `/auth/delete`：要求 `firstConfirmation=true` 和 `secondConfirmation=true`，写入 soft delete metadata。
- `/auth/restore`：同手机号、30 天内、`restoreCount < 1` 才允许恢复。
- `/auth/login`：同手机号登录时会尝试恢复处于 30 天窗口内的 soft-deleted account。
- `/auth/purge-expired-deletions`：提供超期清理合同，写入 `deletionState=purged` tombstone。
- `/family/members/{userId}/{memberId}/revoke`：公开 API 返回 409，明确不支持删除/解除家庭成员。
- Memory/Postgres store 均补齐 `get_user`、`soft_delete_user`、`restore_user`、`purge_expired_deleted_users`。

## QA / 回归

- 新增 `profile-family-account-lifecycle-check.swift`：静态守护 iOS/后端合同、公开 feature flag、家庭邀请规则、账号注销两步确认、时间信件收件人过滤。
- 新增 `backend-family-account-lifecycle-smoke.py` 和 `run-backend-family-account-lifecycle-smoke.sh`：部署后可验证手机号邀请、禁止删除、soft delete、一次恢复、超期恢复失败。
- `run-release-regression.sh` 已接入 `RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE=1` 可选门禁；默认公开回归不强依赖部署后端。

## 验证结果

- Backend unit tests: `PYTHONPATH=. STORE_BACKEND=memory .venv/bin/python -m unittest discover tests`，108 tests passed。
- Python smoke compile: `python3 -m py_compile tmp/visual-qa/prd-stitch-ui/backend-family-account-lifecycle-smoke.py` passed。
- Static guards passed:
  - `release-feature-matrix-check.swift`
  - `profile-release-gating-check.swift`
  - `profile-safety-flow-check.swift`
  - `profile-family-account-lifecycle-check.swift`
  - `profile-family-persona-switcher-check.swift`
  - `group4-profile-care-check.swift`
  - `prd-coverage-matrix-check.swift`
- Release QA package: `release-qa-package-check.swift` passed。
- `git diff --check` passed in both iOS and backend repos。
- iOS simulator compile passed via `xcodebuild -destination 'generic/platform=iOS Simulator'`.
- Default release regression passed:
  - Report: `tmp/visual-qa/prd-stitch-ui/release-regression/20260621-131039-release-regression/report.md`
  - Archive -> Echo screenshot: `tmp/visual-qa/prd-stitch-ui/release-regression/20260621-131039-release-regression/archive-to-echo-smoke/20260621-131039-release-regression/01-archive-to-echo-completed.png`
  - Echo delayed reply screenshot: `tmp/visual-qa/prd-stitch-ui/release-regression/20260621-131039-release-regression/echo-delayed-reply-notification-smoke/20260621-131039-release-regression/01-echo-delayed-reply-notification-smoke.png`

## 仍需后续验收

- 后端部署后跑：

```bash
RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

- 生产账号注销仍需确认 purge 定时任务运行方式、客服恢复支持流程和合规/法务文案。
- 家庭成员退出/解除关系未在 PRD 明确，本轮没有实现，也不在公开入口暴露。
