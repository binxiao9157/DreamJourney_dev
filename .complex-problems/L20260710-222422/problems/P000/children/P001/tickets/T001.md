# 全路由注册表与覆盖测试

## Problem

当前没有机器可校验的完整 FastAPI ownership 清单，新增或修改路由可能绕过 user/system/delegated 分类。

## Success Criteria

- 所有业务路由有唯一显式分类。
- 注册表支持 actual path 匹配和 owner path/body 提取。
- 新增未分类、重复分类或高风险路由使用 service/public 分类时测试失败。
- 清单可导出不含 PII 的审计摘要。
