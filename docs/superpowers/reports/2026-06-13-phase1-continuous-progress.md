# 阶段一持续推进记录 - 2026-06-13

目标：向 `docs/阶段一.docx` 的阶段一产品规划靠拢，优先保证真机可验收的核心闭环。

## 本轮完成

### 1. 记忆档案馆：补齐语音素材入口

- `MemoryArchiveItemKind` 新增 `voiceSample`。
- 档案馆首页新增“导入语音素材”入口，通过系统文件选择器导入音频。
- 导入音频会复制到 App 沙盒 `Documents/archive_voice_samples`，不再只是占位记录。
- 语音素材沿用四档隐私：
  - 私密：只留档案馆。
  - 本机：只本机保存。
  - 可生成：仅沉淀“语音样本元信息”，不把音频正文当作对话共享。
  - 亲友：需要继续选择亲友可见范围。
- 档案馆统计新增“语音”数量。

### 2. 记忆档案馆：文本素材保存后立即进入结构化抽取

- 新增 `Stage1MemoryFacade.ingestArchiveTextMaterial`。
- 档案馆保存非私密文本素材后，会立即触发 KBLite 抽取。
- 私密素材仍只保存在档案馆，不进入结构化知识库。
- 这解决了“保存明确实体信息后，结构化知识库没有生成”的主要链路问题。

### 3. 时空信箱：回声接入授权记忆证据

- `TimeMailboxRepository.refreshDelivery` 支持传入 `TimeMailboxEchoEvidence`。
- App 运行时从 `KBLiteManager.sanitizedGraph(for: .timeMailboxEcho)` 取授权图谱。
- 回声有匹配记忆时会列出“我能参考到的已授权记忆”。
- 没有匹配记忆时明确说明“不会替Ta编造具体经历”。
- 所有回声继续保留“不是逝者真实回复”的边界声明。

### 4. 数字人首帧切换修复仍保留

- 真视频/画布首帧未 ready 前，不再先显示假的 fallback 人像再切换。
- spinner 文案保持“正在准备真人数字人”，直到真实视频首帧 ready。

### 5. 演示数据污染检查

- `RoadshowDemoSeed.applyIfRequested` 只有在显式启动参数或环境变量存在时才会注入演示数据：
  - `--seed-roadshow-demo`
  - `--reset-roadshow-demo`
  - `--roadshow-offline-mode`
  - `DREAMJOURNEY_SEED=roadshow_demo`
  - `DREAMJOURNEY_RESET_DEMO=1`
  - `DREAMJOURNEY_ROADSHOW_OFFLINE=1`
- 足迹页当前 `shouldIncludeDemoExpansion` 默认为 `false`，真实模式不会合并 roadshow expansion points。
- 如果真机仍看到旧路演家庭/妈妈/示例足迹，大概率来自旧安装残留容器数据，可在数字人诊断页使用“清理本机测试数据”入口处理。

### 6. 真机测试数据清理入口

- 数字人诊断页新增“清理本机测试数据”，带二次确认。
- 清理范围：路演 seed/offline 标记、时空信箱、记忆档案、足迹已读/弹跳状态、路演路线完成状态、对话记忆、KBLite 本机图谱、归档照片、归档语音素材、回忆录本机目录。
- 不清理范围：API Key、后端地址、登录信息和服务器数据。
- 本机清理调用 `KBLiteManager.reset(syncToBackend: false)`，不会把空知识库同步到业务后端。
- 新增 `Scripts/LocalTestDataCleanupVerify/main.py`，并接入 `Scripts/verify_phase1.sh`。

## 真机验收建议

### 记忆档案馆

1. 进入“档案”。
2. 点击“添加文字素材”，选择“可生成”。
3. 输入：

   ```text
   我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。
   ```

4. 保存后等待 3-10 秒。
5. 进入“结构化知识库”，预期应出现人物、地点、事件或事实。
6. 再导入一段本地音频，确认档案统计中的“语音”数量增加。

### 时空信箱

1. 先完成上面的记忆档案馆文本素材沉淀。
2. 进入“信箱”，写给“林桂芳”或“陈建国”的信。
3. 投递时间选择“立即”或“1 分钟”。
4. 打开投递后的信件。
5. 预期回声包含：
   - “不是逝者真实回复”。
   - 如有匹配，出现“我能参考到的已授权记忆”。
   - 如无匹配，明确说明不会编造具体经历。

### 长辈关怀看板

当前代码已验证：

- 空数据显示“数据不足”，不会显示“状态稳定”。
- 周报只含脱敏聚合信号，不含原始聊天内容。
- selected-member 可见性会过滤非授权成员内容。

## 已运行验证

- `MemoryArchive verification passed`
- `TimeMailbox verification passed`
- `CareDashboard verification passed`
- `SecretConfig verification passed`
- `LocalTestDataCleanup verification passed`
- `git diff --check`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

结果：以上均通过。

## 下一步

1. 把关怀看板从“本机最近 transcript”逐步接到后端/亲友同步数据源。
2. 为时空信箱补本地通知或服务端投递状态，避免必须打开页面才刷新。
3. 补真机证据包：档案入库截图、结构化知识库截图、信箱回声截图、关怀周报导出文本。
