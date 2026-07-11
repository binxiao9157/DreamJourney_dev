# Coordinator 分页集成与交付验收

## Problem

正常 sync 和 409 refresh 各自发起一次性 change 请求；分页中没有 pull session/generation/终页提交边界，也没有长期组合门禁。

## Success Criteria

- 正常 sync/409 refresh 共用 paginated pull state machine。
- user/generation/pullSession 失效页被丢弃；终页前无 base/pending/KBLite/mutation/governance 副作用。
- 终页 CAS merge 有界重算后只 push 一次。
- QA/release/docs 更新，后端全量、跨仓 gate、Simulator/generic iPhoneOS build 通过。
- 两仓独立提交，不推送、不部署、不真机。
