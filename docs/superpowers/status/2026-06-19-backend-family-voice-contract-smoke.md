# Backend Family / Voice Contract Smoke

Date: 2026-06-19

## Goal

把临时的部署后端验证固化成正式 QA smoke，用于每次后端重新部署后验证隐藏 family digital-human 合同和 voice profile lifecycle 合同。

## Scope

- `/health` 必须返回 `status=ok` 且部署环境为 Postgres store。
- `/config/runtime.archive` 必须返回 `mockObjectStorage` provider switch 合同。
- `/family/invite` 必须保存并回传：
  - `sunlight` / `阳光`
  - `star` / `星辰`
  - `silent` / `静默`
  - `backendContractMode=mockFamilyPersona`
  - `familyPersonaContractVersion=1`
  - `defaultReleaseVisible=false`
- `/family/members/{userId}` 必须能重新拉回相同三态。
- 非法 `digitalHumanMode=storm` 必须返回 400。
- `/voice/profiles` 必须完成创建、列表、禁用、删除 tombstone 的 voice profile lifecycle。

## Release Regression

```bash
RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE=1 \
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

脚本会从 `DreamJourneyBackend/private/deployed-backend-access.md` 或 `DreamJourneyBackend/deployed-backend-access.md` 读取部署后端地址和 `BACKEND_API_TOKEN`，报告只记录 `configured, value intentionally omitted`，不会输出 token 明文。

## Direct Command

```bash
RUN_ID=20260619-deployed-family-voice-contract \
Scripts/QA/prd-stitch-ui/run-backend-family-voice-contract-smoke.sh
```

## Evidence

- Result JSON: `tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke/<run-id>/backend-family-voice-contract-smoke-result.json`
- Report: `tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke/<run-id>/report.md`
