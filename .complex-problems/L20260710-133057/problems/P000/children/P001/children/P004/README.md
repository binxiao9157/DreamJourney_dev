# 补生命周期协调器纯状态回归

## Problem

生命周期协调器已经接入业务路径，但缺少独立可执行的状态断言，无法证明旧 token 在 context、交互和页面代际变化后一定失效。

## Success Criteria

- 新增可直接编译执行的协调器状态检查。
- 覆盖 context 切换推进 session generation。
- 覆盖停止/打断只推进 interaction generation，并保持 session token 可用。
- 覆盖页面级失效使旧 session 与 interaction token 均不可用。
- 检查执行通过。
