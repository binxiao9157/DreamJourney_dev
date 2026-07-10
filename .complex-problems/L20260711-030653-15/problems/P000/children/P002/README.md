# 后端 Persona Context Policy

## Problem

Context 当前只允许 personal self KB facts；缺少实体级 persona 过滤后，family facts 无法安全启用。

## Success Criteria

- personal/self 兼容缺少 metadata 的旧事实，但拒绝其他显式 persona。
- family 只允许 owner、family scope 和目标 digitalHumanId 全部匹配的事实。
- 负向测试覆盖 scope、digitalHumanId、owner 和 legacy family 越界。
