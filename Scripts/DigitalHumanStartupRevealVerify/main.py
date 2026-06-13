#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
vc = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
mini_live = ROOT / "DreamJourney/Resources/web/MiniLive2.js"
mini_mate = ROOT / "DreamJourney/Resources/web/MiniMateLoader.js"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

vc_text = vc.read_text(encoding="utf-8")
mini_live_text = mini_live.read_text(encoding="utf-8")
mini_mate_text = mini_mate.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

missing = []
required_vc_fragments = [
    "private var didRevealInitialAvatar = false",
    "private var initialAvatarRevealFallbackWorkItem",
    "webView.alpha = 0",
    "scheduleInitialAvatarRevealFallback()",
    "revealInitialAvatarIfNeeded(reason:",
    "avatar_video_surface_ready",
    "avatar_startup_reveal",
    "avatar_startup_waiting_for_video",
    'body[data-video-ready="true"] #canvas_video',
    'if type == "avatar_video_surface_ready" {',
]

for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc.name}: missing {fragment!r}")

if "document.getElementById('screen2').style.display = 'block';" in mini_mate_text:
    missing.append(f"{mini_mate.name}: should not force screen2 visible before first frame")
if "#screen2 {\n      display: block;" in vc_text:
    missing.append(f"{vc.name}: screen2 should stay hidden until avatar video ready")
if 'type == "avatar_first_frame_drawn" || type == "avatar_video_surface_ready"' in vc_text:
    missing.append(f"{vc.name}: should not reveal on avatar_first_frame_drawn before DOM video-ready state")
if 'revealInitialAvatarIfNeeded(reason: "timeout")' in vc_text:
    missing.append(f"{vc.name}: timeout fallback should not reveal the loading shell before real avatar video is ready")
if "avatar_first_frame_drawn" not in mini_live_text:
    missing.append(f"{mini_live.name}: missing first-frame diagnostic event")
if "minimate_new_video_done" not in mini_mate_text or "first frame will reveal screen2" not in mini_mate_text:
    missing.append(f"{mini_mate.name}: missing first-frame reveal note")
if "DigitalHumanStartupRevealVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing DigitalHumanStartupRevealVerify/main.py")

if missing:
    raise SystemExit("\n".join(missing))

print("DigitalHumanStartupReveal verification passed")
