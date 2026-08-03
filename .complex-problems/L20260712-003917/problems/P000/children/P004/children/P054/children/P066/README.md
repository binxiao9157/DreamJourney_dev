# Round 4D2：Voice/DH Governance 工作项

## Problem

现有声音复刻、TTS、Tencent数智人和PCM audio-drive已有大量代码与真机调试，但授权、purpose、样本/生成音频、Provider receipt、质量、删除/退出和成本仍未形成一条可公开治理链，配置或ready状态不能代替真实能力。

## Success Criteria

- 为`WP-V0-01`建立原子工作项，覆盖consent/purpose、voice sample/profile、training/TTS/generated audio、DH asset/session、credential broker、provider receipt、quality、device、delete/exit/cost。
- 默认音色不冒充复刻、Provider配置不冒充ready、local lease不冒充provider session；Voice/DH分别可关闭。
- 真实高敏数据禁止dual-send，region/retention/delete/exit无证据时保持`EXTERNAL_BLOCKED`。
- iOS只持runtime短期credential，不持长期key；同一时刻一个audio owner/session，Owner text独立。
