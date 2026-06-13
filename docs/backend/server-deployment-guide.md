# DreamJourney 后端服务器部署记录

本文档记录 `DreamJourneyBackend` 在当前云服务器上的真实部署状态、访问地址、环境变量管理方式和后续运维命令。

更新时间：2026-06-13

> 注意：本文档不写任何真实密钥。服务器 `.env` 已部署，但这里只记录 key 名和部署方式。

## 1. 服务器现状

| 项目 | 值 |
| --- | --- |
| 公网 IP | `124.221.2.31` |
| 内网 IP | `10.0.0.11` |
| 主机名 | `VM-0-11-ubuntu` |
| 系统 | `Ubuntu 24.04.4 LTS` |
| CPU | `4 核 AMD EPYC 7K62` |
| 内存 | `3.6 GiB`，另有 `1.9 GiB` Swap |
| 磁盘 | `40G`，根目录约 `28G` 可用 |

登录方式：

```bash
ssh ubuntu@124.221.2.31
```

本机 alias：

```bash
ssh miao-server
```

当前已占用端口：

| 端口 | 服务 | 说明 |
| --- | --- | --- |
| `22` | SSH | 登录服务器 |
| `80` | Nginx | HTTP |
| `443` | Nginx | HTTPS |
| `3000` | Node / miao | 当前 miao 应用 |
| `3100` | DreamJourney API | 仅绑定 `127.0.0.1` |
| `5432` | Postgres | 仅 Docker 内网 |
| `6379` | Redis | 仅 Docker 内网 |

UFW 当前为 `inactive`。公网业务入口仍统一走 Nginx 的 `80/443`，不直接开放 `3100/5432/6379`。

## 2. 当前部署结论

后端已经部署完成，当前可用入口是：

```text
https://www.mmdd10.tech/dreamjourney-api/
```

iOS 当前应使用：

```text
DreamJourneyBackendBaseURL=https://www.mmdd10.tech/dreamjourney-api
```

正式规划域名仍是：

```text
https://dreamjourney-api.liftora.cn
```

但截至 2026-06-13，该子域名公网访问会被 DNSPod/Tencent webblock 拦截：

```text
https://dnspod.qcloud.com/static/webblock.html?d=dreamjourney-api.liftora.cn
```

因此正式子域名暂时不能作为生产入口，也暂时不能签发可用 HTTPS 证书。等 `dreamjourney-api.liftora.cn` 完成 DNS A 记录解析到 `124.221.2.31`，并完成备案/接入放行后，再切换为正式入口。

不要把 DreamJourney 后端地址填入 `OpenAvatarChatBaseURL`。`OpenAvatarChatBaseURL` 只保留给旧 OpenAvatarChat 兼容服务；DreamJourney 自有业务后端使用 `DreamJourneyBackendBaseURL`。

## 3. 代码仓库与部署目录

后端仓库：

```text
git@github.com:binxiao9157/DreamJourneyBackend.git
```

服务器部署目录：

```text
/opt/services/dreamjourney/DreamJourneyBackend
```

服务器当前代码来源：

```text
main
3a99be7 fix: stabilize docker deployment on server
```

服务器由 `miao` 用户拉取 Git 仓库，因为当前 `miao` 用户已有 GitHub SSH 权限。`ubuntu` 用户当前没有 GitHub SSH 权限。

检查代码状态：

```bash
sudo -iu miao bash -lc 'cd /opt/services/dreamjourney/DreamJourneyBackend && git status --short --branch && git log --oneline -3'
```

## 4. Docker 安装状态

Docker 已安装。由于服务器访问 Docker 官方源不稳定，实际使用 Ubuntu / 腾讯云镜像源安装：

```text
Docker version 29.1.3
Docker Compose version 2.40.3
```

Docker 服务状态：

```bash
sudo systemctl status docker
```

Compose 也可直接使用：

```bash
sudo docker compose version
```

`ubuntu` 已加入 `docker` 组，但在自动化部署中仍建议使用 `sudo docker ...`，避免 SSH 会话没有刷新用户组导致权限不一致。

## 5. Docker Compose 服务

Compose 文件：

```text
/opt/services/dreamjourney/DreamJourneyBackend/docker-compose.yml
```

当前服务：

| 服务 | 作用 | 暴露方式 |
| --- | --- | --- |
| `api` | DreamJourney FastAPI 后端 | `127.0.0.1:3100 -> 8080` |
| `postgres` | 持久化用户、知识库、记忆、档案、亲友数据 | Docker 内网 |
| `redis` | 预留异步任务和长任务状态 | Docker 内网 |

当前为了适配服务器网络，镜像源使用腾讯云镜像：

```yaml
postgres: mirror.ccs.tencentyun.com/library/postgres:16-alpine
redis: mirror.ccs.tencentyun.com/library/redis:7-alpine
python: mirror.ccs.tencentyun.com/library/python:3.11-slim
```

Python 依赖安装使用腾讯云 PyPI：

```text
https://mirrors.cloud.tencent.com/pypi/simple
```

启动或重建：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --build
```

查看状态：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose ps
```

查看日志：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose logs -f api
```

## 6. 环境变量

服务器 `.env` 路径：

```text
/opt/services/dreamjourney/DreamJourneyBackend/.env
```

权限：

```text
600
owner: miao
group: miao
```

`.env` 已从本机私密文档部署：

```text
DreamJourneyBackend/private/server-env-filled.md
```

已部署的 key：

```text
APP_ENV
PUBLIC_BASE_URL
STORE_BACKEND
DATABASE_URL
REDIS_URL
DEEPSEEK_API_KEY
DEEPSEEK_BASE_URL
VOLCENGINE_API_KEY
VOLCENGINE_VOICE_TYPE
VOLCENGINE_APP_ID
VOLCENGINE_APP_KEY
VOLCENGINE_APP_TOKEN
VOLCENGINE_REALTIME_RESOURCE_ID
VOLCENGINE_REALTIME_ADDRESS
VOLCENGINE_REALTIME_URI
AMAP_WEB_SERVICE_KEY
```

不要提交 `.env`，不要把真实值写入文档、镜像或日志。

更新 `.env` 后注意：`docker compose restart api` 不会重新读取 env_file。必须 recreate API 容器：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --force-recreate api
```

## 7. Nginx 配置

当前已有两个入口配置。

### 当前可用 HTTPS 路径入口

在现有 `www.mmdd10.tech` 站点中增加了路径反代：

```nginx
location /dreamjourney-api/ {
    proxy_pass http://127.0.0.1:3100/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 120s;
    proxy_send_timeout 120s;
    proxy_buffering off;
}
```

配置文件：

```text
/etc/nginx/sites-available/miao
```

当前验证：

```bash
curl https://www.mmdd10.tech/dreamjourney-api/health
```

预期：

```json
{"status":"ok","service":"DreamJourney Backend","environment":"production","store":"postgres"}
```

### 正式子域名配置

已新增 HTTP 反代配置：

```text
/etc/nginx/sites-available/dreamjourney-api
/etc/nginx/sites-enabled/dreamjourney-api
```

内容指向：

```text
dreamjourney-api.liftora.cn -> http://127.0.0.1:3100
```

本机 Host 测试已通过：

```bash
curl -H 'Host: dreamjourney-api.liftora.cn' http://127.0.0.1/health
```

但公网仍被 DNSPod/Tencent webblock 拦截。等备案/接入放行后再执行：

```bash
sudo certbot --nginx -d dreamjourney-api.liftora.cn
sudo nginx -t
sudo systemctl reload nginx
```

然后 iOS 再切换到：

```text
DreamJourneyBackendBaseURL=https://dreamjourney-api.liftora.cn
```

## 8. Smoke Test

本机健康检查：

```bash
curl http://127.0.0.1:3100/health
```

公网临时入口健康检查：

```bash
curl https://www.mmdd10.tech/dreamjourney-api/health
```

运行配置：

```bash
curl https://www.mmdd10.tech/dreamjourney-api/config/runtime
```

当前能力开关已验证全部打开：

```json
{
  "deepseekProxy": true,
  "ttsProxy": true,
  "realtimeToken": true,
  "amapDistrictProxy": true,
  "kbSync": true,
  "familyCircle": true
}
```

关怀看板脱敏快照接口：

```bash
curl -X POST https://www.mmdd10.tech/dreamjourney-api/care/snapshots \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157","snapshot":{"riskLevel":"stable","summary":"脱敏聚合测试"}}'

curl 'https://www.mmdd10.tech/dreamjourney-api/care/snapshots/latest/user_9157'
```

按亲友成员视角保存和读取：

```bash
curl -X POST https://www.mmdd10.tech/dreamjourney-api/care/snapshots \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157","viewerFamilyMemberID":"fm_daughter","snapshot":{"riskLevel":"watch","summary":"女儿视角脱敏聚合测试"}}'

curl 'https://www.mmdd10.tech/dreamjourney-api/care/snapshots/latest/user_9157?viewerFamilyMemberID=fm_daughter'
```

说明：

- App 不上传原始对话，只上传 `CareSignalSnapshot` 这类脱敏聚合结果。
- Postgres 会在服务启动时自动 `CREATE TABLE IF NOT EXISTS care_snapshots`。
- iOS 端本机有真实对话时优先本地分析并上传；本机无数据时才尝试拉取后端最近快照。

登录：

```bash
curl -X POST https://www.mmdd10.tech/dreamjourney-api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800000000","nickname":"陈建国"}'
```

KBLite 同步：

```bash
curl -X POST https://www.mmdd10.tech/dreamjourney-api/kb/sync \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "user_9157",
    "graph": {
      "people": [
        {"id":"p1","name":"陈建国","privacyMetadata":{"scope":"generationAllowed"}},
        {"id":"p2","name":"本机私密人物","privacyMetadata":{"scope":"localOnly"}}
      ],
      "places": [],
      "events": [],
      "facts": []
    }
  }'
```

读取快照：

```bash
curl https://www.mmdd10.tech/dreamjourney-api/kb/snapshot/user_9157
```

预期只看到 `generationAllowed` / `familyCircle` 数据，不会看到 `localOnly` 数据。

高德代理 dry run：

```bash
curl -G https://www.mmdd10.tech/dreamjourney-api/maps/district \
  --data-urlencode 'keyword=绍兴市' \
  --data-urlencode 'dryRun=true'
```

TTS dry run：

```bash
curl -X POST 'https://www.mmdd10.tech/dreamjourney-api/tts?dryRun=true' \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157","text":"你好，我想听一段家族回忆。"}'
```

实时语音 token：

```bash
curl -X POST https://www.mmdd10.tech/dreamjourney-api/voice/realtime-token \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user_9157"}'
```

当前返回 `authMode=legacy`，说明 AppID / AppKey / AppToken 已生效。

## 9. 更新部署

后续更新代码：

```bash
sudo -iu miao bash -lc 'cd /opt/services/dreamjourney/DreamJourneyBackend && git pull'
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --build
```

如果只更新 `.env`：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo install -o miao -g miao -m 600 /tmp/dreamjourney-server.env .env
sudo docker compose up -d --force-recreate api
```

查看容器：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose ps
```

查看 API 日志：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose logs -f api
```

停止服务，保留数据库卷：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose down
```

清空数据库卷，谨慎使用：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose down -v
```

## 10. 数据库

Postgres 容器首次启动时会自动初始化表：

- `users`
- `kb_snapshots`
- `memories`
- `archive_items`
- `family_members`

查看表：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose exec postgres psql -U dreamjourney -d dreamjourney -c '\dt'
```

数据卷：

```text
dreamjourneybackend_postgres_data
```

## 11. 当前已修复的问题

部署过程中发现并修复了两个生产问题，已提交到后端仓库：

```text
3a99be7 fix: stabilize docker deployment on server
```

修复内容：

- Docker Hub / PyPI 在服务器上访问不稳定，改为腾讯云 Docker / PyPI 镜像源。
- `psycopg` 不会自动把 Python `dict` 适配为 JSONB，导致 `/auth/login`、`/kb/sync` 写库 500。现已用 `psycopg.types.json.Jsonb` 包装 dict 参数。
- 增加测试覆盖 JSONB 参数包装。

本地后端仓库测试已通过：

```text
12 passed
```

## 12. 当前限制与后续动作

当前限制：

1. `dreamjourney-api.liftora.cn` 还不能公网使用，当前被 DNSPod/Tencent webblock 拦截。
2. 生产入口暂时使用 `https://www.mmdd10.tech/dreamjourney-api`。
3. `PUBLIC_BASE_URL` 当前已临时配置为 `https://www.mmdd10.tech/dreamjourney-api`，因此 `/config/runtime` 返回的 `baseURL` 与当前可用入口一致。

### 12.1 临时入口与 `PUBLIC_BASE_URL` 确认步骤

临时入口期间，服务器 `.env` 应保持：

```bash
PUBLIC_BASE_URL=https://www.mmdd10.tech/dreamjourney-api
```

如果修改 `.env`，不要只执行 `docker compose restart api`。`env_file` 的值需要 recreate 容器才会重新读取：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --force-recreate api
```

确认 runtime：

```bash
curl https://www.mmdd10.tech/dreamjourney-api/config/runtime
```

预期返回中包含：

```json
"baseURL": "https://www.mmdd10.tech/dreamjourney-api"
```

iOS 真机测试期间也应使用：

```text
DreamJourneyBackendBaseURL=https://www.mmdd10.tech/dreamjourney-api
```

建议后续动作：

1. 在 DNSPod 添加/确认 `dreamjourney-api.liftora.cn -> 124.221.2.31`。
2. 完成 `.cn` 域名备案/腾讯云接入放行。
3. 运行 `sudo certbot --nginx -d dreamjourney-api.liftora.cn`。
4. 证书签发后，把 iOS `DreamJourneyBackendBaseURL` 切到 `https://dreamjourney-api.liftora.cn`。
5. 证书签发后，如果要让 runtime 返回正式域名，把服务器 `.env` 的 `PUBLIC_BASE_URL` 改为 `https://dreamjourney-api.liftora.cn` 后执行：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --force-recreate api
```
