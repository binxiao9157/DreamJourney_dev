# 补齐 Widget 扩展嵌入、Bundle ID 与 App Group 配置

## Problem

主 App 当前没有嵌入 Widget extension，也没有依赖关系；主/扩展 target 缺少 App Group entitlement，Widget Bundle ID 与本地覆盖后的主 App 不同源，无法可靠签名交付。

## Success Criteria

- 新策略/存储 Swift 文件加入主 target sources。
- 主 App 增加 Embed App Extensions copy phase 和 Widget target dependency。
- 主/Widget entitlements 含相同可配置 App Group；Info.plist 可读取相同 identifier。
- Widget bundle ID 为主 App bundle ID 加 `.widget`，development team 同源。
- Simulator 与 generic iPhoneOS build 通过，构建 App 包内存在 Widget `.appex`。
- 文档声明真实 Developer Portal capability/provisioning 仍待真机验收。
