# DreamJourney Phase 1 True-Device Acceptance Checklist

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 模块

- [ ] 阶段一真机模块测试操作手册：`phase1_true_device_manual_test_steps.md`
- [ ] P0-1 记忆档案馆真实素材建库验收：`phase1-memory-archive/acceptance_checklist.md`
- [ ] P0-2 数字人对话记忆约束真机验收：`phase1-digital-human-grounding/acceptance_checklist.md`
- [ ] P1-1 长辈关怀看板跨设备验收：`phase1-care-dashboard/acceptance_checklist.md`
- [ ] P1-2 时空信箱真实信件验收：`phase1-time-mailbox/acceptance_checklist.md`
- [ ] P2-1 线上后端 smoke 与安全配置验收：`phase1-backend-smoke/acceptance_checklist.md`

## 后端远端 Smoke

```bash
export DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn
export DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>
export DREAMJOURNEY_BACKEND_REPO=${DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}
PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py --remote
```

完成所有 P0/P1 真机证据后，再更新 `docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md`。
