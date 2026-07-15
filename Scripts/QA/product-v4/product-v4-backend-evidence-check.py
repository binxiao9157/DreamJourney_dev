#!/usr/bin/env python3

import os
import re
import subprocess
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = Path(
    os.environ.get(
        "DREAMJOURNEY_BACKEND_ROOT",
        str(Path(__file__).resolve().parents[4] / "DreamJourneyBackend"),
    )
)
SPEC_PATH = IOS_ROOT / "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md"
EXPECTED_BACKEND_COMMIT = "4c0538bf3d2c90cf0ce9d3ca0dfbcb2138c73e85"
EXPECTED_ROUTE_COUNT = 58
EXPECTED_TABLE_COUNT = 18


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def git_head(repo: Path) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repo, text=True
    ).strip()


def main() -> None:
    require(BACKEND_ROOT.is_dir(), f"backend repo not found: {BACKEND_ROOT}")
    require(SPEC_PATH.is_file(), f"product spec not found: {SPEC_PATH}")

    spec = SPEC_PATH.read_text()
    backend_head = git_head(BACKEND_ROOT)
    require(
        backend_head == EXPECTED_BACKEND_COMMIT,
        "backend HEAD changed; rerun the audit and update the evidence baseline",
    )
    require(EXPECTED_BACKEND_COMMIT in spec, "backend audit commit missing from Product Spec")

    route_ownership = (BACKEND_ROOT / "app/services/route_ownership.py").read_text()
    route_count = len(re.findall(r"^\s+_(?:rule|owner_body|owner_path)\(", route_ownership, re.M))
    require(
        route_count == EXPECTED_ROUTE_COUNT,
        f"route ownership count changed: expected {EXPECTED_ROUTE_COUNT}, got {route_count}",
    )

    postgres_store = (BACKEND_ROOT / "app/services/postgres_store.py").read_text()
    table_count = len(re.findall(r"CREATE TABLE IF NOT EXISTS\s+[a-z_]+", postgres_store))
    require(
        table_count == EXPECTED_TABLE_COUNT,
        f"Postgres table count changed: expected {EXPECTED_TABLE_COUNT}, got {table_count}",
    )

    section_start = spec.index("### 23.2 CURRENT EVIDENCE：组件与迁移证据矩阵")
    section_end = spec.index("### 23.3 CURRENT EVIDENCE：代表性链路")
    component_rows = [
        line for line in spec[section_start:section_end].splitlines() if line.startswith("| `")
    ]
    require(
        len(component_rows) >= 15,
        f"backend component evidence rows too small: {len(component_rows)}",
    )

    required_target_sections = [
        "### 23.6 RECOMMENDED TARGET：系统拓扑与部署单元",
        "### 23.7 RECOMMENDED TARGET：模块、数据所有权与合同",
        "### 23.8 RECOMMENDED TARGET：事务、事件与幂等",
        "### 23.9 Owner 核心独立运行证明",
        "### 23.10 现有组件到目标模块的迁移矩阵",
        "### 23.11 渐进实施顺序",
        "### 23.12 暂不引入技术的进入证据",
    ]
    for heading in required_target_sections:
        require(heading in spec, f"target architecture section missing: {heading}")

    module_section = spec[
        spec.index(required_target_sections[1]) : spec.index(required_target_sections[2])
    ]
    module_rows = [line for line in module_section.splitlines() if line.startswith("| ")][2:]
    require(len(module_rows) >= 12, f"target module rows too small: {len(module_rows)}")

    independence_section = spec[
        spec.index(required_target_sections[3]) : spec.index(required_target_sections[4])
    ]
    independence_rows = [
        line for line in independence_section.splitlines() if line.startswith("| ")
    ][2:]
    require(
        len(independence_rows) >= 6,
        f"Owner core independence rows too small: {len(independence_rows)}",
    )

    migration_section = spec[
        spec.index(required_target_sections[4]) : spec.index(required_target_sections[5])
    ]
    migration_rows = [line for line in migration_section.splitlines() if line.startswith("| `")]
    require(
        len(migration_rows) >= 12,
        f"backend target migration rows too small: {len(migration_rows)}",
    )

    non_goal_section = spec[spec.index(required_target_sections[6]) :]
    for technology in ("微服务", "Redis", "专用向量数据库", "通用 Agent runtime"):
        require(technology in non_goal_section, f"entry evidence missing: {technology}")

    compose = (BACKEND_ROOT / "docker-compose.yml").read_text()
    runtime_config = (BACKEND_ROOT / "app/services/runtime_config.py").read_text()
    operations = (BACKEND_ROOT / "docs/backend/server-update-operations.md").read_text()
    require("redis:" in compose, "documented unused Redis deployment evidence changed")
    require('"storageProvider": "mockObjectStorage"' in runtime_config, "mock storage evidence changed")
    require("systemd timer" in operations, "external timer evidence changed")

    print(
        "Product V4 backend evidence check passed: "
        f"commit={backend_head[:7]}, routes={route_count}, tables={table_count}, "
        f"components={len(component_rows)}, modules={len(module_rows)}, "
        f"migrations={len(migration_rows)}"
    )


if __name__ == "__main__":
    main()
