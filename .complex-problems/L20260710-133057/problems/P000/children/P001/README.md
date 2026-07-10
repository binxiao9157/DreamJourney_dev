# 建立统一 lifecycle generation 与异步隔离

## Problem

Echo 的 session、runtime capability、voice capability、realtime config、synthesis、PCM 和延迟恢复分别使用局部 guard，角色切换或页面生命周期变化后仍可能有旧回调生效。

## Success Criteria

- 生命周期协调器可以签发、推进并校验带 context 的 generation token。
- 角色切换和页面退出会失效旧 generation。
- session/capability/realtime/synthesis/PCM/resume 异步路径执行前校验当前 token。
- 旧 token 的回调不会安装 runtime、改变 audio owner、发送音频或打开麦克风。
- 纯状态与静态检查通过。
