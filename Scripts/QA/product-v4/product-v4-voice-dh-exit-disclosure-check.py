#!/usr/bin/env python3
"""Guard honest Voice/Digital Human disable and delete disclosure copy.

The current backend only records local profile lifecycle state.  Until an exit
DAG and Provider receipt exist, iOS must not say that third-party samples or
assets were physically deleted.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PROFILE_SHELL = ROOT / "DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift"
BACKEND_MAIN = ROOT.parent / "DreamJourneyBackend/app/main.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path}")
    return path.read_text(encoding="utf-8")


def constant_body(source: str, name: str) -> str:
    match = re.search(rf"{name} = \(\n(?P<body>.*?)\n\)", source, re.DOTALL)
    require(match is not None, f"missing contract constant: {name}")
    return match.group("body")


def main() -> None:
    shell = read(PROFILE_SHELL)
    voice_service = read(ROOT / "DreamJourney/Sources/Memoir/VoiceCloneService.swift")
    backend = read(BACKEND_MAIN)

    required_shell_copy = (
        "删除会立即停止该音色用于回响，并更新本地记录。当前未接入第三方服务清理回执，无法确认第三方数据是否已删除。此操作不可恢复。",
        "音色已停止使用",
        "音色已停止使用，回响会使用普通语音",
    )
    for phrase in required_shell_copy:
        require(phrase in shell, f"missing honest Voice/DH exit disclosure: {phrase}")

    for forbidden in (
        "删除会清理后端样本、训练产物和本地记录。此操作不可恢复。",
        "删除会立即停止该音色用于回响，并请求后端清理相关记录。第三方服务清理状态以回执为准。此操作不可恢复。",
        "音色和本地记录已清理，可以重新授权创建。",
        "self.applySnapshot(snapshot, feedback: \"音色已删除。\")",
        "该音色已停止用于回响。本地状态已更新；后端及第三方清理仍需以回执确认。",
    ):
        require(forbidden not in shell, f"misleading completed-cleanup claim remains: {forbidden}")

    for required_symbol in (
        "let exitState: String",
        "let accessRevoked: Bool",
        "let localCleanupState: String",
        "let providerCleanupState: String",
        "let providerCleanupReceiptAvailable: Bool",
        "var exitDisclosureText: String",
        "第三方服务清理尚未接入，无法确认第三方数据是否已删除。",
    ):
        require(required_symbol in shell or required_symbol in voice_service, f"missing local cleanup-state disclosure handling: {required_symbol}")

    disable_contract = constant_body(backend, "VOICE_CLONE_DISABLE_CONTRACT")
    delete_contract = constant_body(backend, "VOICE_CLONE_DELETE_CONTRACT")
    require("Provider 停用或删除回执" in disable_contract, "disable contract must disclose missing provider receipt")
    require("尚未产生样本、训练产物或 Provider 资产的删除回执" in delete_contract, "delete contract must disclose missing provider receipt")
    require("不能宣称第三方清理已完成" in delete_contract, "delete contract must reject an unsupported completion claim")
    for required_contract_field in (
        '"exitState": "accessRevoked"',
        '"exitState": "partial"',
        '"providerCleanupState": "unsupported"',
        '"providerCleanupReceiptAvailable": False',
    ):
        require(required_contract_field in backend, f"missing Voice/DH cleanup contract field: {required_contract_field}")

    print("Product V4 Voice/DH exit disclosure check passed")


if __name__ == "__main__":
    main()
