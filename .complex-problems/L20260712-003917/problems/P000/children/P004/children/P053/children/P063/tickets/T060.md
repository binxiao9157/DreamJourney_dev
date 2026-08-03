# 以 Composition Root、Typed Ports 与 Runtime Lease 渐进收敛 iOS

## Problem Definition

当前UIKit工程已有Repository、policy、generation guard、DigitalHumanRuntime和大量QA脚本，但依赖创建仍集中在App/Tab/ViewController/singleton，账户generation防线分散，Echo同时承担UI、应用流程、Provider会话、音频、通知与诊断。直接重写会破坏Stitch视觉和已验证真机链路，需要以可回滚seam逐步迁移。

## Proposed Solution

为 `WP-S1-03` 建立十个连续Work Item：

1. `WI-S1-03-01`：建立XCTest承载面与层级依赖/import guard。
2. `WI-S1-03-02`：新增UIKit AppComposition/FeatureFactory，先注入现有concrete service。
3. `WI-S1-03-03`：抽App lifecycle并贯穿S0 AccountLease/generation/release policy。
4. `WI-S1-03-04`：Archive/Candidate/Memory/OwnerQA typed use cases与Intent/ViewState adapter。
5. `WI-S1-03-05`：抽Echo application coordinator，保留现有布局和控件。
6. `WI-S1-03-06`：抽Echo runtime session coordinator和统一callback fence。
7. `WI-S1-03-07`：建立进程级AudioOwnerLease并逐Feature接管AVAudioSession。
8. `WI-S1-03-08`：Voice/DH client ports、owner-scoped cache/timer与runtime adapters。
9. `WI-S1-03-09`：notification/deeplink/push runtime按owner/generation路由。
10. `WI-S1-03-10`：QA scenario移出生产控制器，完成渐进strangler与iOS集成门。

每项填满16字段，明确消费而不复制S0 AccountLease和S1-01 Authority。所有改动保留UIKit、三Tab与Stitch全屏Echo；只按composition/port/coordinator/adapter拆职责。G0/G1/generic iPhoneOS可以关闭非设备合同，麦克风、AudioSession、Tencent DH、TTS、打断和后台恢复仍为G4。

## Acceptance Criteria

- 十个Work Item连续唯一、16字段完整，并引用当前真实文件或显式新增位置。
- App/Scene/Tab只从Composition取Feature factory；Feature只发Intent/渲染ViewState。
- Archive/Owner QA写入仅经S1-01 application ports，不直接改KBLite/Archive Authority。
- stale account/role/request/conversation/runtime callback在UI、store、notification、audio四处均被fence。
- 同一时刻只有一个active Echo runtime和AudioOwner lease；停止、打断、后台与页面退出语义分开。
- `EchoViewController`按职责逐段变薄，不一次重写，不改变Stitch视觉。
- mock/simulator不能关闭真机/Provider门，QA脚本中人工未验证项不能输出完整passed。

## Verification Plan

1. 对照独立iOS源码审计和Product Spec的六层边界、I01–I08迁移波次。
2. 为每项标注现有`SceneDelegate/TabCoordinator/AppDelegate/Archive/Echo/Voice/DH/Notification`路径与新增模块。
3. 结构检查10个ID、160字段、S0/S1依赖、no UI rewrite、G0–G4与rollback。
4. 运行现有Product V4、account isolation、Echo lifecycle/audio、release与generic iPhoneOS检查。
5. Round5独立审查是否产生第二AccountLease、第二AudioOwner、过度抽象或UI回归风险。

## Risks

- 没有XCTest target会让actor/lease/port只能靠静态脚本证明；测试承载面必须先行。
- 仅新增protocol但继续由VC拼业务不会降低风险；每个port需有一个真实call site迁移和old path断言。
- AudioSession由Echo、DialogEngine、Archive、Profile和Memoir分别配置；必须逐Feature接管，不能一次切全部。
- QA代码与AppDelegate/Echo混杂，直接删除会失去验证能力；先移到QASupport target/config再收窄生产路径。

## Assumptions

- 本票据只写可执行路线，不修改Xcode project或生产代码。
- S0负责AccountLease/ReleasePolicy/credential，S1-01负责Owner truth，S1-03只消费typed ports。
- Voice/DH关闭时Owner文字核心必须独立通过；真实设备质量不由本轮文档关闭。
