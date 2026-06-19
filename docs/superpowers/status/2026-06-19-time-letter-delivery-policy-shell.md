# 时间信件 Delivery Policy Shell

日期：2026-06-19

## 目标

本轮固定时间信件的产品边界：支持草稿、封存、暂不投递、等待产品决策四类状态表达，但不做真实通知/投递。

## 合同

- 草稿：只保留本地编辑、删除和封存能力。
- 封存：可作为回响上下文线索。
- 暂不投递：不会调度本地通知，不会触发 APNs，不调用外部投递 provider。
- 等待产品决策：投递时间、收件人、提醒、取消和失败重试规则都不在当前公开 MVP 开放。

## 验证

```bash
swift tmp/visual-qa/prd-stitch-ui/time-letter-delivery-policy-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ARCHIVE_HIDDEN_SHELL_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## 边界

`RUN_ARCHIVE_HIDDEN_SHELL_SMOKE` 只验证隐藏 QA 下的草稿/封存/暂不投递状态，不声明真实通知或投递闭环完成。
