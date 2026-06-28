# Family Digital Human Hidden Contract

Date: 2026-06-19

## Goal

收敛家庭/数字人隐藏合同，不开放公开入口；后端以 mock 持久化方式保存 family member 的 `personaScope`、`digitalHumanId` 和 `阳光 / 星辰 / 静默` 状态，iOS 只解析并继续服务隐藏 QA 分支。

## Contract

- `backendContractMode`: `mockFamilyPersona`
- `familyPersonaContractVersion`: `1`
- `personaScope`: `family`
- `digitalHumanId`: 默认 `family_default`
- `digitalHumanMode`: `sunlight` / `star` / `silent`
- `digitalHumanModeLabel`: `阳光` / `星辰` / `静默`
- `defaultReleaseVisible`: `false`

## Release Boundary

- 不开放公开入口。
- 公开 MVP 默认仍不暴露家人管理和数字人生命周期切换。
- 仅作为后端合同、iOS 解析和 QA 隐藏分支的前置地基。

## Verification

- `python -m unittest tests.test_core_services.FamilyAPITests`
- `python -m unittest tests.test_postgres_store.PostgresStoreTests.test_store_persists_family_member_digital_human_contract`
- `swift Scripts/QA/prd-stitch-ui/family-digital-human-hidden-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
