# DreamJourney 阶段2启动计划

日期：2026-06-11

基线：阶段1集成分支 `feature/phase1-integrated-mvp`

## 目标

阶段2从“本地可验收 MVP”推进到“可联调、可试点、可运营的安全闭环”。重点不再继续堆本地页面，而是把阶段1留下的关键限制转成可验证的工程任务。

## 工作流 1：前置安全和服务端兜底

### 背景

阶段1已在本地 UI/TTS/记忆链路阻断高风险内容，但 `SEEventChatTextQueryConfirmed` 事件可能发生在远端 LLM 前后，不能证明高风险文本完全没有进入远端链路。

### 交付

- 服务端 safety guard：所有用户输入、角色回复、TTS 文本入参前统一评估。
- SDK 前置拦截调研：确认是否能在最终 ASR 到 LLM 前中断。
- 危机事件审计日志：只记录风险级别、时间和处理状态，不保存高风险原文。
- 安全回归用例：覆盖用户输入、助手输出、信箱正文、档案素材、图片分析摘要。

### 验收

- 高风险输入不会进入角色回复生成。
- 高风险助手输出不会进入 TTS。
- 危机事件不会写入回忆录、知识库或亲友看板。
- 本地脚本和服务端测试同时覆盖。

## 工作流 2：语音引擎和模拟器/CI 可测试性

### 背景

阶段1 iPhoneOS Debug build 已通过，但 Simulator 构建受 `SpeechEngineToB` 二进制 slice 限制影响。

### 交付

- 语音 SDK simulator slice 或 mock adapter。
- `DialogEngineFactory` 接入 Apple 免费语音路径的真实实现。
- CI smoke target：不依赖真机语音 SDK 也能编译核心 UI/业务逻辑。
- 对话引擎协议测试：验证 start/stop/safety/end reason 的状态流。

### 验收

- iPhoneOS 构建继续通过。
- Simulator smoke build 可通过。
- Apple 免费语音路径可手动跑通基础听说流程。

## 工作流 3：亲友账号、权限和同步

### 背景

阶段1亲友看板只读取本机 transcript，没有家庭关系、权限、云同步和 APNs。

### 交付

- 用户、家庭圈、成员角色和授权模型。
- 关怀信号同步 API：只同步脱敏聚合数据，不上传原始对话。
- 家属查看权限：老人授权、撤回、成员移除。
- APNs 或本地通知策略：仅在持续风险或未读关怀提醒时触发。

### 验收

- 未授权家属无法读取任何关怀信号。
- 授权撤回后，新数据停止同步，历史数据按策略处理。
- 看板明确展示数据时间窗口和数据量。

## 工作流 4：记忆资产、声音授权和人格边界

### 背景

阶段1已建立记忆档案和信箱边界，但声音克隆、persona speaker 绑定、授权撤回和审计链路尚未实现。

### 交付

- 记忆资产权限范围：私密、本机、家庭圈、可用于生成。
- 声音授权记录：采集来源、授权人、用途、撤回状态。
- TTS speaker 绑定：persona 与 voice profile 分离管理。
- 时空信箱 opt-in：用户明确选择哪些素材可用于回声生成。

### 验收

- 私密素材不会进入 prompt、导出、关怀看板或 Widget。
- 撤回声音授权后无法继续生成该 voice profile。
- 信箱回复能说明使用了“已授权记忆线索”，不伪装真实逝者回复。

## 工作流 5：数据迁移和产品试点

### 交付

- 阶段1本地数据迁移到阶段2 schema。
- 用户试点脚本：安全兜底、信箱、档案、亲友看板四条核心路径。
- 埋点和诊断：只记录操作事件和错误码，不记录敏感正文。
- 试点反馈表：悲伤干预、边界理解、家属误读风险。

### 验收

- 老数据升级后不丢失本地信箱和档案。
- 试点用户能完成四条核心路径。
- 安全、隐私和边界文案经过人工走查。

## 多 agent 协作安排

- 主控 agent：维护阶段2计划、拆任务、合并验证、处理冲突。
- Safety agent：服务端 safety guard、危机事件审计、测试矩阵。
- Speech agent：语音 SDK/Apple 免费路径/mock adapter。
- Family agent：账号、权限、同步、APNs。
- Memory agent：资产权限、声音授权、persona 绑定、迁移。
- QA agent：验收脚本、CI、试点流程和回归清单。

## 第一批任务

1. 给 `DialogEngineFactory` 增加 mock/simulator adapter，解锁 Simulator smoke build。
2. 设计服务端 safety API 合约和本地调用点。
3. 设计家庭圈权限 schema，明确原始对话不出端原则。
4. 设计记忆资产 privacy scope，并反向审计 prompt/export/widget 路径。
5. 建立阶段2 CI 验收脚本，复用 `Scripts/verify_phase1.sh` 并增加 mock build。
