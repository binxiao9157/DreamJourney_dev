#!/usr/bin/env python3

import re
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(text: str, start: str, end: Optional[str] = None) -> str:
    start_index = text.index(start)
    if end is None:
        return text[start_index:]
    return text[start_index:text.index(end, start_index)]


def markdown_rows(text: str, prefix: str = "| `") -> list[str]:
    return [line for line in text.splitlines() if line.startswith(prefix)]


def main() -> None:
    spec = SPEC.read_text()
    headings = [
        "## 25. Identity、AuthZ 与 `/v2` API 合同",
        "### 25.0 CURRENT EVIDENCE：本节尚未实现",
        "### 25.1 生产身份与启动默认",
        "### 25.2 Session 与 Credential 生命周期",
        "### 25.3 Principal 类型",
        "### 25.4 可执行授权公式",
        "### 25.5 `/v2` 通用传输合同",
        "### 25.6 核心 `/v2` Endpoint 目录",
        "### 25.7 Error Contract",
        "### 25.8 Capability 与 Release Policy",
        "### 25.9 Legacy Compatibility 与 Cutover",
        "### 25.10 Auth/API 验收场景",
    ]
    for heading in headings:
        require(heading in spec, f"API/AuthZ heading missing: {heading}")

    auth_contract = section(spec, headings[0], "## 26. Job、Outbox、对象存储与 Provider 合同")
    for term in (
        "ProcessingBasis",
        "Consent",
        "AccessGrant",
        "WorkAuthorization",
        "DataRightsAuthorization",
        "RetentionHold",
        "extra=forbid",
        "commandId",
        "expectedVersion",
        "application/problem+json",
        "upgrade_required",
        "生产环境不允许 `shadow` ownership mode",
    ):
        require(term in auth_contract, f"API/AuthZ term missing: {term}")

    principals = section(spec, headings[4], headings[5])
    principal_rows = markdown_rows(principals)
    require(len(principal_rows) >= 6, f"principal rows too small: {len(principal_rows)}")

    endpoints = section(spec, headings[7], headings[8])
    endpoint_rows = markdown_rows(endpoints)
    require(len(endpoint_rows) >= 20, f"endpoint rows too small: {len(endpoint_rows)}")

    errors = section(spec, headings[8], headings[9])
    error_rows = [line for line in errors.splitlines() if re.match(r"^\| \d{3} \|", line)]
    require(len(error_rows) >= 9, f"error rows too small: {len(error_rows)}")

    capabilities = section(spec, headings[9], headings[10])
    for field in (
        "enabled",
        "providerReady",
        "releaseVisible",
        "externalVerified",
        "fallbackMode",
        "blockedReasonCode",
    ):
        require(field in capabilities, f"capability field missing: {field}")

    acceptance = section(
        spec,
        headings[11],
        "## 26. Job、Outbox、对象存储与 Provider 合同",
    )
    scenarios = sum(1 for line in acceptance.splitlines() if re.match(r"^\d+\. ", line))
    require(scenarios >= 10, f"Auth/API acceptance scenarios too small: {scenarios}")

    print(
        "Product V4 API/AuthZ check passed: "
        f"principals={len(principal_rows)}, endpoints={len(endpoint_rows)}, "
        f"errors={len(error_rows)}, acceptance_scenarios={scenarios}"
    )


if __name__ == "__main__":
    main()
