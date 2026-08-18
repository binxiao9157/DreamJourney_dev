# PC-A0 回滚说明

1. 后端可将 `PASSWORD_AUTHENTICATION_ENABLED=false`，只关闭密码能力；现有 OTP Challenge、Access/Refresh Session 和已登录用户不受影响。
2. Runtime 关闭后，iOS 根据 typed capability 隐藏密码模式及设置、修改、重置入口，不允许本地强行打开。
3. 若登录接口出现回归，优先 forward-fix；不得删除 `0094` 已创建的凭据、锁定和 action grant 表，也不得恢复旧明文/弱哈希逻辑。
4. 密码修改或重置已撤销的 token family 不得因回滚重新生效。
5. 真实短信 Provider 未就绪时，必须保持 `resetReady/setupReady/reauthReady=false`；测试白名单能力只能通过 `testRecoveryReady` 诊断，不能作为普通用户入口依据。
