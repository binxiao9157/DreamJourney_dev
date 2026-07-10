# Principal 解析与 ownership shadow

## Problem

扩展鉴权中间件，使 legacy backend token 和 user access bearer 可并存；解析当前 user principal，提取 actor userId 声明，在 shadow 模式记录匹配/不匹配并返回安全 QA header，不阻断现有业务。

## Success Criteria

legacy 请求继续成功；有效/无效/撤销 token 行为明确；mismatch 在 shadow 下成功并可观察，在测试 enforce 模式下可拒绝；日志不输出 token 或原始手机号。
