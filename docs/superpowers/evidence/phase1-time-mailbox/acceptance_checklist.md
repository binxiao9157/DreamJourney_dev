# P1-2 时空信箱真实信件验收

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 真机流程

- [ ] 先沉淀一条具体人物记忆。
- [ ] 创建给具体姓名的信件，隐私选择“可生成”或“亲友”。
- [ ] 当前 App 最短投递延迟按 5 分钟验收。
- [ ] 本机通知不暴露收件人和正文。
- [ ] 阅读页显示“原信仅本机显示”和“不是逝者真实回复”的边界。
- [ ] 后端 `/mailbox/letters/{userId}` 不含 `body`、`replyText`、`bodyPreview`，正文不出端。
- [ ] 换设备只恢复 metadata-only，不凭空出现正文。

## 证据文件

- `screens/create-letter.png`
- `screens/delivery-notification.png`
- `screens/reader-boundary.png`
- `screens/cross-device-metadata-only.png`
- `backend/mailbox-letters-redacted.json`
