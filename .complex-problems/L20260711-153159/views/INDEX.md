# Complex Problem Ledger

Ledger: L20260711-153159
Schema: v6
Root: P000 - Task 22：P0 家庭关系授权与知识候选隔离
Status: done
Updated: 2026-07-11T09:43:27+00:00

## Problem Tree
- [done] P000: Task 22：P0 家庭关系授权与知识候选隔离
  - [done] P001: 建立默认拒绝的家庭关系 authority 模型
  - [done] P002: 隔离 KBPerson 候选并绑定家庭仓库账号生命周期
  - [done] P003: 在 Echo 与持久化数字人上下文前复核家庭授权
  - [done] P004: 阻断未授权家庭知识同步与 legacy 整库导入
  - [done] P005: 将家庭授权边界纳入发布回归并收口文档
    - [done] P006: 收紧运行期家庭授权新鲜度与异步快照
      - [done] P007: 家庭授权刷新状态与前台同步顺序
      - [done] P008: Extraction 与 Governance 不可变授权快照
        - [done] P010: 对齐既有知识发布门与不可变授权快照合同
      - [done] P009: 家庭授权撤销后的 Echo Context 主动回退
      - [done] P011: 消除家庭刷新与治理失效的并发排序窗口
        - [done] P012: 同账号家庭刷新响应代次隔离
        - [done] P013: Coordinator 授权失效线性化
      - [done] P014: 对齐统一知识管线发布门与家庭授权合同
    - [done] P015: 收口 Task 22 最终实现与回归文档

## Active

## Blocked

## Done
- [x] P000: Task 22：P0 家庭关系授权与知识候选隔离
- [x] P001: 建立默认拒绝的家庭关系 authority 模型
- [x] P002: 隔离 KBPerson 候选并绑定家庭仓库账号生命周期
- [x] P003: 在 Echo 与持久化数字人上下文前复核家庭授权
- [x] P004: 阻断未授权家庭知识同步与 legacy 整库导入
- [x] P005: 将家庭授权边界纳入发布回归并收口文档
- [x] P006: 收紧运行期家庭授权新鲜度与异步快照
- [x] P007: 家庭授权刷新状态与前台同步顺序
- [x] P008: Extraction 与 Governance 不可变授权快照
- [x] P009: 家庭授权撤销后的 Echo Context 主动回退
- [x] P010: 对齐既有知识发布门与不可变授权快照合同
- [x] P011: 消除家庭刷新与治理失效的并发排序窗口
- [x] P012: 同账号家庭刷新响应代次隔离
- [x] P013: Coordinator 授权失效线性化
- [x] P014: 对齐统一知识管线发布门与家庭授权合同
- [x] P015: 收口 Task 22 最终实现与回归文档

## Tickets
- [done] T000: 实施家庭授权与知识候选隔离的 P0 闭环 -> P000 (split)
- [done] T001: 用显式 owner/source/status 决定家庭关系权限 -> P001 (one_go)
- [done] T002: 将 FamilyRepository 改为账号绑定的后端关系仓库 -> P002 (one_go)
- [done] T003: 让持久化角色与 Echo Context 使用 accepted family preflight -> P003 (one_go)
- [done] T004: 用 owner/persona scope 守住知识同步并关闭未签名整库分享 -> P004 (one_go)
- [done] T005: 将家庭知识授权边界设为默认发布门 -> P005 (one_go)
- [done] T006: 运行期家庭授权刷新与异步 identity generation -> P006 (split)
- [done] T007: 引入 owner-bound 家庭授权刷新状态并串联 foreground -> P007 (one_go)
- [done] T008: 用 generation token 固化知识提取与治理授权 -> P008 (one_go)
- [done] T009: 更新旧发布门以验证不可变授权快照 -> P010 (one_go)
- [done] T010: 家庭授权撤销时主动回退本人 Echo Context -> P009 (one_go)
- [done] T011: 用 refresh token 与 authorization epoch 封闭并发失效窗口 -> P011 (split)
- [done] T012: 用 freshness generation 拒绝旧家庭响应 -> P012 (one_go)
- [done] T013: 用 authorization epoch 线性化 coordinator 失效 -> P013 (one_go)
- [done] T014: 更新统一知识管线静态发布合同 -> P014 (one_go)
- [done] T015: 更新 Task 22 最终状态与验收证据 -> P015 (one_go)

## Latest Checks
- [success] C011: P012 R010 满足 P012：最新 refresh 是唯一能提交 authority 的请求，旧成功、旧失败和重复 callback 都因 refresh generation 不匹配而拒绝。
- [success] C012: P013 R011 满足 P013；独立复核确认角色/家庭失效会先轮换 epoch，再同步更新 queue generation，旧 callback 无法通过写入 guard，且未发现新阻断问题。
- [success] C013: P011 R012 满足 P011：两个独立并发根因均有运行时修复、模型/静态证据和独立复核，未发现剩余阻断。
- [not_success] C014: P006 R009/R012 已关闭运行期与并发问题，但全量 release regression 被过期的 `knowledge-pipeline-check` 阻断，当前还不能判定 P006 成功。
- [success] C015: P014 R013 满足 P014：只替换了被 Task 22 淘汰的旧断言，完整发布回归和两种非真机构建通过。
- [success] C016: P006 R009、R012、R013 共同满足 P006：前台刷新、异步快照、Echo 回退和两个并发排序缺口均已关闭，完整非真机发布回归通过。
- [not_success] C017: P005 R004/R009/R012/R013 已证明代码与 full regression 成功，但 canonical/status 文档仍引用 final5，未记录运行期新鲜度、不可变快照、主动回退和并发修复，当前不能判定 P005 完成。
- [success] C018: P015 R014 满足 P015。状态文档已准确记录 Task 22 的实现边界、运行期授权合同、最终回归证据和后续缺口；覆盖矩阵保留了既有 family/voice 证据，没有用删除断言的方式通过门禁。
- [success] C019: P005 R004、R009、R012、R013、R014 及其已验收子问题共同满足 P005。家庭授权边界已进入默认 release regression 和 release QA package，运行期新鲜度、异步快照、主动 Echo 回退与 coordinator epoch 均有自动化证据，最终状态文档与覆盖矩阵已同步。
- [success] C020: P000 R015 与全部已验收子问题证明 P000 成功完成。当前公开业务只信任当前 owner 的后端 accepted family 关系；候选、legacy、错误 owner、撤销关系和迟到异步工作均不能进入家庭 Echo 或远端知识同步。实现、发布门、非真机构建和状态文档形成了闭环证据。
