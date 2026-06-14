#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def fail(message: str) -> None:
    print(f"CareDashboardNoDuplicateMetrics verification failed: {message}", file=sys.stderr)
    sys.exit(1)


vc_text = VC.read_text(encoding="utf-8")
phase1_text = PHASE1.read_text(encoding="utf-8")

render_start = vc_text.find("private func render()")
render_end = vc_text.find("private func canShareCareReport", render_start)
if render_start == -1 or render_end == -1:
    fail("could not locate CareDashboardViewController.render()")

render_body = vc_text[render_start:render_end]
metric_grid_count = render_body.count("makeMetricGrid(metrics)")
if metric_grid_count != 1:
    fail(f"render() should add the metrics grid once, found {metric_grid_count}")

if "CareDashboardNoDuplicateMetricsVerify/main.py" not in phase1_text:
    fail("phase1 verification should include duplicate metrics coverage")

print("CareDashboardNoDuplicateMetrics verification passed")
