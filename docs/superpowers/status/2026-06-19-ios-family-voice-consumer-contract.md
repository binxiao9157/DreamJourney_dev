# iOS Family / Voice Consumer Contract

Date: 2026-06-19

## Scope

把已部署后端的 family digital-human 和 voice profile lifecycle 合同接进 iOS 端消费层，避免后端已稳定但 App 仍只依赖 mock/静态假数据。

## Contract

- `FamilyMember.fromBackendJSON(_:)` 统一解析后端 family member payload。
- `DreamJourneyBackendClient.fetchFamilyMembers` 返回 typed `[FamilyMember]`。
- `FamilyRepository.refreshFromBackend` 只消费 typed client，不再维护第二套 family JSON parser。
- `VoiceCloneProfileSnapshot.init(backendContract:)` 把后端 `VoiceCloneProfileContract` 转成隐藏声音克隆壳层可展示的 snapshot。
- 声音克隆壳层展示 `providerMode`、合同版本和默认发布可见性。

## Hidden Release Boundary

- 不开放公开 family management 入口。
- 不开放真实声音克隆训练入口。
- `defaultReleaseVisible=false` 仍表示 voice/family 扩展只可通过 hidden QA flag 或后续产品决策放出。

## Verification

```bash
swift Scripts/QA/prd-stitch-ui/ios-family-voice-consumer-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

该检查已接入 `run-release-regression.sh` 和 release QA package。
