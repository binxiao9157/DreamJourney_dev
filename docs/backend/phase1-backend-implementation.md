# 阶段1最小后端实现说明

后端工程已剥离为独立仓库：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`，远程为 `git@github.com:binxiao9157/DreamJourneyBackend.git`。iOS 仓库通过 `DreamJourneyBackendBaseURL` 访问后端，不再内嵌后端源码。

## 已覆盖能力

- 服务端运行配置：`GET /config/runtime` 只暴露能力状态，不泄露密钥。
- 火山实时对话配置：`POST /voice/realtime-token` 返回 iOS `SpeechEngineToB` 可直接启动的实时连接配置；该接口必须通过 `BACKEND_API_TOKEN` / `DreamJourneyBackendAPIToken` 保护，避免把火山运行凭证作为公开接口暴露。
- 火山 TTS 代理：`POST /tts` 默认转发到火山 TTS，`dryRun=true` 可查看脱敏请求。
- 高德行政区代理：`GET /maps/district` 默认转发高德 WebService，`dryRun=true` 可查看脱敏 URL。
- KBLite 同步：`POST /kb/sync` 过滤 `localOnly`，保留可同步图谱。
- 记忆、档案、亲友最小接口：默认写入 Postgres JSONB 表，支持服务重启后继续测试。
- 长辈关怀看板脱敏快照：`POST /care/snapshots` 保存本机分析后的聚合快照，`GET /care/snapshots/latest/{user_id}` 按全家或指定 `viewerFamilyMemberID` 拉取最近快照。

## 未完成但已预留

- Redis 异步任务队列。
- 照片对象存储。
- DeepSeek chat / image analyze 统一代理。
- Safety Guard 后端化。
- 更完整的亲友权限校验和服务端关怀信号分析；当前 care snapshot 只存脱敏聚合结果，不上传原始对话。

## 验收

核心服务使用标准库 `unittest` 验证，不依赖 FastAPI 安装：

```bash
export DREAMJOURNEY_BACKEND_REPO=${DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}
PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" python3 -m unittest discover "$DREAMJOURNEY_BACKEND_REPO/tests"
```

如果本机使用仓库虚拟环境，推荐直接运行：

```bash
bash Scripts/verify_backend.sh
```

FastAPI 本机 smoke 可显式切到内存模式，避免本机未启动 Postgres 时阻塞：

```bash
export DREAMJOURNEY_BACKEND_REPO=${DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}
STORE_BACKEND=memory PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" python - <<'PY'
from fastapi.testclient import TestClient
from app.main import app
client = TestClient(app)
assert client.get("/health").json()["status"] == "ok"
PY
```

关怀快照接口 smoke：

```bash
curl -X POST http://127.0.0.1:3100/care/snapshots \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157","snapshot":{"riskLevel":"stable","summary":"脱敏聚合测试"}}'

curl 'http://127.0.0.1:3100/care/snapshots/latest/user_9157'
```
