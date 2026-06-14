# P1-1 长辈关怀看板跨设备验收

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 双设备流程

- [ ] A 设备创建亲友邀请。
- [ ] B 设备接受邀请。
- [ ] A 设备用“亲友”范围完成 3-5 轮真实对话。
- [ ] B 设备关怀看板只显示趋势、摘要、周报，无原始 transcript。
- [ ] A 设备撤回 B 权限。
- [ ] B 设备 latest/history 读取撤回后 403，App 显示权限已撤回或未生效。

## 证据文件

- `screens/device-a-invite.png`
- `screens/device-b-accept.png`
- `screens/device-b-care-dashboard.png`
- `screens/device-a-revoke.png`
- `backend/latest-redacted.json`
- `backend/history-redacted.json`
- `backend/revoked-403.txt`
