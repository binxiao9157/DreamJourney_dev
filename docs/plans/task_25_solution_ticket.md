# 实现 Echo 诊断数据账号级隐私生命周期

## Problem Definition

四类 Echo QA/诊断 store 使用固定全局 `UserDefaults` key，读取和导出不要求 owner；UserManager 登出未清理。账号切换后可能读取上一账号 trace，且旧异步回调可能在清理后重新写入。

## Proposed Solution

建立线程安全 active-owner scope 和不可逆 owner digest storage key。四类 store 的 record/read/export 都绑定 owner并验证当前 scope；UserManager 在冷启动、登录、切换、登出时以同一串行事务切换账号、知识库和通知。数字人 session、语音合成摘要及 evidence package 带显式 owner，异步回调使用请求发起时 owner。QA 导出落在 owner digest 目录并在切换/登出时清理。旧全局 key 直接清除，不跨账号迁移。

## Acceptance Criteria

- 四类 store 全部账号隔离且 key 不包含原始 user ID。
- A/B 切换、登出、冷启动、旧 owner 写入和 legacy key 清理均有测试。
- 导出只包含当前账号数据。
- 账号切换清除旧 runtime/session/voice 页面缓存和临时导出文件。
- 现有 Echo QA trace/evidence 能力不回归。
- release regression 与两个非真机构建通过。

## Verification Plan

先新增独立 Swift model smoke 和 static guard，再修改 stores/UserManager/Echo call sites；运行 Echo trace/evidence checks、release regression、Simulator/generic iPhoneOS build 与 diff check。

## Risks

- QA launch harness 使用固定 fake user，需要显式激活测试 scope 后恢复。
- UIQA 临时账号在函数返回时会触发清理，测试 harness 需先复制纯 mock 导出到 Documents 再交给外部脚本读取。

## Assumptions

- 现有 Echo lifecycle token 已阻断被销毁页面的旧 callback。
- QA trace 是可清理诊断数据，不要求从旧全局 key 迁移。
