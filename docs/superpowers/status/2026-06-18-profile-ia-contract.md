# Profile IA Contract

Date: 2026-06-18

Project: `projects/2650033127117292960`

## Confirmed Decision

The app keeps the three-tab MVP shell:

- `记忆档案`
- `回响`
- `我的`

`我的` remains the third public tab. Do not rename the tab to `长辈关怀`.

`我的` is the container for:

- user identity/persona summary;
- `心境追踪`;
- `长辈关怀` aggregate card or child dashboard entry;
- `个人资料设置`;
- `法律法规`;
- `退出登录`;
- hidden QA-only entries such as `家人管理`, `立即通话`, and `注销账户`.

## Public Release Boundary

- Public by default: identity/persona card, mood/care summary, profile settings, legal center, logout.
- Public only when existing release gates allow it: aggregate care dashboard.
- Hidden unless feature flags are enabled: family management, doctor contact/care escalation, account deletion, persona/lifecycle management.

## Stitch Evidence Rules

- Current Stitch canvas + downloaded `htmlCode` are the visual authority.
- MCP screenshot and `list_screens` metadata are auxiliary only.
- Multiple `时空对话` records in MCP are candidate/variant evidence, not automatic targets.
- A profile-like screen title containing `长辈关怀` does not override the tab label when the canvas/instance/product decision says `我的`.

## Stitch Source Snapshot

Observed through Stitch MCP on 2026-06-18:

| Area | Stitch title or instance label | Screen ID | Contract interpretation |
| --- | --- | --- | --- |
| Login | `登录入口 - 往日与回响` | `3fcfe3aa2489492d82f56bd7efd55b11` | Current login visual source. |
| Archive | `记忆档案 - 悬浮导航版` | `6c38acaae2ce4d579331480ab678ed64` | Current archive visual source. |
| Echo candidate | `时空对话 - 活力少年版` | `3a713e9254f742fe8b6df81d9e400e9f` | Candidate only until explicitly selected. |
| Echo candidate | `时空对话 - 沉浸阅读版` | `8f0966443829472fa16ed5cd974b7fdd` | Candidate only until explicitly selected. |
| Echo candidate | `时空对话 - 温馨家中版` | `f1d7279042ed4fd3a1d13d918c552f7f` | Candidate only until explicitly selected. |
| Care child page | `长辈关怀 - 子女看板 (子页面逻辑)` | `22c439c698074c468b4b2f75d100148e` | Content under `我的`, not a tab replacement. |
| Profile instance | `我的 - 悬浮导航版` | `174fe3acf33443ee9229b4230b36c6b7` | Confirms the third tab label remains `我的`; source title metadata is auxiliary. |

## Implementation Implications

- Keep `TabCoordinator` and bottom navigation label as `我的`.
- Keep the Profile module as the owner of account/settings/legal/care entry composition.
- Add care growth as a Profile child page or section under `我的`; do not add a fourth tab or rename the third tab.
- Keep hidden Profile/Care branches behind existing feature flags and QA launch arguments.
- If a future Stitch update changes this IA, require a new explicit product decision before code changes.

## Required Regression

Run the final visual QA guard after Stitch UI, Profile/Care, or tab navigation changes:

```bash
swift Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

The guard must confirm this contract exists before release handoff.
