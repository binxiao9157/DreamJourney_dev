# Ownership Audit Gate 固化

## Problem

缺少跨后端注册表、principal-bound 中间件、iOS system 调度边界和部署 HTTP 行为的一键检查。

## Success Criteria

- 新增静态 audit check，校验 54 路由、0 未分类、principal-bound block 和 iOS 无生产 dispatch。
- 新增 deployed route ownership HTTP smoke，报告不含 token、手机号或原始 user id。
- release regression 提供可选开关运行 deployed smoke，默认不影响公开 MVP gate。
- 相关后端测试、Swift QA 和 iOS generic build 通过。
