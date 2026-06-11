# Roadshow Demo Cut 真机验证与演示闭环

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

目标：把 Roadshow 演示切成一条可在真机上验收、可在无网络/无 key/SDK 异常时兜底的主线。本分支已接入 `--seed-roadshow-demo`、`--reset-roadshow-demo`、`--roadshow-offline-mode`，并用阶段2验证脚本覆盖 seed 合约、工程文件语法和 iPhoneOS Debug build。

## 1. 真机前置条件

### 设备与签名

- 设备：至少 1 台 iPhone 真机，建议 iOS 17+，电量 50% 以上，关闭低电量模式。
- Xcode：使用 `DreamJourney.xcworkspace`，Scheme `DreamJourney`，Configuration `Debug` 或专用 `Roadshow` 配置。
- 签名：在 Xcode target `DreamJourney` 选择可用 Apple Developer Team；Bundle ID 使用唯一后缀，例如 `com.<team>.DreamJourney.roadshow`，避免与现场旧包冲突。
- 权限：首次启动前准备允许麦克风、语音识别、相册、相机、定位；如果现场不演示相机/地图，也要确认拒绝权限后页面不会阻断主线。
- 网络：准备两套环境：主 Wi-Fi/5G 用于真实 key smoke；飞行模式或断网用于兜底 smoke。
- 构建限制：当前完整 Simulator app build 已知受 `SpeechEngineToB` simulator slice 阻断，路演验收以 iPhoneOS 真机 build/run 为主。

### API key 与配置

`DreamJourney/Resources/Info.plist` 当前仍是占位值，真机包必须替换或由构建配置注入以下 key：

- `VolcEngineAppID`、`VolcEngineAppKey`、`VolcEngineAppToken`：真实语音陪伴链路需要。
- `DeepSeekAPIKey`、`DeepSeekAPIBaseURL`：回忆录、知识提取、图片分析等远端生成链路需要。
- `VoiceCloneAPIKey`：如现场演示声音克隆/TTS 个性化才需要；否则可不走该链路。
- `AMapAPIKey`：如现场展示足迹地图才需要；否则主线可跳过地图细节。
- `SafetyGuardBaseURL` 或 env `DREAMJOURNEY_SAFETY_GUARD_BASE_URL`：真实 safety guard smoke 使用。
- `SafetyGuardAPIKey` 或 env `DREAMJOURNEY_SAFETY_GUARD_API_KEY`：有鉴权时使用；无 key 时应确认请求不带 Authorization，且 fail-closed 行为符合预期。

### 真机安装与启动

推荐真机 smoke 构建命令：

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  build
```

推荐先跑 preflight：

```bash
Scripts/roadshow_device_smoke_preflight.sh
```

若当前机器没有连接真机，只验证脚本和 iPhoneOS build gate：

```bash
Scripts/roadshow_device_smoke_preflight.sh --allow-no-device
```

现场运行优先用 Xcode 直接 Run 到真机，便于设置 launch arguments/env 和查看控制台日志。若使用 `ios-deploy` 或 Xcode Devices 安装 ipa，需要另行确认 launch arguments 是否能注入。

## 2. 推荐 Launch Arguments / Env

### 已实现，可立即用于 mock 演示

| 用途 | Launch argument | Env | 预期 |
| --- | --- | --- | --- |
| 对话引擎走 mock | `--use-mock-dialog-engine` | `DREAMJOURNEY_DIALOG_ENGINE=mock` | `DialogEngineFactory` 返回 `MockDialogEngine`，不依赖 VolcEngine Speech SDK。 |
| Safety guard mock allow | `--use-mock-safety-guard` | `DREAMJOURNEY_SAFETY_GUARD=mock_allow` | 远端生成 guard 放行，用于演示链路，不代表生产策略。 |
| 真实 guard endpoint | 无 | `DREAMJOURNEY_SAFETY_GUARD_BASE_URL=https://<guard-host>` | POST `/v1/safety/evaluate`；非 2xx、网络错、解码错均 fail-closed。 |
| 真实 guard key | 无 | `DREAMJOURNEY_SAFETY_GUARD_API_KEY=<token>` | safety guard HTTP 请求携带 Bearer token。 |

### Roadshow Demo Cut 已接入

| 用途 | Launch argument | Env | 要求 |
| --- | --- | --- | --- |
| 注入路演 seed | `--seed-roadshow-demo` | `DREAMJOURNEY_SEED=roadshow_demo` | 首次启动写入固定家庭成员、对话、信箱、档案、照片 mock analysis、KBLite graph 和边界文案。 |
| 强制离线演示 | `--roadshow-offline-mode` | `DREAMJOURNEY_ROADSHOW_OFFLINE=1` | 写入本机离线演示标记，并让默认对话引擎与 safety guard 走 mock，避免真实网络依赖。 |
| 重置路演数据 | `--reset-roadshow-demo` | `DREAMJOURNEY_RESET_DEMO=1` | 清理路演本机数据后重新 seed，避免连续演示数据串场。 |

建议路演默认参数：

```text
--use-mock-dialog-engine --use-mock-safety-guard --seed-roadshow-demo
```

真实链路 smoke 参数：

```text
--seed-roadshow-demo
DREAMJOURNEY_SAFETY_GUARD_BASE_URL=https://<guard-host>
DREAMJOURNEY_SAFETY_GUARD_API_KEY=<token-if-required>
```

断网兜底参数：

```text
--use-mock-dialog-engine --use-mock-safety-guard --seed-roadshow-demo --roadshow-offline-mode
```

## 3. Demo Seed 规格

`--seed-roadshow-demo` 当前在 App 启动时通过 `RoadshowDemoSeed.applyIfRequested()` 注入本机演示数据。路演使用前建议搭配 `--reset-roadshow-demo`，确保每轮演示状态可复现。

### 家庭成员

- `fm_daughter_lin`：林岚，女儿，最近更新“刚刚”，用于成员级看板裁剪验证。
- `fm_son_hao`：陈浩，儿子，最近更新“路演数据”，用于亲友列表和分享对象验证。
- `fm_grandchild_yu`：小予，外孙，最近更新“路演数据”，用于时空信箱和家庭叙事。

现有 `FamilyRepository` 以 id 合并成员，重复执行 seed 不应产生同 id 重复行；如需重新演示，使用 `--reset-roadshow-demo`。

### 对话片段

写入 `ConversationTurn` 时必须携带 `privacyMetadata`，其中关怀看板可见内容使用 `.familyCircle`，普通生成内容使用 `.generationAllowed`，私密内容保持 `.localOnly`。

- 语音陪伴 1：AI 问“今天想从哪段回忆开始聊？”。
- 语音陪伴 2：用户说“昨晚睡不好，翻到很晚才睡着。”。
- 语音陪伴 3：用户说“下午一个人在家有点孤单，想听听小予的声音。”。
- 关怀信号片段：用户说“这两天胸闷，胃口差，也吃不下多少。”，该轮只授权给 `fm_daughter_lin`。
- 档案/信箱片段：用户分别提到“1984 年弄堂里全家吃年夜饭”和“写给小予十八岁生日”。

### 时空信箱

- 收件人：外公。
- 标题：`写给外公的一封信`。
- 正文首行：`外公，我今天又想起 1975 年外滩那张合影。`
- 投递时间：当前时间减 1 分钟，打开信箱后应显示 delivered。
- 回声文案：沿用 `TimeMailboxRepository.makeReply` 边界格式，首段必须包含“不是逝者真实回复”。
- 隐私：默认 `.localOnly`；若要进入家族分享，必须另建摘要化条目，不直接分享原信正文。

### 记忆档案馆

- 文本条目：`外滩合影的背景`，说明“1975 年 7 月，外公和外婆在外滩拍过一张全家合影。”
- 性格条目：`外公的习惯`，说明“说话慢，喜欢先听完别人讲完再回答。”
- 口头禅条目：`慢慢来，饭要趁热吃`。
- 照片条目：`外滩老照片`，使用本地 bundle demo 图片或占位图片路径；如果没有真实图，仍写入 analyzed 状态的 mock analysis。

照片分析 mock 结果：

```text
summary: 老照片中可能是一家人在江边合影，背景有城市建筑和栏杆，整体氛围温暖。
detectedPeople: 林静文、外公、张国强
scene: 上海外滩江边
occasion: 结婚纪念日/家庭合影
mood: 怀旧、温暖
estimatedDecade: 1970
```

### 关怀报告

用上述对话生成或直接 seed snapshot，必须只展示聚合信号：

- 数据覆盖：`近 3 天，用户发言 4 轮。`
- 观测结论：`最近对话出现睡眠、饮食和身体相关信号，建议家人主动联系并线下确认。`
- 风险信号：睡眠信号、身体/饮食信号、孤独/思念信号。
- 建议：`今晚主动打一次电话`、`询问睡眠和饮食`、`必要时陪同线下确认`。
- 不展示原始对话全文，只展示脱敏解释。

### 分享包

- 生成入口：知识库/同步页导出。
- 分享对象：先选“全体亲友”，再选“林静文（祖母）”或其他成员验证裁剪。
- 包内容：`SharePackage.sourceUserId`、`sourceNickname`、`exportDate`、`graphJSON`。
- 验收口径：分享包内只含 `.familySync` 允许的 sanitized graph；不包含 `.localOnly` 原始信件、私密档案、完整对话原文。

## 4. 8-12 步路演脚本

1. 开场进入 App，用一句话定调：这是“帮家庭整理记忆和关怀信号”的工具，不是复活服务。
2. 打开底部“信箱”，展示写给外公的信和回声。讲清楚回声来自已保存记忆，页面文案明确“不是逝者真实回复”。
3. 切到底部“档案”，展示文字、性格、口头禅和旧照片条目。点开照片分析结果，展示人物、场景、年代和氛围标签。
4. 从“档案”进入知识库，展示人物/地点/事件/事实如何从用户授权内容形成“记忆档案馆”。
5. 切到底部“回忆”，选择会话使用范围为“亲友”或“可生成”，点击语音/对话入口。mock 模式下输入或触发固定话术：“昨晚又睡不着，胃口也差。”
6. 展示语音陪伴回复：只做倾听和整理，不做医疗判断；如果 Speech SDK 异常，直接说明当前为 mock 对话引擎，主线继续。
7. 继续展示“潜行建库”：回到知识库，说明对话中的授权片段会形成人物、地点、事实，但私密/localOnly 内容不会进入分享。
8. 切到底部“亲友”，进入“长辈关怀看板”。展示数据覆盖、观测窗口、脱敏观察报告和建议。
9. 点某个家庭成员行进入成员视角看板，说明成员级可见性会裁剪数据，不同亲友只看到被授权的聚合信号。
10. 进入知识库同步/分享包，选择“全体亲友”导出，再选择单个成员导出，展示系统会按目标对象生成 sanitized 分享包。
11. 现场打开飞行模式或切换断网配置，重走“信箱 -> 档案 -> 回忆 mock -> 看板”关键节点，证明无网络仍可演示。
12. 结束页口播产品边界：不复活、不冒充、不诊断、不泄露原文，只展示用户授权、脱敏后的家庭关怀信号。

## 5. 手动验收 Checklist

### 安装启动

- [ ] 真机安装成功，启动无 crash。
- [ ] Xcode 控制台无关键缺 key crash；占位 key 场景能进入 mock 演示。
- [ ] 首次权限弹窗选择允许/拒绝后，主路演页面仍可访问。
- [ ] 使用 `--use-mock-dialog-engine` 时不触发 VolcEngine Speech SDK 依赖。
- [ ] 使用 `--use-mock-safety-guard` 时远端 guard 演示链路放行。
- [ ] 不带 mock safety 且未配置真实 guard endpoint 时，远端生成链路 fail-closed，不应静默发送请求。

### Seed 数据

- [ ] 家庭成员列表存在林岚、陈浩、小予，且同 id 不重复。
- [ ] 时空信箱至少有一封 delivered 状态信件，回复含“不是逝者真实回复”。
- [ ] 记忆档案馆至少有 3 个文本类条目和 1 个照片条目。
- [ ] 照片条目展示 analyzed/mock analyzed 结果，不依赖现场上传。
- [ ] 知识库有可展示的人物、地点、事件、事实。
- [ ] 分享包能生成临时 JSON 文件并弹出系统分享面板。

### 路演主线

- [ ] “时空信箱 -> 记忆档案馆 -> 语音陪伴/潜行建库 -> 子女关怀看板 -> 家族分享”能在 6 分钟内走完。
- [ ] 关怀看板展示数据覆盖、观测窗口、脱敏观察报告、风险信号解释。
- [ ] 看板不展示完整原始对话句子。
- [ ] 成员行进入成员视角看板可用。
- [ ] 知识库分享对象 action sheet 显示“全体亲友”和具体家庭成员。
- [ ] 选择取消导出时不会生成分享包。

### 隐私与边界

- [ ] localOnly 信件正文不进入关怀看板、知识库分享包或远端生成。
- [ ] `.familyCircle` 内容才进入亲友/看板/分享。
- [ ] `.generationAllowed` 内容才允许远端图片分析、知识提取或回忆录生成。
- [ ] 高风险/危机话术触发安全兜底，危机会话不写入记忆或回忆录。
- [ ] UI 或口播不使用“复活”“真实对话”“医疗诊断”等误导表达。

## 6. 失败兜底矩阵

| 失败场景 | 现场表现 | 兜底开关/动作 | 可继续演示的主线 | 验收口径 |
| --- | --- | --- | --- | --- |
| 无网络 | DeepSeek、guard、图片分析请求失败 | 启动 `--roadshow-offline-mode`；该参数会让默认对话引擎和 safety guard 走 mock | 信箱、档案、mock 对话、mock 看板、分享包 | 页面明确为演示/本机数据，不阻断导航。 |
| 无 DeepSeek key | 回忆录/知识提取/图片分析不可用 | 使用 seed 的 analyzed 照片和知识库 graph | 档案馆、知识库、看板、分享包 | 不出现 crash；远端入口提示稍后重试或显示 mock 结果。 |
| 无 VolcEngine key | 真实语音陪伴不可用 | `--use-mock-dialog-engine` 或 `DREAMJOURNEY_DIALOG_ENGINE=mock` | 语音陪伴主线改为 mock 对话 | 能出现确定性回复和 ASR/TTS 生命周期 UI。 |
| Speech SDK 异常 | 启动对话失败、engine error | 重新以 mock arg 启动；现场口播“切换本机演示引擎” | 回忆 tab 的对话与潜行建库 | 不依赖 SDK 即可走完脚本第 5-7 步。 |
| Safety guard endpoint 不可达 | 远端生成被阻断 | 真链路 smoke 记录 fail-closed；路演切 `--use-mock-safety-guard` | 演示远端结果改为 seed/mock | 真实 smoke 以 fail-closed 为通过，不为了演示绕过生产策略。 |
| 相册/相机权限被拒 | 无法上传新照片 | 使用 seed 照片条目 | 档案馆照片分析 | 拒绝权限后不影响浏览已有档案。 |
| 分享面板不可用 | AirDrop/文件分享失败 | 打开临时 JSON 预览或复制到剪贴板导入流程 | 家族分享口径仍可展示 | 能说明 sanitized package 已生成，后续分享渠道可替换。 |
| Seed 未生效 | 首屏无路演数据 | 使用 `--reset-roadshow-demo --seed-roadshow-demo` 重启；若仍失败，使用现有 mock 数据 + 手动创建信件/档案 | 低保真路演 | 记录控制台 `[RoadshowDemo]` 日志和启动参数，作为下一轮修复输入。 |

## 7. 产品边界文案清单

### 必须出现或口播

- “这不是复活，也不是逝者真实意识的回复。”
- “系统只基于用户主动保存和授权的记忆做整理与陪伴。”
- “时空信箱的回声是记忆整理文本，不代表逝者本人。”
- “关怀看板不是医疗诊断，只提示家庭可关注的脱敏信号。”
- “看板不展示原始对话，只展示聚合后的趋势和建议。”
- “私密内容默认只留在本机；进入亲友分享需要用户明确授权。”
- “高风险表达会优先触发安全兜底，而不是继续角色扮演。”

### 禁止或需要替换

- 禁止：“让亲人复活”“真实和逝者聊天”“AI 医生判断老人健康”。
- 替换为：“记忆陪伴”“基于保存内容的回声”“家庭关怀信号提示”。
- 禁止展示：完整原始对话、私密信件正文、未授权照片原图、未脱敏病情判断。
- 替换为：片段摘要、风险类别、观测窗口、授权状态、分享对象。

## 8. 剩余风险和下一轮必须补项

### 剩余风险

- `--seed-roadshow-demo`、`--roadshow-offline-mode`、`--reset-roadshow-demo` 已实现并通过脚本/iPhoneOS build 验证，但仍需真机启动后逐屏 smoke。
- Info.plist 仍含占位 key，真机真实链路必须在路演前由安全方式注入。
- 完整 Simulator app build 仍受 `SpeechEngineToB` simulator slice 影响，无法作为路演前唯一 gate。
- 成员级授权 UI 仍不完整；当前有成员视角入口和导出裁剪，但真实亲友身份与授权管理还需补齐。
- 分享包内容需要在真机上实际导出并抽查 JSON，确认没有 localOnly 原文和私密档案。
- 无网络/无 key 时的 UI 提示口径需要逐屏确认，避免显示“生成失败”后断掉叙事。
- Speech SDK 异常下的自动 fallback 尚未确认；已知可靠方式是用 launch argument 预先切 mock。
- reset 当前会清理路演相关本机存储，路演机应使用专用安装包/测试账号，避免混入真实用户数据。

### 下一轮必须补项

1. 真机 smoke：用 `--reset-roadshow-demo --seed-roadshow-demo --use-mock-dialog-engine --use-mock-safety-guard --roadshow-offline-mode` 启动，逐屏截图确认信箱、档案、回忆、看板、分享。
2. 抽查分享包 JSON：自动断言不含 `localOnly`、信件正文、完整对话原文。
3. 补真机 smoke runbook：包含签名、env、安装、启动、日志关键字和截图清单。
4. 补 Speech SDK 异常处理：真实 engine setup/start 失败时 UI 可提示切换 mock 或自动 fallback。
5. 补一轮现场计时演练：主线控制在 6 分钟内，断网兜底控制在 2 分钟内。
