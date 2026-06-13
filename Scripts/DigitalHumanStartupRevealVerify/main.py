#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
vc = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
mini_live = ROOT / "DreamJourney/Resources/web/MiniLive2.js"
mini_mate = ROOT / "DreamJourney/Resources/web/MiniMateLoader.js"
poster = ROOT / "DreamJourney/Resources/web/avatar_poster.png"
xcodeproj = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

vc_text = vc.read_text(encoding="utf-8")
mini_live_text = mini_live.read_text(encoding="utf-8")
mini_mate_text = mini_mate.read_text(encoding="utf-8")
xcodeproj_text = xcodeproj.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

missing = []
required_vc_fragments = [
    "private var didRevealInitialAvatar = false",
    "private var initialAvatarRevealFallbackWorkItem",
    "private let startupPosterImageView",
    'UIImage(named: "avatar_poster")',
    "addSubview(startupPosterImageView)",
    "webView.alpha = 1",
    "startupPosterImageView.alpha = 0",
    "scheduleInitialAvatarRevealFallback()",
    "revealInitialAvatarIfNeeded(reason:",
    "avatar_video_surface_ready",
    "avatar_startup_reveal",
    "avatar_startup_poster_visible",
    "avatar_startup_waiting_for_video",
    'body[data-video-ready="true"] #canvas_video',
    'body[data-video-ready="true"] #avatarPoster',
    'body[data-video-ready="true"] #loadingSpinner',
    'body[data-video-ready="true"] #startMessage',
    '<img id="avatarPoster" src="avatar_poster.png"',
    'if type == "avatar_video_surface_ready" {',
]

for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc.name}: missing {fragment!r}")

if not poster.exists() or poster.stat().st_size <= 0:
    missing.append(f"{poster.name}: missing transparent startup poster")
if "avatar_poster.png in Resources" not in xcodeproj_text:
    missing.append(f"{xcodeproj.name}: missing avatar_poster.png resource entry")
if "webView.alpha = 0" in vc_text:
    missing.append(f"{vc.name}: webView should be visible immediately with the stable poster, not blank until live canvas")
if "startMessage.textContent = '真人数字人已就绪';" in vc_text:
    missing.append(f"{vc.name}: should not flash ready text during avatar startup reveal")
if not re.search(r"#loadingSpinner\s*\{[^}]*display:\s*none;", vc_text, re.S):
    missing.append(f"{vc.name}: startup spinner should be hidden while the poster is visible")
if not re.search(r"#startMessage\s*\{[^}]*display:\s*none;", vc_text, re.S):
    missing.append(f"{vc.name}: startup loading text should be hidden while the poster is visible")
if re.search(r"<div id=\"screen2\">\s*<video[^>]*>\s*</video>\s*<img id=\"avatarPoster\"", vc_text, re.S):
    missing.append(f"{vc.name}: avatar poster must sit outside initially hidden screen2")
if "document.getElementById('screen2').style.display = 'block';" in mini_mate_text:
    missing.append(f"{mini_mate.name}: should not force screen2 visible before first frame")
if "spinner.style.display = 'block';" in mini_mate_text:
    missing.append(f"{mini_mate.name}: startup spinner should stay hidden behind the poster")
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
