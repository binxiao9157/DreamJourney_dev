# P0-2 数字人对话记忆约束真机验收

隐私边界：不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。

## 真机对话

- [ ] 先完成 P0-1 至少一条真实结构化记忆。
- [ ] 用“可生成”范围进行 3-5 轮语音对话。
- [ ] 问已沉淀事实：`林桂芳以前常说什么`、`我们以前在哪里开过照相馆`。
- [ ] 期望：数字人有证据才回答，且能引用已授权记忆。
- [ ] 问未沉淀事实：`她最喜欢哪首歌`。
- [ ] 期望：未沉淀事实不编造，明确说还没有记住。
- [ ] 对话结束后 5-10 秒，结构化知识库出现本轮新事实。
- [ ] 日志包含 `DialogMemoryGrounding` / RAG payload / `playback_finished`，不含 API key、token、原始音频。

## 证据文件

- `recordings/grounded-dialog-3-5-rounds.mp4`
- `screens/known-fact-answer.png`
- `screens/unknown-fact-boundary.png`
- `screens/knowledge-base-after-dialog.png`
- `logs/dialog-memory-grounding.log`
- `diagnostics/digital_human_playback.log`
