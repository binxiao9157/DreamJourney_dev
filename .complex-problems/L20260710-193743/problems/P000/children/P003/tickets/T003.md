# 非真机 QA Gate 与文档收敛

## Problem

跨账号授权需要可重复的本地 HTTP 证据和 release gate；仅有后端单测不足以证明 iOS 请求合同、runtime 能力声明和交付文档保持一致。

## Success Criteria

- 新增跨账号授权 HTTP smoke 和运行脚本。
- 新增 Swift 静态 guard，并接入 release QA package 与可选 release regression 开关。
- `/config/runtime` 暴露授权策略合同版本和默认 shadow 状态。
- 后端全量测试、HTTP smoke、release QA、generic iPhoneOS/simulator build 和 `git diff --check` 通过。
- 文档明确生产 enforce、短信身份校验和真机验收仍未完成。
