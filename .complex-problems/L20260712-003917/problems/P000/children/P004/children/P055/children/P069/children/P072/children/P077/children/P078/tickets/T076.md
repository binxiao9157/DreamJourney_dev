# 建立适用 Gate 解析约定并重生成矩阵

## Problem Definition

生成器以 Unicode `\b` 从 Work Item 的 `Verification` 与 `External gates` 提取 `G0-G4`，会漏掉中文紧邻 token；独立 checker 改用 ASCII 边界后虽然发现遗漏，却会把明确否定的 Gate 当成适用 Gate。矩阵 Gate 和 Ceiling 因而不能作为可靠执行约束。

## Proposed Solution

在生成器和独立 checker 中分别实现同一公开语义、不同代码实现的 `applicable gates` 解析：先识别 ASCII Gate token，再排除完整否定片段（至少覆盖 `无G2/G3/G4`、`无G3真实调用`、`G3不适用`、`不依赖G3`、`无需G4`），没有适用 token 时默认 `G0`。为正向中文紧邻、Gate 列表、否定列表和混合句建立自测。重新生成矩阵和 Ceiling，独立检查真实矩阵；随后重复生成并比较哈希，运行全部 Product V4 checks 和 diff gate。后续 Round 4E2 再把 Gate 迁入显式 typed registry，本票不扩展为 115 项元数据重写。

## Acceptance Criteria

- 生成器能识别中文紧邻 Gate，并不会把明确否定 Gate 写入矩阵。
- checker 不导入生成器，独立复算适用 Gate；原六类负向变体和新增 Gate 正/负语义自测全部通过。
- 115 个 Work Item 的 Gate 与 Ceiling 在真实矩阵中零差异。
- 生成器连续两次输出哈希一致，旧哈希被明确标记为已取代。
- 全部 Product V4 checks、Python syntax check 和 `git diff --check` 通过。

## Verification Plan

运行生成器/checker各自 Gate 单元自测；运行 checker `--self-test` 和真实矩阵；连续运行生成器并计算 SHA-256；运行 `Scripts/QA/product-v4` 下全部非生成器检查；运行 `git diff --check`。重点人工抽查 `WI-S1-03-01`（`无G2/G3/G4`）、`WI-MIG-01-05`（`无G3真实调用`/`G3不适用`）、`WI-S0-01-03`（`G2部署`）和包含 `G4产品` 的条目。

## Risks

- 自然语言否定规则仍可能出现新表达；Round 4E2 必须用显式 typed registry 消除长期启发式依赖。
- 生成器和 checker 若共享代码会掩盖共因错误，因此只能共享文字约定，不能互相 import。
- 重新计算 Ceiling 会改变大量矩阵行，但这属于纠错，不代表任何实现状态升级。

## Assumptions

- 当前 roadmap 中明确否定表达的有限集合可以完整枚举并由自测锁定。
- Gate/Ceiling 只描述适用验收门和无证据时的状态上限，不是实现完成声明。
