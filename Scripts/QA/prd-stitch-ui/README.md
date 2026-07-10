# PRD Stitch UI QA Scripts

This directory stores durable QA and smoke scripts for the PRD/Stitch UI adaptation work.

Conventions:

- Keep reusable `.swift`, `.sh`, and `.py` QA scripts in `Scripts/QA/prd-stitch-ui/`.
- Keep generated reports, build logs, DerivedData, screenshots, and smoke outputs under `tmp/visual-qa/prd-stitch-ui/`.
- `tmp/` is ignored and may be cleaned at any time; do not place durable scripts there.
- Historical evidence already tracked under `tmp/visual-qa/prd-stitch-ui/` is kept for traceability, but new evidence should be treated as generated output unless it is intentionally promoted into `docs/superpowers/status/`.

Common commands:

```bash
Scripts/QA/prd-stitch-ui/run-release-regression.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/digital-human-runtime-abstraction-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/auth-session-ownership-shadow-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/cross-account-authorization-policy-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/route-ownership-audit-check.swift "$PWD"
```

Access/refresh token 与 ownership shadow 的部署后端 smoke：

```bash
DREAMJOURNEY_BACKEND_BASE_URL=https://your-backend.example.com \
DREAMJOURNEY_BACKEND_API_TOKEN='server compatibility token' \
Scripts/QA/prd-stitch-ui/run-backend-auth-session-shadow-smoke.sh
```

该脚本不会输出 access token、refresh token 或后端 token；报告只记录轮换、防重放、注销和 principal-bound mismatch 拒绝的布尔结果。全局模式仍保持 shadow。

合法跨账号授权矩阵的本地/部署后端 shadow smoke：

```bash
DREAMJOURNEY_BACKEND_BASE_URL=https://your-backend.example.com \
DREAMJOURNEY_BACKEND_API_TOKEN='server compatibility token' \
Scripts/QA/prd-stitch-ui/run-backend-cross-account-authorization-shadow-smoke.sh
```

该脚本验证 owner、已接受家庭成员、时间信件收件人和家庭邀请接收人的授权分类，同时确认敏感路由会拒绝伪造 viewer 并只输出脱敏 deny 证据。它不会输出 token、手机号、用户 ID 或信件正文，也不会调用全局 dispatch；生产仍必须保持 `AUTH_OWNERSHIP_MODE=shadow`，直到短信身份校验和部署 shadow 证据完成。

全部业务路由 ownership 分类和 principal-bound 行为的部署 smoke：

```bash
DREAMJOURNEY_BACKEND_BASE_URL=https://your-backend.example.com \
DREAMJOURNEY_BACKEND_API_TOKEN='server compatibility token' \
Scripts/QA/prd-stitch-ui/run-backend-route-ownership-audit-smoke.sh
```

该脚本验证部署环境保持 `ownershipMode=shadow`，同时具备 54 条显式分类、0 条遗漏、owner path/body 越权 403 和 system-only user 403。报告只包含固定布尔值、计数和 policy 指纹，不输出 token、手机号或原始用户 ID，也不会主动运行全局 dispatch。
