# PC-E2 产品确认版关闭能力与最终回归

日期：2026-08-20
状态：`COMPLETE_WITH_EXTERNAL_AND_DEVICE_GATES`

## 1. 本轮目标

1. 证明数字人 Session 不再创建或续约，不消耗新配额。
2. 证明时光信和延迟回复不再新建、调度或调用投递 Provider。
3. 回归普通 Echo、档案、正式记忆、家庭、音色、消息中心、Publication 和 Visitor 的关键合同。
4. 将代码完成、外部配置和真机验收拆成独立 readiness 类别，禁止缺失证据被标为成功。

## 2. 实现与版本

| 工程 | 提交 | 说明 |
|---|---|---|
| iOS | `8cd337f19f14beaa6fd2b8ea3e01eae67e9427d9` | PC-E2 最终 Gate、readiness 分类器和测试 |
| Backend | `c4b03f22dc958f823a6849f6327f165c6c591798` | 最终回归与部署态零副作用 smoke 基线 |
| Backend deployed | `06b63406cd2afab6d050e886c19942b2f50da908` | 容器执行、严格 heartbeat 夹具和策略 smoke 收敛后的最终部署 |

服务器 migration head 为 `0104`。API、business message projection、Owner Truth Candidate extraction、media deletion 和 memory projection Worker 均已使用当前提交重建；部署后 API 为 healthy，四个 Worker 为 ready/idle。

## 3. 验证结果

### Backend 本地 Gate

```bash
./scripts/run-backend-product-confirmed-final-closure-gate.sh
```

- 数字人关闭：71 项测试通过。
- 时光信/延迟回复关闭：6 项测试通过。
- 普通核心能力定向回归：178 项测试通过。
- Python compile、wrapper 容器导入守卫和 `git diff --check` 通过。

### Backend 部署态

```bash
sudo docker compose exec -T \
  -e BACKEND_BASE_URL=http://127.0.0.1:8080 \
  api ./scripts/run-backend-product-confirmed-closed-capabilities-deployed-smoke.sh

sudo docker compose exec -T \
  -e BACKEND_BASE_URL=http://127.0.0.1:8080 \
  -e EXPECTED_RELEASE_POLICY_COMMAND_MODE=mixed \
  -e EXPECTED_RELEASE_POLICY_CANARY_FEATURES=familyManagement \
  api ./scripts/run-backend-release-policy-command-deployed-smoke.sh

sudo docker compose exec -T \
  -e BACKEND_BASE_URL=http://127.0.0.1:8080 \
  api ./scripts/run-backend-release-policy-stable-feature-deployed-smoke.sh
```

结构化结果：

- `digitalHumanSessionCreated=0`
- `digitalHumanHeartbeatAccepted=0`
- `timeLetterCreated=0`
- `delayedReplyCreated=0`
- `scheduledDeliveryCount=0`
- `providerDeliveryAttempted=false`
- `/ready` 的 database、schema、auth、incident 均为 ready。

### iOS

```bash
./Scripts/QA/product-v4/run-product-confirmed-final-closure-gate.sh

RUN_ID=20260820-pc-e2-final-regression-host \
LOCAL_BUNDLE_ID=com.yxj.dreamjourney.app \
LOCAL_DEVELOPMENT_TEAM=2BTR77V3R8 \
./Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh
```

- 最终静态/合同 Gate 通过。
- generic iPhoneOS Debug build 通过。
- 构建包 Bundle ID 为 `com.yxj.dreamjourney.app`。
- 构建报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260820-pc-e2-final-regression-host/report.md`。

## 4. Readiness 结论

证据：`artifacts/product-confirmed/20260820-pc-e2/PC-E2/readiness-report.json`。

| 类别 | 结果 | 含义 |
|---|---|---|
| 代码 Gate | `3/3 ready` | Backend、iOS 和 generic iPhoneOS build 已验证 |
| 外部配置 | `0/8 blocked` | OTP、Ownership enforce、私有对象存储/媒体、视觉、声音身份、APNs、Publication/Visitor 审批未关闭 |
| 真机验收 | `0/6 pending` | 麦克风、前后台、音频、相册/文件、APNs 到达和截图日志待真机 |
| 发布结论 | `NO-GO` | 代码完成不能替代外部配置与真机证据 |

## 5. 本轮发现并修复的部署问题

1. 部署脚本新增 `app` 模块依赖后，容器 wrapper 缺少 `PYTHONPATH=/app`；现已固定并加入静态守卫。
2. 旧 release-policy smoke 仍期待伪造 QA 头获得 allow；现改为验证 `observeDeny/missingCapturedPolicy`，family canary 则为 enforce deny。
3. 四个异步 Worker 使用旧镜像，因数据库 migration head 已到 `0104` 而反复重启；现已按当前提交重建并恢复 ready/idle。

## 6. 回滚与剩余 Gate

- 回滚不得重新开放数字人、时光信或延迟回复；必要时只回退 QA 脚本，并保持服务端 `productClosed`。
- 外部 Provider 或审批未完成时，继续由 runtime capability 失败关闭相应能力。
- 本轮未进行真机验收，也未声明真实短信、APNs 到达、真实视觉处理、生产声音训练或公开 Visitor 放量完成。
