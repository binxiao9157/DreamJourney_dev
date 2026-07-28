# WI-V0-01-05 G0：复刻音色试听确认凭据

日期：2026-07-28
Work Item：`WI-V0-01-05`
范围：仅补齐音色质量确认前的服务端/客户端合同；不改变公开 Echo 视觉或发布态能力。

## 本轮结论

`G0 = SCOPED_VERIFIED`。

已把“训练状态 ready”与“用户已试听并确认可用于 Echo”分开：ready 音色只能用于一次短时质量试听；普通 Echo 合成在确认前必须拒绝。

## 已实现的合同

1. `/voice/synthesis` 支持 `requestPurpose=qualityPreview`；只有该 purpose 可在未确认时生成默认试听音频。
2. 后端仅在 Provider 成功返回试听音频后，签发 15 分钟有效、随机且只保存哈希的 `qualityPreviewReceiptId`。
3. `/quality-acceptance` 必须提交有效、未过期的 receipt；receipt 被消费后不可重放。
4. 常规 Echo 合成仍要求 `qualityAcceptanceRequired=false`，不会静默降级为默认音色。
5. iOS 仅在 `AVAudioPlayer` 确实开始播放试听后缓存 receipt，之后才允许点击“确认使用此音色”。
6. profile 公共返回体不包含 preview/acceptance receipt 的哈希或内部时间字段。

## 验证

```bash
# Backend
env STORE_BACKEND=memory /tmp/dreamjourney-backend-test-venv/bin/python -m unittest -v \
  tests.test_core_services.VoiceCloneProfileAPITests
python3 -m py_compile app/main.py tests/test_core_services.py

# iOS/static
swift Scripts/QA/prd-stitch-ui/voice-clone-quality-preview-receipt-check.swift .
swift Scripts/QA/prd-stitch-ui/voice-clone-stale-ready-state-check.swift .
swift Scripts/QA/prd-stitch-ui/voice-clone-status-feedback-check.swift .
swift Scripts/QA/prd-stitch-ui/voice-clone-backend-contract-check.swift .
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath tmp/visual-qa/product-v4/DerivedDataVoicePreviewReceiptDevice \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app \
  DREAMJOURNEY_DEVELOPMENT_TEAM=2BTR77V3R8
git diff --check
```

结果：后端 `VoiceCloneProfileAPITests` 23/23 通过；静态检查和 iPhoneOS generic build 通过。

## 未关闭 Gate

- `G1`：模拟器交互路径需使用可控后端 fixture 验证“试听播放后才能确认”的完整 UI 行为。
- `G3`：真实火山 Provider 的训练、试听和 receipt 行为尚未验收。
- `G4`：真机听感确认，以及“试听音色 = Echo 目标人物音色”尚未验收。

因此该 Work Item 不提升为公开 Voice MVP，也不部署或宣称 Provider/真机能力已完成。
