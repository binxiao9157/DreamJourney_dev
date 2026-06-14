#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List

DEFAULT_ROOT = Path("docs/superpowers/evidence")
PRIVACY_BOUNDARY = "不提交原始照片、原始音频、信件正文、完整 transcript；后端样本只保留 metadata-only 脱敏响应。"


def write_if_missing(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(content, encoding="utf-8")


def overwrite(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


MODULES: List[Dict[str, object]] = [
    {
        "id": "phase1-memory-archive",
        "priority": "P0-1",
        "title": "记忆档案馆真实素材建库验收",
        "requiredFiles": [
            "screens/archive-list.png",
            "screens/knowledge-base-after-text.png",
            "screens/photo-analysis.png",
            "screens/voice-profile-status.png",
            "backend/archive-items-redacted.json",
            "logs/memory-archive-device.log",
        ],
        "readme": """# Phase 1 Memory Archive Evidence

Use this folder for P0-1 memory archive acceptance.

- archive screen screenshots
- knowledge base screenshots
- real photo analysis screenshots
- voice sample / voice profile screenshots
- redacted `/archive/items/{userId}` responses
""",
        "checklist": """# P0-1 记忆档案馆真实素材建库验收

隐私边界：{privacy_boundary}

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
""",
    },
    {
        "id": "phase1-digital-human-grounding",
        "priority": "P0-2",
        "title": "数字人对话记忆约束真机验收",
        "requiredFiles": [
            "recordings/grounded-dialog-3-5-rounds.mp4",
            "screens/known-fact-answer.png",
            "screens/unknown-fact-boundary.png",
            "screens/knowledge-base-after-dialog.png",
            "logs/dialog-memory-grounding.log",
            "diagnostics/digital_human_playback.log",
        ],
        "readme": """# Phase 1 Digital Human Grounding Evidence

Use this folder for true-device evidence from P0-2 digital human memory grounding acceptance:

- 3-5 round dialog recordings
- screenshots of known-fact and unknown-fact answers
- redacted device logs containing `DialogMemoryGrounding`, RAG, `assistant_final`, and `playback_finished`
- updated knowledge base screenshots after dialog end
""",
        "checklist": """# P0-2 数字人对话记忆约束真机验收

隐私边界：{privacy_boundary}

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
""",
    },
    {
        "id": "phase1-care-dashboard",
        "priority": "P1-1",
        "title": "长辈关怀看板跨设备验收",
        "requiredFiles": [
            "screens/device-a-invite.png",
            "screens/device-b-accept.png",
            "screens/device-b-care-dashboard.png",
            "screens/device-a-revoke.png",
            "backend/latest-redacted.json",
            "backend/history-redacted.json",
            "backend/revoked-403.txt",
        ],
        "readme": """# Phase 1 Care Dashboard Evidence

Use this folder for P1-1 cross-device family care dashboard acceptance:

- invitation / acceptance / revoke screenshots
- Device B care dashboard screenshots
- redacted latest/history care snapshot responses
- 403 response after permission revoke
""",
        "checklist": """# P1-1 长辈关怀看板跨设备验收

隐私边界：{privacy_boundary}

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
""",
    },
    {
        "id": "phase1-time-mailbox",
        "priority": "P1-2",
        "title": "时空信箱真实信件验收",
        "requiredFiles": [
            "screens/create-letter.png",
            "screens/delivery-notification.png",
            "screens/reader-boundary.png",
            "screens/cross-device-metadata-only.png",
            "backend/mailbox-letters-redacted.json",
        ],
        "readme": """# Phase 1 Time Mailbox Evidence

Use this folder for P1-2 real time-mailbox letter acceptance:

- delivery notification screenshots
- reader boundary screenshots
- metadata-only backend responses
- cross-device metadata restore screenshots
""",
        "checklist": """# P1-2 时空信箱真实信件验收

隐私边界：{privacy_boundary}

## 真机流程

- [ ] 先沉淀一条具体人物记忆。
- [ ] 创建给具体姓名的信件，隐私选择“可生成”或“亲友”。
- [ ] 当前 App 最短投递延迟按 5 分钟验收。
- [ ] 本机通知不暴露收件人和正文。
- [ ] 阅读页显示“原信仅本机显示”和“不是逝者真实回复”的边界。
- [ ] 后端 `/mailbox/letters/{{userId}}` 不含 `body`、`replyText`、`bodyPreview`，正文不出端。
- [ ] 换设备只恢复 metadata-only，不凭空出现正文。

## 证据文件

- `screens/create-letter.png`
- `screens/delivery-notification.png`
- `screens/reader-boundary.png`
- `screens/cross-device-metadata-only.png`
- `backend/mailbox-letters-redacted.json`
""",
    },
    {
        "id": "phase1-backend-smoke",
        "priority": "P2-1",
        "title": "线上后端 smoke 与安全配置验收",
        "requiredFiles": [
            "health.json",
            "runtime.json",
            "runtime-without-token.txt",
            "image-analysis-dry-run.json",
            "kb-snapshot-smoke.json",
            "authenticated-smoke.log",
        ],
        "readme": """# Phase 1 Backend Smoke Evidence

Use this folder for P2 backend smoke and deployment evidence:

- `/health` response
- `/config/runtime` response
- unauthorized response without backend token
- authenticated smoke responses
- Docker compose and deployment status snapshots
""",
        "checklist": """# P2-1 线上后端 Smoke 与安全配置验收

隐私边界：{privacy_boundary}

## 远端命令

```bash
export DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn
export DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>
export DREAMJOURNEY_BACKEND_REPO=${{DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}}
PYTHONPATH="$DREAMJOURNEY_BACKEND_REPO" STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py --remote \\
  | tee docs/superpowers/evidence/phase1-backend-smoke/authenticated-smoke.log
```

期望：

- `/health` 为 200。
- `/config/runtime` 不带 token 为 401。
- 带 `DREAMJOURNEY_BACKEND_API_TOKEN` 为 200。
- runtime、dryRun、snapshot 响应不泄露原始 key/token。
- 能力状态仅为 bool 或 configured/missing，不出现真实密钥值。

## 证据文件

- `health.json`
- `runtime.json`
- `runtime-without-token.txt`
- `image-analysis-dry-run.json`
- `kb-snapshot-smoke.json`
- `authenticated-smoke.log`
""",
    },
]


def format_checklist(template: str) -> str:
    return template.format(privacy_boundary=PRIVACY_BOUNDARY)


def module_manifest(module: Dict[str, object]) -> Dict[str, object]:
    return {
        "id": module["id"],
        "priority": module["priority"],
        "title": module["title"],
        "requiredFiles": module["requiredFiles"],
        "status": "pending_true_device_evidence",
    }


def write_module(root: Path, module: Dict[str, object]) -> None:
    module_dir = root / str(module["id"])
    module_dir.mkdir(parents=True, exist_ok=True)
    write_if_missing(module_dir / "README.md", str(module["readme"]))
    overwrite(module_dir / "acceptance_checklist.md", format_checklist(str(module["checklist"])))
    for relative in module["requiredFiles"]:
        (module_dir / str(relative)).parent.mkdir(parents=True, exist_ok=True)


def write_root_files(root: Path) -> None:
    manifest = {
        "app": "DreamJourney",
        "goal": "phase1_true_device_acceptance",
        "privacyBoundary": PRIVACY_BOUNDARY,
        "generatedBy": "Scripts/phase1_acceptance_evidence_scaffold.py",
        "modules": [module_manifest(module) for module in MODULES],
    }
    overwrite(
        root / "phase1_acceptance_manifest.json",
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    )

    lines = [
        "# DreamJourney Phase 1 True-Device Acceptance Checklist",
        "",
        f"隐私边界：{PRIVACY_BOUNDARY}",
        "",
        "## 模块",
        "",
    ]
    for module in MODULES:
        lines.append(f"- [ ] {module['priority']} {module['title']}：`{module['id']}/acceptance_checklist.md`")
    lines.extend(
        [
            "",
            "## 后端远端 Smoke",
            "",
            "```bash",
            "export DREAMJOURNEY_BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn",
            "export DREAMJOURNEY_BACKEND_API_TOKEN=<与服务器 BACKEND_API_TOKEN 相同的值>",
            "export DREAMJOURNEY_BACKEND_REPO=${DREAMJOURNEY_BACKEND_REPO:-$HOME/Documents/Codex/Video/DreamJourneyBackend}",
            "PYTHONPATH=\"$DREAMJOURNEY_BACKEND_REPO\" STORE_BACKEND=memory python3 Scripts/BackendAuthenticatedSmoke/main.py --remote",
            "```",
            "",
            "完成所有 P0/P1 真机证据后，再更新 `docs/superpowers/reports/2026-06-14-phase1-full-status-and-development-plan.md`。",
            "",
        ]
    )
    overwrite(root / "phase1_acceptance_checklist.md", "\n".join(lines))


def scaffold(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for module in MODULES:
        write_module(root, module)
    write_root_files(root)


def main() -> None:
    parser = argparse.ArgumentParser(description="Create Phase 1 true-device acceptance evidence scaffold.")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="Evidence root directory")
    args = parser.parse_args()
    scaffold(args.root)
    print(f"Phase 1 acceptance evidence scaffold ready: {args.root}")


if __name__ == "__main__":
    main()
