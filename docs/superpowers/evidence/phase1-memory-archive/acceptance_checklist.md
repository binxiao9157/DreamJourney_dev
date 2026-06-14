# P0-1 记忆档案馆真实素材建库验收

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 真机素材

- [ ] 首页隐私范围选择“可生成”。
- [ ] 新增文字素材：

```text
我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。林桂芳性格慢，常说慢慢来，日子要一张一张照好。
```

- [ ] 结构化知识库出现陈建国、林桂芳、绍兴越城区仓桥直街、杭州西湖边小照相馆。
- [ ] 真实照片走 `DreamJourneyBackendBaseURL` 图片分析代理；失败只显示可重试，不允许 mock 成功。
- [ ] 真实语音素材完成转写/摘要/人物绑定。
- [ ] 同一具体人物 3 段语音进入 `readyForTraining` 或友好失败状态。
- [ ] `backend/archive-items-redacted.json` 不含 `localPath`、`voiceProfileId`、图片/音频本体。

## 证据文件

- `screens/archive-list.png`
- `screens/knowledge-base-after-text.png`
- `screens/photo-analysis.png`
- `screens/voice-profile-status.png`
- `backend/archive-items-redacted.json`
- `logs/memory-archive-device.log`
