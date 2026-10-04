# Echo publication discovery refresh

A visible Echo page could lose its automatic publication discovery wake-up when account readiness or in-flight disk reads caused an early return. Keep one foreground discovery timer before those guards, and restart observation after policy refresh. Preserve account isolation, read coalescing and existing save/publish behavior.

Validation on the identical source fingerprint:

- Same assertions: 2 pre-fix failures, 2 post-fix passes.
- iOS regression: 728 passed, 0 failed, 4 independent integration entries skipped; generic device build passed.
- Physical short scenes: capture, candidate publication, add-only confirmation and cold formal readback passed.
- Physical ten-minute scene: 22 user turns / 44 messages persisted; 2 themes with 29 facts published. Immediate completion text observed; user confirmed completion text after normal cold restart without requested notification navigation. Exact refresh latency was not measured.

Full long-scene acceptance remains incomplete: an audio scheduler gap caused the test to invoke stop after farewell; 4 facts were omitted; confirmation was blocked because one proposal disputed existing formal memory. Do not label those items as passed or change historical failure records.

Design, detailed evidence summaries and issue-register snapshot: `binxiao9157/DreamJourneyBackend`, `docs/02-问题修复/2026-10-04-回响状态自动刷新/README.md`. No backend product changes in this repair.
