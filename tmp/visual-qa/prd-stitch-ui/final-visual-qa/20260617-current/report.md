# Final Visual QA Evidence Pack

Date: 2026-06-17

Stitch project: `projects/2650033127117292960`

Output directory:

```text
tmp/visual-qa/prd-stitch-ui/final-visual-qa/20260617-current/
```

## Screenshots

| File | App screen | Stitch reference | Status | Notes |
| --- | --- | --- | --- | --- |
| `01-login.jpg` | Login | `登录入口 - 往日与回响` | Pass with copy caveat | Light/cream login is present; not black. Visible copy still uses `寻梦环游` and `在时空中，留下你的身影`. |
| `02-echo.jpg` | `回响` | `时空对话 - 悬浮导航版` | Pass for MVP | Voice-first page, scenic background, quote bubble, floating tab bar. No visible `阳光模式` / `星辰模式` / `静默模式`. |
| `03-archive.jpg` | `记忆档案馆` | `记忆档案 - 悬浮导航版` | Pass for UIQA; release-like pass added | UIQA all-branch mode can expose extra entries. Release-like hidden-entry evidence is in `tmp/visual-qa/prd-stitch-ui/release-like-visual-qa/20260617-hidden-entries/`. |
| `04-profile.jpg` | `我的` | `长辈关怀 - 子女看板 (子页面逻辑)` | Needs convergence | Main visual tone matches the care/profile direction, but settings rows include placeholder/gated actions: family management, legal, account deletion. |

## Critical Invariants

- Login page is light/cream, not black.
- Bottom nav labels are `记忆档案`, `回响`, `我的`.
- No visible `往日记念` / `时光回响` product entries in the current app shell.
- `回响` primary input remains voice-first.
- Internal echo mode names are not visible on the `回响` page.
- Archive-to-echo core regression is covered separately by:

```bash
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

## Release-Like Follow-Up

Release-like visual evidence was added at:

```text
tmp/visual-qa/prd-stitch-ui/release-like-visual-qa/20260617-hidden-entries/
```

Without `DJEnableArchiveHiddenBranches`, the archive page exposes text/photo creation only. `时间胶囊` remains as the timeline section label; time-letter creation remains hidden.
