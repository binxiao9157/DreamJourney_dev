# P2-1 线上后端 Smoke 与安全配置验收

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 远端命令

```bash
export DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn
export DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>
PYTHONPATH=DreamJourneyBackend STORE_BACKEND=memory DreamJourneyBackend/.venv/bin/python Scripts/BackendAuthenticatedSmoke/main.py --remote \
  | tee docs/superpowers/evidence/phase1-backend-smoke/authenticated-smoke.log
```

期望：

- `/health` 为 200。
- `/config/runtime` 不带 token 为 401。
- 带 `DREAMJOURNEY_BACKEND_API_TOKEN` 为 200。
- runtime、dryRun、snapshot 响应不泄露原始 key/token。
- 能力状态仅为 bool 或 configured/missing，不出现真实密钥值。

## 证据文件

- `health.json`
- `runtime.json`
- `runtime-without-token.txt`
- `image-analysis-dry-run.json`
- `kb-snapshot-smoke.json`
- `authenticated-smoke.log`
