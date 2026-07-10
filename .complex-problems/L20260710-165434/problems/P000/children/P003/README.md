# iOS Keychain 消费与非真机 gate

## Problem

新增 iOS auth session 模型和 Keychain store，登录保存用户 token，请求分离 backend header 与 user bearer，401 时最多刷新并重试一次，退出登录撤销并清理；补静态 guard、模拟器 smoke 和 release gate。

## Success Criteria

token 不进入 UserDefaults；自动刷新不递归、不并发重复旋转；模拟器验证登录、授权请求、refresh 和 logout；iOS build 与 release regression 通过。
