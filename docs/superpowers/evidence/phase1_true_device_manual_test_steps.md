# 阶段一真机模块测试操作手册

更新日期：2026-06-14

本文档用于阶段一真实设备验收。测试目标不是验证路演演示效果，而是验证真实账号、真实素材、真实后端和真实隐私边界是否闭环。

## 测试总原则

- 不使用路演模式、演示向导、mock/offline 模式。
- 不把原始照片、原始音频、信件正文、完整 transcript 提交进证据目录。
- 证据目录只保存截图、录屏、设备日志、脱敏后端响应和问题记录。
- 发现问题时记录模块、步骤、期望、实际、截图或录屏、测试账号和大概时间。
- 优先测试 P0 主链路，再测 P1 家庭协作，最后做辅助回归。

## 证据目录

根目录：

```text
docs/superpowers/evidence/
```

模块目录：

```text
docs/superpowers/evidence/phase1-memory-archive/
docs/superpowers/evidence/phase1-digital-human-grounding/
docs/superpowers/evidence/phase1-care-dashboard/
docs/superpowers/evidence/phase1-time-mailbox/
docs/superpowers/evidence/phase1-backend-smoke/
```

## 0. 测试前准备

### 操作步骤

1. 安装最新真机包。
2. 冷启动 App。
3. 确认 App 没有使用以下启动参数或环境：
   - `--seed-roadshow-demo`
   - `--roadshow-offline-mode`
   - `DREAMJOURNEY_SEED=roadshow_demo`
   - `DREAMJOURNEY_ROADSHOW_OFFLINE`
4. 首次进入时允许权限：
   - 麦克风
   - 相册
   - 通知
   - 定位
5. 确认网络可用。
6. 确认业务后端地址配置为当前可用入口：

```text
DreamJourneyBackendBaseURL=https://www.mmdd10.tech/dreamjourney-api
```

正式域名 `https://dreamjourney-api.liftora.cn` 完成 DNS/HTTPS 放行后再切换。

7. 如果服务器启用了 `BACKEND_API_TOKEN`，iOS 同步配置：

```text
DreamJourneyBackendAPIToken=<与服务器 BACKEND_API_TOKEN 相同>
```

8. 使用真实测试账号登录。
9. 如果需要双设备测试，准备 A 设备和 B 设备两个不同手机号账号。

### 通过标准

- App 能正常进入主界面。
- 不出现路演向导、演示清单、路演家庭 seed 数据。
- 首页右上隐私范围能切换。
- 底部 Tab 可正常进入：回忆、足迹、亲友、信箱、档案。

### 失败记录

```text
模块：测试前准备
步骤：
期望：
实际：
截图/录屏：
测试账号：
大概时间：
```

## 1. 登录与真实模式基线

### 操作步骤

1. 冷启动 App。
2. 如果出现手机号登录页，输入测试手机号和真实姓名。
3. 进入首页后查看右上状态。
4. 点击首页右上隐私范围按钮。
5. 依次确认可选范围：
   - 本机
   - 可生成
   - 亲友
6. 依次进入以下 Tab：
   - 回忆
   - 足迹
   - 亲友
   - 信箱
   - 档案

### 通过标准

- 能完成登录并进入首页。
- 首页不显示“路演”“演示”“本机演示已就绪”等主流程提示。
- 隐私范围可切换。
- 各 Tab 不出现旧 mock 家庭、路演家庭、“妈妈”等残留测试数据。

## 2. P0 记忆档案馆：文本素材建库

### 操作步骤

1. 回到首页。
2. 点击右上隐私范围，选择“可生成”。
3. 进入“档案”Tab。
4. 新增文字素材。
5. 输入以下文本：

```text
我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。林桂芳性格慢，常说慢慢来，日子要一张一张照好。
```

6. 保存素材。
7. 回到档案列表，确认素材已出现。
8. 进入“结构化知识库”。
9. 分别查看：
   - 人物
   - 地点
   - 事件
   - 事实
   - 图谱

### 通过标准

- 档案列表出现刚保存的文字素材。
- 人物中出现 `陈建国`、`林桂芳`。
- 地点中出现 `绍兴越城区仓桥直街`、`杭州西湖边`，或合理拆分后的等价地点。
- 事件或事实中出现“小照相馆”“慢慢来”等信息。
- 图谱页不出现旧 seed 或 mock 描述。
- 不出现“妈妈”“路演家庭”“绍兴 -> 杭州 -> 广州”等旧演示数据。

### 建议证据

```text
phase1-memory-archive/screens/archive-list.png
phase1-memory-archive/screens/knowledge-base-after-text.png
phase1-memory-archive/logs/memory-archive-device.log
```

## 3. P0 记忆档案馆：真实照片分析

### 操作步骤

1. 进入“档案”Tab。
2. 新增照片素材。
3. 从相册选择一张真实照片。
4. 隐私范围选择“可生成”。
5. 保存素材。
6. 等待图片分析状态变化。
7. 进入素材详情。
8. 再进入“结构化知识库”查看照片相关摘要、标签、人物、地点或事实。

### 通过标准

- 照片素材出现在档案列表。
- 成功时显示真实分析结果，不是 mock 文案。
- 失败时只显示可理解的失败或重试状态，不能伪装成功。
- 结构化知识库只沉淀可信的照片分析信息。
- 后端同步只应是 metadata，不应包含本地图片路径、图片本体或完整原图内容。

### 建议证据

```text
phase1-memory-archive/screens/photo-analysis.png
phase1-memory-archive/backend/archive-items-redacted.json
```

## 4. P0 记忆档案馆：语音素材与声纹样本

### 操作步骤

1. 进入“档案”Tab。
2. 新增语音素材。
3. 录制 20 到 30 秒语音，内容包含明确人物、地点和事件。
4. 隐私范围选择“可生成”。
5. 保存语音素材。
6. 等待转写、摘要或失败状态。
7. 对同一具体人物连续录制 3 段语音样本。
8. 查看声纹或语音状态。
9. 进入“结构化知识库”查看语音内容是否沉淀。

### 通过标准

- 语音素材出现在档案列表。
- 有转写、摘要、可训练、已就绪或友好失败状态。
- 同一人物的 3 段样本能进入 `readyForTraining` 或明确失败状态。
- 服务不可用时不能假成功。
- 结构化知识库能沉淀语音里的明确实体。

### 建议证据

```text
phase1-memory-archive/screens/voice-profile-status.png
phase1-memory-archive/logs/memory-archive-device.log
```

## 5. P0 数字人：已知记忆引用

### 前置条件

先完成“文本素材建库”，确保知识库中已有：

- `陈建国`
- `林桂芳`
- `杭州西湖边小照相馆`
- `慢慢来`

### 操作步骤

1. 回到首页。
2. 点击右上隐私范围，选择“可生成”。
3. 点击麦克风开始语音对话。
4. 问：

```text
林桂芳以前常说什么？
```

5. 等数字人完整回答。
6. 继续问：

```text
我们以前在哪里开过照相馆？
```

7. 等数字人完整回答。

### 通过标准

- 数字人能引用已沉淀事实，例如“慢慢来”“杭州西湖边小照相馆”。
- 回答不能脱离知识库自由发挥。
- 文字气泡不溢出屏幕。
- 数字人说话时有声音。
- 口型跟随音频，音频结束后嘴部动作停止。
- 一轮回答结束后能继续聆听下一轮。

### 建议证据

```text
phase1-digital-human-grounding/recordings/grounded-dialog-3-5-rounds.mp4
phase1-digital-human-grounding/screens/known-fact-answer.png
phase1-digital-human-grounding/diagnostics/digital_human_playback.log
```

## 6. P0 数字人：未知事实边界

### 操作步骤

1. 保持首页语音对话。
2. 问：

```text
林桂芳最喜欢哪首歌？
```

3. 再问：

```text
她年轻时最喜欢哪个电影演员？
```

4. 观察数字人的回答和知识库变化。

### 通过标准

- 数字人应表达“不确定”“还没有记住”“你可以告诉我”等边界。
- 不能编造歌曲、电影演员或其他没有沉淀的事实。
- 没有证据的内容不能写入结构化知识库。
- 不应在用户话没说完时打断。

### 建议证据

```text
phase1-digital-human-grounding/screens/unknown-fact-boundary.png
phase1-digital-human-grounding/screens/knowledge-base-after-dialog.png
phase1-digital-human-grounding/logs/dialog-memory-grounding.log
```

## 7. P0 数字人：连续 3 到 5 轮稳定性

### 操作步骤

1. 打开系统录屏。
2. 回到首页。
3. 隐私范围选择“可生成”。
4. 连续进行 3 到 5 轮语音对话。
5. 每轮说完后停顿 1 到 2 秒。
6. 观察麦克风状态、文字气泡、数字人动作和声音播放。
7. 自然结束本轮对话。
8. 等待 5 到 10 秒。
9. 进入“档案 -> 结构化知识库”，检查本轮新事实是否沉淀。

### 通过标准

- 不抢话。
- 不重复自问自答。
- 不无故跳回“数字人加载中”。
- 不误触发回忆录生成界面。
- 播放回答时暂停聆听，播放结束后恢复聆听。
- 新的明确事实能进入结构化知识库。

## 8. P1 时空信箱真实信件

### 前置条件

知识库里已有一个具体人物，例如 `林桂芳`。

### 操作步骤

1. 进入“信箱”Tab。
2. 新建信件。
3. 收件人填写：

```text
林桂芳
```

4. 标题填写：

```text
给林桂芳的一封信
```

5. 正文填写一段真实测试内容。
6. 隐私范围选择“可生成”或“亲友”。
7. 投递时间选择当前支持的最短延迟。
8. 当前 App 按 5 分钟最短投递延迟验收。
9. 保存信件。
10. 等待本机通知。
11. 通知到达后进入阅读页。
12. 如有第二台设备，登录同账号或亲友账号检查跨设备恢复情况。

### 通过标准

- 信件能保存。
- 本机通知不暴露正文。
- 阅读页显示边界提示，例如“原信仅本机显示”“不是逝者真实回复”。
- 后端 `/mailbox/letters/{userId}` 不包含 `body`、`replyText`、`bodyPreview`。
- 跨设备只恢复 metadata，不凭空出现正文。
- 信件 metadata 可进入结构化知识库。

### 建议证据

```text
phase1-time-mailbox/screens/create-letter.png
phase1-time-mailbox/screens/delivery-notification.png
phase1-time-mailbox/screens/reader-boundary.png
phase1-time-mailbox/screens/cross-device-metadata-only.png
phase1-time-mailbox/backend/mailbox-letters-redacted.json
```

## 9. P1 亲友与长辈关怀看板

### 前置条件

建议准备两台真机：

- A 设备：长辈账号
- B 设备：亲友账号

如果只有一台设备，先用不同账号做基础验证，但撤回后的跨设备体验仍需第二台设备补测。

### 操作步骤

1. A 设备登录长辈账号。
2. A 设备进入“亲友”Tab。
3. 创建亲友邀请，填写 B 设备手机号、姓名和关系。
4. B 设备登录对应账号。
5. B 设备接受邀请。
6. A 设备回到首页。
7. A 设备隐私范围选择“亲友”。
8. A 设备进行 3 到 5 轮真实对话，内容可包含睡眠、孤独、心情、日常活动等关怀信号。
9. B 设备进入亲友或关怀看板。
10. B 设备查看趋势、摘要和周报。
11. A 设备撤回 B 权限。
12. B 设备刷新关怀看板。

### 通过标准

- B 能看到脱敏趋势、摘要、周报。
- B 看不到 A 的原始聊天 transcript。
- B 看不到完整聊天原文。
- A 撤回后，B 无法继续读取 latest/history。
- B 侧应显示权限失效、权限已撤回或未生效。
- 7 天趋势不应是明显固定 mock 数字。

### 建议证据

```text
phase1-care-dashboard/screens/device-a-invite.png
phase1-care-dashboard/screens/device-b-accept.png
phase1-care-dashboard/screens/device-b-care-dashboard.png
phase1-care-dashboard/screens/device-a-revoke.png
phase1-care-dashboard/backend/latest-redacted.json
phase1-care-dashboard/backend/history-redacted.json
phase1-care-dashboard/backend/revoked-403.txt
```

## 10. 足迹点亮视觉回归

### 操作步骤

1. 进入“足迹”Tab。
2. 确认顶部不再出现“城市 / 全国 / 世界”模式切换。
3. 确认只保留代际选择：
   - 全家
   - 祖辈
   - 父辈
   - 我们
   - 下一代
4. 首次进入时观察默认“全家”地图。
5. 依次点击：
   - 祖辈
   - 父辈
   - 我们
   - 下一代
   - 全家
6. 对比第一次进入的全家地图和切换回来后的全家地图。

### 通过标准

- 首次打开的全家效果，与切换代际后再切回全家的效果一致。
- 祖辈点亮范围为绍兴。
- 父辈点亮范围为浙江。
- 我们点亮范围为江苏、浙江、上海、广东。
- 下一代为灰色待点亮区域。
- 全家为各代区域叠加。
- 各代区域有不同深浅或颜色区分。
- 地图行政边界不应退化成粗糙多边形兜底，除非网络或高德服务失败并有明确提示。

## 11. 后端与隐私抽查

### 操作步骤

1. 完成档案、信箱、关怀任意一项真机测试。
2. 记录测试账号和大概时间。
3. 抽查后端响应。
4. 后端远端 smoke 可使用：

```bash
export DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn
export DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>
export DREAMJOURNEY_BACKEND_REPO=${DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}
PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py --remote
```

### 通过标准

- `/health` 返回 200。
- `/config/runtime` 不带 token 返回 401。
- 带 `DREAMJOURNEY_BACKEND_API_TOKEN` 返回 200。
- runtime、dryRun、snapshot 响应不泄露真实 key 或 token。
- 档案后端记录不含 `localPath`、原始图片、原始音频。
- 信箱后端记录不含 `body`、`replyText`、`bodyPreview`。
- 关怀看板后端记录不含完整 transcript。

### 建议证据

```text
phase1-backend-smoke/health.json
phase1-backend-smoke/runtime.json
phase1-backend-smoke/runtime-without-token.txt
phase1-backend-smoke/image-analysis-dry-run.json
phase1-backend-smoke/kb-snapshot-smoke.json
phase1-backend-smoke/authenticated-smoke.log
```

## 推荐测试顺序

1. 登录与真实模式基线。
2. 记忆档案馆文本素材建库。
3. 结构化知识库检查。
4. 数字人已知事实引用。
5. 数字人未知事实边界。
6. 数字人连续 3 到 5 轮稳定性。
7. 真实照片分析。
8. 语音素材与声纹样本。
9. 时空信箱真实信件。
10. 亲友与长辈关怀看板。
11. 足迹点亮视觉回归。
12. 后端与隐私抽查。

## 问题反馈模板

```text
模块：
步骤：
期望：
实际：
截图/录屏：
测试账号：
大概时间：
是否可稳定复现：
补充说明：
```

## 验收结论记录模板

```text
模块：
结果：通过 / 不通过 / 部分通过
阻塞问题：
非阻塞问题：
证据文件：
下一步：
```
