# WI-V0-01-07 G0：角色音色选择与安全 Fallback 预检

日期：2026-07-28
Work Item：`WI-V0-01-07`

## 本轮范围

后端提交 `e837740` 新增默认关闭的
`voice_role_selection_shadow`，为后续服务端 `ResolveRoleVoice` 查询固定
角色、内部 profile、purpose、runtime generation 与 fallback 的最小合同。

- 本人没有 profile 时，候选明确为产品默认 AI 音色；
- 本人 profile 或在世成年人已独立授权、发布对应 purpose grant 且质量确认的
  profile，只能登记为 future candidate；
- 家庭关系本身不构成声音授权；未成年人、纪念/逝者角色不提升 profile，返回
  中性默认 AI 或文字 fallback；
- profile 撤销、删除、主体不匹配、跨 owner/vault、旧 generation 或同 generation
  冲突时，要求清除旧 profile，不能继续上一角色声音；
- provider speaker ID、原文、音频、显示名、家庭资料和凭据不进入该合同或摘要。

该模块没有路由、数据库、Provider 调用、音频合成、session 或 iOS UI 改动。它不改变
现有 `/voice/synthesis`、家人页面或 Echo 运行时行为。

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-role-selection-g0-gate.sh
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-generated-audio-binding-g0-gate.sh
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-dh-authority-g0-gate.sh
env STORE_BACKEND=memory /tmp/dreamjourney-backend-test-venv/bin/python \
  -m unittest -v \
  tests.test_safety_integration.SafetyIntegrationTests.test_minor_and_family_voice_or_digital_human_requests_hard_deny_before_provider
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：新增 9 项角色音色 G0 测试通过；既有 GeneratedAudio、Voice/DH authority、
未成年人/家庭声音高风险拒绝测试通过；完整后端验证通过（1206 项单测及既有 contract
gates）。

## 未关闭 Gate

- `G1`：iOS 仍使用本地家人 metadata 选择音色，尚未消费服务端 Resolver receipt；
  selector/diagnostics 也未接入该合同。
- `G2`：无 RoleVoiceSelection receipt、consent/grant/quality 查询、profile 状态持久化或
  runtime generation ledger。
- `G3`：无真实 Provider profile/consent/quality/region/cost 证据。
- `G4`：无真机本人/单个独立授权在世主体的听感与角色切换验收。

因此本项仅是 scoped G0。未推送、未部署，不能被报告为“家人复刻音色已可用”或公开
Echo 声音能力。
