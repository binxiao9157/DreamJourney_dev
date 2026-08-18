# PC-A2 回滚说明

1. migration `0096` 为 additive，不执行生产 down migration；异常时采用 forward-fix。
2. 可先停止 Candidate extraction 和 Memory projection Worker，阻止新 V2 写入与索引重建。
3. 已激活的 MemoryVersion 是不可变证据，不得降写、删除或自动改造成 V1。
4. V1 读取保持兼容；旧代码可忽略新增 SearchDocument schema 列与索引。
5. 未知 schema 保持 quarantine，任何回滚不得改成容错放行。
6. PC-A3 完成前保持 Family/Visitor 私人 V2 facets 默认不可见。
