# 修复 Gate 语义解析并重新生成可验证追踪矩阵

## Problem

矩阵生成器会漏掉中文紧邻 Gate，而独立检查器会把否定语境中的 Gate 当作适用门禁。需要分别实现可审查的适用 Gate 解析规则，重新生成矩阵和 Ceiling，并让独立 checker、负向自测、确定性和全量 Product V4 检查共同通过。

## Success Criteria

- 生成器正确识别 `G4产品`、`G2真实` 等中文紧邻 Gate，并排除 `无G2/G3/G4`、`G3不适用`、`不依赖G3`、`无需G4` 等明确否定语境。
- 独立 checker 不导入生成器，使用独立实现复算同一适用 Gate 语义，并增加中文紧邻与否定语境自测。
- 重新生成 115 个 Work Item 的 Gate 与 Ceiling 后，独立 checker 对真实矩阵零错误。
- 生成器重复运行内容哈希一致；全部 Product V4 checks 与 `git diff --check` 通过。
- 结果记录新矩阵哈希，并明确旧快照哈希已经被修复版本取代。
