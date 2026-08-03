# 独立复算矩阵并用负向变体证明失败能力

## Problem Definition

生成器已经能输出完整矩阵，但生成器自身的assert不能作为独立证据。需要另一个不导入生成器代码的checker，从权威文档和roadmap重新解析集合、关系与状态，并验证矩阵的正反向一致性。

## Proposed Solution

新增独立checker，分别解析FR/DR/finding/CR/package/WI六个矩阵section和五份权威源；比较精确集合、primary/reverse边、decision状态/关系、finding声明package下钻、package父子/CR、WI状态与gate ceiling。内置`--self-test`在内存中构造孤儿、反向边缺失、非法ID、finding边丢失、DR状态漂移和VERIFIED越权六类变体，要求全部失败。

## Acceptance Criteria

- checker不import生成器，能独立通过当前矩阵。
- 六类对象集合、FR primary/deferred与supporting反向、DR状态/关系、finding链、package/WI父子全部一致。
- 任何FR/WI `PROD_VERIFIED/VERIFIED`在无证据manifest时失败；open G2–G4不允许越过Ceiling。
- 至少六类negative fixture均返回明确错误码。
- 全量Product V4 checks、生成确定性和diff gate通过。

## Verification Plan

运行checker与`--self-test`；临时在内存修改矩阵行并检查错误类别；运行生成器两次、全部Product V4脚本和`git diff --check`；邀请独立agent只读复审checker盲点。

## Risks

- checker如果复制生成器常量会形成共因错误，必须从权威源计算primary之外的关系，并对primary做存在/反向验证。
- Markdown解析过宽会误把其他章节ID计入，应按section边界读取表。

## Assumptions

- primary FR映射是明确人工架构关系，可由矩阵读取，但目标存在、反向FR和唯一性必须独立验证。
- 状态证据manifest尚未实现，因此当前任何VERIFIED/PROD_VERIFIED都是越权。
