# WI-S0-01-08 Account Data Rights Receipt 生命周期映射纠偏

- 日期：2026-07-30
- Work Item：`WI-S0-01-08`
- Authority：`ACCOUNT_LOCAL_STATE`
- 范围：Account Store Inventory 与 lifecycle module registry 的单项映射一致性。

## 修复内容

`S14.account-data-rights-receipt-cache` 已在生产运行时由
`LM-11-widget-and-temporary-exports` 的
`AccountDataRightsReceiptStore.teardownForAccountLifecycle` 清理，但其机器可读
lifecycle registry 遗漏了该 surface，导致 Slice 1D 总 gate 错报一项未覆盖。

本次将该 surface 映射到既有 LM-11。该模块在冷启动、账号切换、退出和暂停时
清理旧 lease 的 scoped receipt 与 legacy unscoped key；账号注销时 purge。没有新建
第二套 cleanup 路径，也不改变注销、草稿保留或远端删除语义。

## 验证

```text
Scripts/QA/product-v4/run-account-lifecycle-entrypoint-gate.sh
Scripts/QA/product-v4/account-data-rights-status-owner-scope-check.py
```

预期 lifecycle module registry 覆盖全部 inventory surfaces，`gaps=0`。

## 非声明

- 不关闭 `WI-S0-01-08` 的 G1/G4。
- 不声明真实设备账号切换、Provider 删除或远端数据清理完成。
- 不改变公开产品 UI。
