# Release-Like Hidden Entries QA

Date: 2026-06-17

Build:

```text
tmp/visual-qa/prd-stitch-ui/DerivedDataReleaseLikeHiddenEntries
```

Launch arguments:

```text
DJSeedPendingArchiveAnalysis
```

Not passed:

```text
DJEnableArchiveHiddenBranches
```

## Evidence

| File | Screen | Result |
| --- | --- | --- |
| `01-archive-hidden-entries.jpg` | `记忆档案馆` | Pass: only `相册影像` top card is visible; `语音档案` and `人格设定` are not exposed. CTA subtitle is `文字、图片`. |
| `02-create-sheet-hidden-entries.jpg` | Create sheet | Pass: only `添加文字描述` and `选择照片` are visible. `录入语音` and `录入时间信件` are hidden. |

## Notes

- `时间胶囊` remains as the archive timeline section label. The hidden feature being checked here is the time-letter creation branch, not the timeline label.
- QA-only all-branch coverage can still be enabled explicitly with `DJEnableArchiveHiddenBranches`.
