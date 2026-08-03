# Round 3A2a：后端现状与部署证据审计

## Problem

目标架构必须建立在当前 FastAPI、PostgresStore、models、provider adapter、worker/smoke 和部署脚本的真实职责上。若不先形成可复核现状清单，模块边界容易成为与代码脱节的概念包装。

## Success Criteria

- 记录当前 API/worker/Postgres/object/provider 的实际部署与调用关系。
- 至少 15 个当前 route/service/store/model/provider/script 组件有文件证据、现状职责和主要耦合风险。
- 标记 Owner 核心、Voice/Digital Human Beta、Family/Care/Time Letter Future 的当前依赖关系。
- 识别跨模块直接写入、JSONB 聚合、owner/tenant scope、异步幂等和 provider credential 的关键风险。
- 该问题属于 T020，因为它为后端目标边界提供代码和部署证据。
