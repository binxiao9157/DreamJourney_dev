# PRD Coverage Matrix

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Head at creation: `790f029 docs: add prd ui continuation plan`

## Source of truth

- Product: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual: current Stitch canvas and `htmlCode`.
- MCP screenshots are auxiliary, not final visual authority.
- Code: current UIKit implementation in `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`.

## Coverage Table

| PRD requirement | Current status | Public? | Evidence | Next action |
| --- | --- | --- | --- | --- |
| 回响语音输入 | implemented | yes | `EchoViewController`, archive-to-echo smoke | true-device microphone acceptance |
| 2-3轮后等待回信 | partially implemented | yes | `EchoViewModel` | tune delay policy after product review |
| 档案照片 | implemented | yes | Archive photo entry smoke | true-device photo acceptance |
| 档案视频 | not implemented | no | release matrix | define video upload scope |
| 档案录音 | hidden candidate | no | archive media smoke | true-device audio acceptance |
| 档案文字描述 | implemented | yes | archive smoke | maintain |
| 时间信件 | hidden candidate | no | archive media smoke | delivery policy |
| 个人资料管理 | partially implemented | yes | `ProfileSettingsViewController` | avatar/password scope |
| 心境追踪 | implemented fallback | yes | Profile care checks | lifecycle policy |
| 家人管理 | hidden candidate | no | family persona smoke | product exposure decision |
| 法律法规 | implemented | yes | `ProfileLegalViewController` | legal review |
| 账号退出 | implemented | yes | `ProfileViewController` | maintain |
| 账号注销 | hidden blocked shell | no | safety check | compliance/backend contract |
| 长辈关怀 | implemented aggregate | yes | elder dashboard check | real backend acceptance |
| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |

## External Acceptance Boundary

- 本地 FastAPI 后端 smoke：accepted
- release-like FastAPI/Postgres 后端验收：accepted
- 线上/公网后端验收：accepted for simulator release-like scope
- 真机验收：not accepted
- 语音 SDK 生产质量验收：not accepted
- App Store / TestFlight 签名链路验收：not accepted

These are not product failures. They are external acceptance gates that require user-provided environment or physical-device operation.

## Release Gating Policy

No hidden PRD feature is public by default.

Default public surface remains:

- `记忆档案`
- `回响`
- `我的`
- text/photo archive creation
- voice-first Echo
- profile settings
- legal center
- logout
- aggregate `心境追踪` / `长辈关怀`

Hidden or blocked by default:

- archive audio upload
- time letters
- video upload
- persona settings
- family management public release
- account deletion execution
- doctor contact / intervention execution
- sunlight/star/silent lifecycle transition controls
- digital inheritance lifecycle

## Blockers

- release-like FastAPI/Postgres and simulator remote-backend acceptance passed with `20260618-deployed-postgres-acceptance-after-deploy`.
- 需要部署后端最新代码并 rerun `run-release-like-backend-acceptance.sh` after future backend changes.
- 需要真机、签名和设备操作 before true-device acceptance can run.
- 需要产品/合规确认 before account deletion, doctor contact, intervention, and inheritance flows can execute.
- 需要明确发布范围 before audio, time-letter, video, and public family management can move from hidden candidate to public feature.

## Current Interpretation

The current app is a simulator-validated MVP candidate for the core loop:

```text
记忆档案 -> 回响 -> 心境追踪 / 关怀
```

It is not yet a fully accepted real-device release candidate.

The safest next implementation work is still:

1. refresh final Stitch visual QA,
2. add one-command release regression,
3. harden hidden candidates one feature at a time,
4. run true-device acceptance when signing and device conditions exist.
