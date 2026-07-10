# 统一知识管线验证与交付成功检查

## Summary

P004 的非真机交付标准已满足。两仓库均有完整验证证据，部署态合同已固化为可选 gate，状态文档没有把基础增量知识管线夸大为向量检索或线上真机验收完成。

## Evidence

- 后端全量验证通过 182 个测试、FastAPI smoke、knowledge delta smoke 和 diff check。
- 本地等价部署环境执行 knowledge deployed smoke 通过登录、revision、幂等、change feed、generation context 与 409 conflict。
- iOS 全量 release regression 和 generic iPhoneOS build 通过。
- Archive -> Echo 模拟器 smoke 显示 `containsArchiveContext=true`，延迟回信通知 smoke 验证 pending request。
- 两仓库状态文档列明服务器部署和真机/provider 残余项。

## Criteria Map

- 后端测试与知识 smoke：全部通过。
- iOS 隔离、同步/提取、Echo、release 与设备通用构建：静态门和全量回归通过。
- diff 与改动清单：两仓库 diff check 通过，状态文档按模块记录。
- 文档边界：明确 P0 基础管线、旧端兼容、无向量库以及后续 P1/P2。

## Execution Map

- R005 记录脚本、回归报告、截图和文档产物。
- 默认 release regression 不访问隐藏/部署功能；部署态知识 gate 通过显式环境变量开启。

## Stress Test

- 重复 operation ID 不重复写入；stale revision 返回 409 并可重新拉取。
- Archive 隐私元数据缺失时后端拒绝同步；补齐 generationAllowed 后主链路通过。
- 模拟器与 generic iPhoneOS 分别覆盖可运行流程和 arm64/腾讯 SDK 链接。

## Residual Risk

- 服务器尚需部署本轮后端后再跑真实 Postgres smoke；这是部署验收，不阻塞代码与非真机交付闭环。
- 线上 ChatRagText 的语义效果仍需真机验证。

## Result IDs

- R005
