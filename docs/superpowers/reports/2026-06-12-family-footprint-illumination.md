# Family Footprint Illumination

## 目标

将足迹页从“回忆点标注”升级为接近高德足迹海报的“点亮地图”表达：

- 城市 / 全国 / 世界三档视角。
- 不同代际筛选会驱动点亮区域变化。
- 地图页保留可点击回忆点，同时增加行政区块式发光面层。
- 边界数据优先走可替换缓存，避免将 Demo 多边形永久写死在页面控制器中。

## 当前实现

- `MapFootprintViewController`
  - 只负责地图底图、overlay 渲染、交互刷新。
  - 使用 `MAPolygon` 和 `MAPolygonRenderer` 绘制青色点亮区域。
  - 切换城市 / 全国 / 世界或代际时，刷新统计、点亮面层和足迹点。

- `FamilyFootprintIllumination`
  - 负责足迹点到点亮区域的映射。
  - 支持 `family_footprint_boundaries.json` 的 bundle 边界缓存。
  - 如果 bundle 缓存不存在或覆盖不足，回落到内置 Demo 边界。
  - 统一输出统计文案、overlay 坐标、颜色样式和视野 padding。

- `FamilyFootprintTimeline`
  - 新增 `FamilyFootprintJourneySummary`，从当前代际足迹生成迁徙故事线、跨城/跨国摘要和“更大的世界”表达。
  - 地图页顶部故事卡和分享海报复用同一摘要，避免 UI 与海报叙事不一致。

## 设计取舍

当前工程未集成 `AMapSearch` / DistrictSearch SDK，因此没有直接调用高德行政边界查询的能力。为了不阻塞真机与路演 Demo，本阶段先做本地边界 provider：

1. 有真实边界缓存时，优先使用 bundle JSON。
2. 缓存缺失时，使用内置近似多边形保证体验不断。
3. 后续接入真实数据时，只需要生成或下载 `family_footprint_boundaries.json`，或新增 AMapSearch provider。

## 边界缓存格式

`family_footprint_boundaries.json` 建议格式：

```json
{
  "regions": [
    {
      "scope": "nation",
      "name": "杭州",
      "center": [120.155, 30.274],
      "approximateAreaKm2": 16850,
      "polygons": [
        [
          [119.5, 30.2],
          [120.1, 30.8],
          [120.7, 30.1]
        ]
      ]
    }
  ]
}
```

坐标顺序使用 GeoJSON 习惯：`[longitude, latitude]`。

## 验证

- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- `xcrun swiftc -sdk iphoneos -target arm64-apple-ios15.0 -typecheck ... FamilyFootprintIllumination.swift`
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj DreamJourney/Resources/Info.plist`
- `git diff --check`

## 2026-06-12 追加推进：足迹分享海报

已完成第一版“当前筛选状态 -> 竖版足迹海报 -> 预览 / 分享 / 导出”的路演闭环。

- 新增 `FamilyFootprintSharePosterDescriptor`，从当前 `FootprintIlluminationScope`、`FamilyFootprintGeneration` 和 `FamilyFootprintPoint` 生成海报标题、日期范围、叙事、统计数字、二维码 payload 和点亮区域摘要。
- 新增 `FamilyFootprintSharePosterRenderer`，用 UIKit 本地合成深色地图感海报：深色背景、青色点亮区域、足迹点、家族标题、代际 / 范围标签、统计卡片、二维码和“寻梦环游 · 家族记忆地图”脚注；点亮区域和迁徙点线共用同一坐标 bounds，避免跨省/跨国视角下点线与区域投影比例不一致。
- 海报地图会按时间顺序把足迹点连成迁徙线，统计面板展示 `FamilyFootprintJourneySummary` 生成的路线与“更大的世界”摘要。
- 新增 `FamilyFootprintSharePosterPreviewViewController`，提供海报预览、“分享给家人”和“保存图片”按钮；保存走 `UIDocumentPickerViewController` 文件导出，避免新增相册权限。
- `MapFootprintViewController` 新增浮动分享按钮，host 模式隐藏导航栏时仍可见；点击会暂停代际播放动画，并按当前城市 / 全国 / 世界与全家 / 祖辈 / 父辈 / 我们 / 下一代筛选状态生成海报；顶部故事卡展示当前代际的迁徙路线、年份、城市数、国家数和世界半径变化。
- 新增 `Scripts/FamilyFootprintPosterVerify/main.py`，并接入 `Scripts/verify_phase2.sh`，覆盖海报入口、迁徙路线连线、二维码、文件导出、工程 target 引用和 iOS SDK typecheck。

当前实现没有直接截取高德地图瓦片，而是用现有足迹点与本地点亮区域合成路演图。这样不依赖额外高德 DistrictSearch 能力，真机上可先验证“点亮表达 + 分享成果物”是否达到演示预期。

验证结果：

- `python3 Scripts/FamilyFootprintPosterVerify/main.py` 通过。
- `bash Scripts/verify_phase2.sh` 通过。
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/DreamJourneyDeviceBuild build` 通过。

真机验证重点：

- 足迹页右侧分享按钮是否遮挡定位按钮或底部统计栏。
- 切换城市 / 全国 / 世界、全家 / 祖辈 / 父辈 / 我们 / 下一代后，海报标题、统计和点亮区域是否跟随变化。
- 海报预览中文字是否截断，二维码是否清晰，系统分享和文件导出是否可用。

## 后续

- 用真实行政区 GeoJSON 替换内置近似数据。
- 如果产品确认引入高德搜索 SDK，则新增 `AMapDistrictBoundaryProvider`，将查询结果写入同一缓存格式。
- 分享海报后续可升级为真实地图截图、真实家庭邀请链接二维码和家族头像合成。
