# WI-S1-03-01 XCTest 承载面与层级依赖 Guard

日期：2026-07-18

## 当前状态

- Work Item：`WI-S1-03-01`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_TEST_FOUNDATION_VERIFIED / IOS_LOCAL_COMMITTED`
- 范围：只新增测试承载面、纯模型和层级 guard；不改三 Tab、Stitch 全屏 Echo、账户 writer、后端 API 或公开功能。

## 已实现

- Xcode 新增 hosted `DreamJourneyTests` unit-test target、共享 `DreamJourney` scheme 和 Pods build settings 继承。
- 新增 `DreamJourneyCore` SwiftPM unhosted test target，只复用当前纯 Foundation 的 `AccountSessionActor.swift`、`AccountLease.swift` 和 `AudioOwnerLeaseModel.swift`。
- 同一组 `DreamJourneyTests` 测试源通过 conditional `@testable import` 同时服务 Xcode hosted target 和 SwiftPM unhosted target，避免复制行为断言。
- 新增可控 Clock、UUID、HTTP、通知与 audio-owner test doubles。
- 新增纯 `AudioOwnerLeaseModel`：按 account/runtime generation 与 priority 仲裁，拒绝旧 generation，旧 lease release 不能清除后来的 owner。该模型尚未接管 `AVAudioSession`；真实 runtime 接线仍属于后续 `WI-S1-03-07`。
- 新增 `product-v4-ios-test-foundation-check.py`：确认 hosted/unhosted target、scheme、test support、纯模型依赖边界，以及 Feature 不直接创建新的 audio-owner model。

## 验证证据

1. `python3 Scripts/QA/product-v4/product-v4-ios-test-foundation-check.py` 通过。
2. `swift test --package-path . --scratch-path .build/product-v4-xctest` 通过：4 条 XCTest 全部通过。
   - A -> B 账号切换后的旧 callback 被拒绝。
   - 同账号 refresh 后的旧 generation 被拒绝。
   - 腾讯数字人播放可抢占 Echo capture，旧 capture release 不会清除播放 owner。
   - 旧 runtime generation 不能抢占当前 audio owner。
3. `Scripts/QA/product-v4/run-ios-test-foundation-gate.sh` 通过：先执行 unhosted XCTest，再运行 iPhoneOS hosted `build-for-testing`。
4. `xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` 通过；Release app 内不存在 `DreamJourneyTests.xctest` 或其他 test artifact。
5. `plutil -lint DreamJourney.xcodeproj/project.pbxproj` 通过。

## Hosted / Unhosted 选择说明

- 当前完整 App target 链接腾讯、地图和语音 provider 二进制；本机 `xcodebuild -showdestinations` 不向该 scheme 暴露可运行模拟器目的地，XcodeBuildMCP 仍可发现 4 条测试但无法启动 simulator runner。
- 因此 G0 的实际可执行断言由 unhosted `swift test` 在 macOS 运行；同一测试源仍由 iPhoneOS hosted target `build-for-testing` 编译，保证 app module 和 Pods 依赖接线有效。
- 当 provider SDK 提供可运行 simulator slice，CI 可设置 `DJ_IOS_TEST_DESTINATION`，`run-ios-test-foundation-gate.sh` 会切换为真正的 `xcodebuild test` hosted execution。此限制没有被标记为模拟器通过。

## 后续边界

- 下一项按当前交接进入 `WI-S1-01-01`：Owner Truth 核心 schema、约束与 Authority Epoch。
- `WI-S1-03-02` 仍依赖本项完成，但不与 Owner Truth writer 同时变更。
- 本项不把 `AudioOwnerLeaseModel` 接入真实 AVAudioSession，也不宣称数字人/复刻音色真机 runtime 已验证。
