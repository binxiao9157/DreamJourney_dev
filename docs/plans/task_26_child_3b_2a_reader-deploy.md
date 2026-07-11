# Reader-first 后端部署与健康验证

## Problem

线上仍运行旧后端，必须先部署支持 legacy/full 与 compact 双读的 `4c0538b`，验证服务和既有业务不回退，再允许数据库维护。

## Success Criteria

- 服务器仓库/容器运行提交 `4c0538b`。
- 重建重启成功，health 200 且 store=postgres。
- Runtime config 和基础登录/知识 smoke 正常。
- 未执行 receipt apply。
- 部署日志不输出私密环境变量。
