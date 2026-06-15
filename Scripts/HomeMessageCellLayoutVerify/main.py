#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
CELL = ROOT / "DreamJourney/Sources/Modules/Home/MessageCells.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def expect(condition: bool, message: str) -> None:
    if not condition:
        print(f"HomeMessageCellLayout verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = CELL.read_text()

message_cell_match = re.search(
    r"final class TGMessageCell: UITableViewCell \{(?P<body>[\s\S]*?)\n\}\n\n// MARK: - 照片卡片Cell",
    source,
)
expect(message_cell_match is not None, "TGMessageCell class body not found")
message_cell = message_cell_match.group("body")

expect(
    "override func layoutSubviews()" in message_cell
    and "bubbleView.frame =" in message_cell
    and "messageLabel.frame =" in message_cell,
    "TGMessageCell should remain a manual frame-layout cell",
)

expect(
    "translatesAutoresizingMaskIntoConstraints = false" not in message_cell,
    "TGMessageCell is manually framed and must not disable translatesAutoresizingMaskIntoConstraints",
)

expect(
    "HomeMessageCellLayoutVerify/main.py" in PHASE1.read_text(),
    "phase1 verification should include home message cell layout regression coverage",
)

print("HomeMessageCellLayout verification passed")
