# iOS 工程后端运行配置说明

更新时间：2026-06-15
适用对象：DreamJourney iOS 工程真机调试、联调、交付验证。

> 本文档不包含真实 token、API Key 或服务器 `.env` 明文。`DreamJourneyBackendAPIToken` 必须由有服务器权限的负责人单独通过安全渠道提供。

## 1. 当前后端入口

当前可用的 DreamJourney 业务后端地址：

```text
https://www.mmdd10.tech/dreamjourney-api
```

正式规划域名：

```text
https://dreamjourney-api.liftora.cn
```

正式域名完成 DNS、备案接入和 HTTPS 放行前，iOS 先使用 `https://www.mmdd10.tech/dreamjourney-api`。

不要把这个地址配置到 `OpenAvatarChatBaseURL`。DreamJourney 自有业务后端只使用：

```text
DreamJourneyBackendBaseURL
```

## 2. 必配项

新电脑、新真机至少配置以下三项：

| 配置项 | 必填 | 用途 |
| --- | --- | --- |
| `DreamJourneyBackendBaseURL` | 是 | DreamJourney 业务后端入口 |
| `DreamJourneyBackendAPIToken` | 是 | 后端接口鉴权；必须与服务器 `BACKEND_API_TOKEN` 完全一致 |
| `AMapAPIKey` | 地图链路需要 | iOS 高德 SDK Key，用于足迹地图 |

当前后端已经启用 `BACKEND_API_TOKEN`。除 `/health` 外，iOS 请求后端接口时需要携带同值 token，否则会返回 `401`。

## 3. 推荐配置方式：LocalConfig.plist

在 iOS 工程创建本地配置文件：

```text
DreamJourney/Resources/LocalConfig.plist
```

该文件已经加入 `.gitignore`，不要提交到仓库。

示例内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DreamJourneyBackendBaseURL</key>
    <string>https://www.mmdd10.tech/dreamjourney-api</string>

    <key>DreamJourneyBackendAPIToken</key>
    <string>填入服务器 BACKEND_API_TOKEN 的真实值</string>

    <key>AMapAPIKey</key>
    <string>填入 iOS 高德 SDK Key</string>
</dict>
</plist>
```

`DreamJourneyBackendAPIToken` 的值来自服务器：

```text
/opt/services/dreamjourney/DreamJourneyBackend/.env
```

对应 key：

```text
BACKEND_API_TOKEN
```

不要把真实值写入文档、截图、聊天记录或 Git 提交。

## 4. 可选配置方式：Xcode Scheme 环境变量

也可以不创建 `LocalConfig.plist`，直接在 Xcode Scheme 中配置：

```text
Product -> Scheme -> Edit Scheme... -> Run -> Arguments -> Environment Variables
```

添加：

```text
DreamJourneyBackendBaseURL=https://www.mmdd10.tech/dreamjourney-api
DreamJourneyBackendAPIToken=<服务器 BACKEND_API_TOKEN 同值>
AMapAPIKey=<iOS 高德 SDK Key>
```

Scheme 环境变量优先级高于 `LocalConfig.plist`。

## 5. 配置读取优先级

iOS 当前读取顺序：

```text
Xcode Scheme 环境变量
  -> DreamJourney/Resources/LocalConfig.plist
  -> DreamJourney/Resources/Info.plist
```

`Info.plist` 只应保留占位符或非敏感默认值，不要写入真实 token 或第三方 key。

## 6. 不需要在新电脑重复配置的项

当前后端已经集中保存并代理这些能力，新电脑/新真机正常情况下不需要本地配置：

```text
DeepSeekAPIKey
VolcEngineAPIKey
VolcEngineAppID
VolcEngineAppKey
VolcEngineAppToken
VolcEngineRealtimeResourceID
VolcEngineRealtimeAddress
VolcEngineRealtimeURI
AMapWebServiceKey
```

只有在后端不可用、做离线开发兜底或排查第三方链路时，才考虑临时配置这些本地项。

## 7. 验证后端是否可用

负责人可以用 curl 验证。先设置环境变量：

```bash
export DJ_API='https://www.mmdd10.tech/dreamjourney-api'
export DREAMJOURNEY_BACKEND_API_TOKEN='<服务器 BACKEND_API_TOKEN 同值>'
```

健康检查不需要 token：

```bash
curl -i "$DJ_API/health"
```

预期返回 `200`，并包含：

```json
{"status":"ok","service":"DreamJourney Backend","environment":"production","store":"postgres"}
```

运行配置需要 token：

```bash
curl -i "$DJ_API/config/runtime" \
  -H "Authorization: Bearer ${DREAMJOURNEY_BACKEND_API_TOKEN}"
```

预期返回 `200`，并且 `capabilities.realtimeToken=true`。

实时语音配置验证：

```bash
curl -s -X POST "$DJ_API/voice/realtime-token" \
  -H "Authorization: Bearer ${DREAMJOURNEY_BACKEND_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157"}' \
  | python3 -m json.tool
```

预期包含：

```text
authMode=legacy
appID/appKey/appToken 存在
resourceID=volc.speech.dialog
address=wss://openspeech.bytedance.com
uri=/api/v3/realtime/dialogue
```

该接口会返回 SDK 启动所需凭证，验证时不要把完整响应截图或发到群里。

## 8. 常见问题

### App 提示语音服务暂不可用

优先检查：

1. `DreamJourneyBackendBaseURL` 是否为 `https://www.mmdd10.tech/dreamjourney-api`。
2. `DreamJourneyBackendAPIToken` 是否与服务器 `BACKEND_API_TOKEN` 完全一致。
3. `/voice/realtime-token` 带 token 调用是否返回 `200`。
4. 修改 `LocalConfig.plist` 或 Scheme 后是否重新安装/启动 App。

### 后端接口返回 401

原因通常是未配置 token，或 token 与服务器不一致。

处理：

```text
重新确认 DreamJourneyBackendAPIToken == 服务器 BACKEND_API_TOKEN
```

注意不要多复制空格、换行或引号。

### 真机访问失败但 Mac curl 正常

优先检查：

1. App 配置是否写成了 `localhost`。真机不能用 Mac 自己的 `localhost` 访问服务器。
2. URL 是否缺少 `/dreamjourney-api` 前缀。
3. 是否把地址误填到了 `OpenAvatarChatBaseURL`。
4. 真机网络是否能访问公网 HTTPS。

## 9. 交付提醒

- `DreamJourney/Resources/LocalConfig.plist` 是本机私密文件，不能提交。
- `DreamJourneyBackendAPIToken` 是生产后端访问凭证，不能进入仓库、文档或截图。
- `Info.plist` 不应写真实 token。
- 正式域名 `dreamjourney-api.liftora.cn` 放行前，不要把 iOS 配置切过去。
