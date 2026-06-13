# 家族足迹时空地图实现记录

日期：2026-06-12

## 目标

把现有足迹地图从“单人回忆点列表”升级成路演可讲清楚的“家族足迹时空地图”：

- 类似高德点亮地图，但叙事重点是家庭记忆，不是打卡。
- 支持按代际查看：全家、祖辈、父辈、我们、下一代。
- 通过年份顺序与地图点亮表达家族生活半径变大。
- 点击真实回忆点仍进入现有记忆详情；路演扩展点只展示轻量故事卡，不伪造完整详情。

## 多 agent 收敛

- 产品/路演 agent：建议把该功能作为足迹 Tab 的上层叙事入口，优先做代际筛选、时间回放、点亮统计，避免第一版扩成复杂 GIS。
- 工程 agent：确认 `MemoryModel` 已具备地点、年份、坐标、隐私和 owner 字段；不建议为 demo 增加非 optional Codable 字段，避免破坏旧 UserDefaults 解码。
- 主控决策：新增派生模型 `FamilyFootprintPoint`，不改持久化模型；地图页负责 UI 和交互，时间轴规则集中到独立文件。

## 已实现

- 新增 `FamilyFootprintTimeline`
  - 代际枚举：全家、祖辈、父辈、我们、下一代。
  - 从 `MemoryModel` 派生 `FamilyFootprintPoint`。
  - 根据年份和文本关键词进行代际归类。
  - 路演主态补充绍兴老宅、深圳南山、温哥华三个扩展点，强化“更大的世界”。
  - 提供筛选、统计文案、叙事文案、播放顺序。

- 升级 `MapFootprintViewController`
  - 顶部新增代际分段控件。
  - 新增叙事浮层，展示当前代际的故事摘要。
  - 新增播放按钮，按祖辈、父辈、我们、下一代、全家的顺序自动切换。
  - 新增家族足迹标注样式，不影响旧 `MemoryAnnotationView` 分支。
  - 真实回忆点点击进入 `MemoryDetailViewController`。
  - 路演扩展点点击弹出轻量故事卡。

- 新增验证脚本
  - `Scripts/FamilyFootprintVerify/main.swift`
  - 已接入 `Scripts/verify_phase2.sh`

## 2026-06-12 追加推进

- 亲友页新增“家族足迹地图”快捷入口，与“长辈关怀看板”一起形成亲友页的两条家庭协作主线。
- 新增 `FamilyCircleQuickAction`，将亲友页快捷动作标题、说明、图标和无障碍文案集中管理。
- “家族足迹地图”入口以 push 形态进入足迹页，保留返回按钮，同时显式开启路演扩展点，保证可以讲出“绍兴老宅 → 深圳南山 → 温哥华”的家族生活半径扩展。
- 修正点亮地图 fallback 语义：全国视角不再因为当前代际足迹少而默认点亮一组全国城市；世界视角也不再默认点亮中国，而是只点亮当前代际足迹实际对应的国家。
- 新增 `FamilyFootprintIlluminationPolicyVerify`，防止代际点亮逻辑退回到“默认全国/默认中国”的失真策略。

## 验证

- `xcrun swiftc ... FamilyFootprintVerify/main.swift`：通过。
- `xcrun swiftc ... FamilyCircleQuickActionsVerify/main.swift`：通过。
- `python3 Scripts/FamilyFootprintIlluminationPolicyVerify/main.py`：通过。
- `bash Scripts/verify_phase2.sh`：通过。
- iPhoneOS Debug 构建：通过。
- `git diff --check && git diff --cached --check`：通过。

## 已知限制

- 当前第一版没有绘制跨城市轨迹线，先用代际点亮和视野聚焦保证稳定性。
- 全家聚合 owner 仍是派生演示层，未接入真实多成员授权图谱。
- 模拟器运行被既有 `SpeechEngineToB/libspeechsdk` 和 Pods simulator 架构配置阻断；真机/iPhoneOS 编译可通过。
- `Info.plist` 中存在本机测试密钥配置，提交前需要按团队策略转为本地 xcconfig 或环境注入，避免泄露。

## 下一步建议

- 把路演 seed 中的家族成员与足迹 owner 做更稳定映射。
- 第二版增加轨迹线/年份进度条，但不要牺牲地图稳定性。
- 补充真实行政区边界缓存，降低内置 blob fallback 的“示意图”观感。
- 真机验证重点：亲友页家族足迹入口、足迹 Tab 首屏、代际切换、播放按钮、真实回忆点详情、扩展点故事卡、返回后的地图状态。
