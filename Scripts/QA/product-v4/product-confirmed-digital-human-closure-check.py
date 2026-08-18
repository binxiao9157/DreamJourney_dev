#!/usr/bin/env python3
"""Guard the confirmed public-product closure of digital human runtime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def require(text: str, marker: str, message: str) -> None:
    if marker not in text:
        raise SystemExit(f"product-confirmed digital-human closure check failed: {message}")


feature_gate = (ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift").read_text(
    encoding="utf-8"
)
feature_flags = (ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift").read_text(
    encoding="utf-8"
)
echo = (ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift").read_text(
    encoding="utf-8"
)

require(
    feature_gate,
    "private static let productClosedFeatures: Set<DJFeature>",
    "FeatureGateService must define a public-product closed set",
)
require(
    feature_gate,
    ".digitalHumanLivePanel,",
    "digitalHumanLivePanel must be included in a fail-closed feature set",
)
managed_start = feature_gate.index(
    "private static let serverPolicyManagedProductionFeatures: Set<DJFeature>"
)
managed_end = feature_gate.index(
    "private static let serverPolicyManagedGeneralFeatures: Set<DJFeature>",
    managed_start,
)
managed_block = feature_gate[managed_start:managed_end]
if ".digitalHumanLivePanel," in managed_block:
    raise SystemExit(
        "product-confirmed digital-human closure check failed: "
        "ordinary server rollout must not contain digitalHumanLivePanel"
    )
require(
    feature_gate,
    "guard !Self.productClosedFeatures.contains(feature) else { return false }",
    "server-managed public routes must reject product-closed features",
)
require(
    feature_flags,
    "case digitalHumanLivePanel",
    "the QA-only feature identity must remain explicit",
)
require(
    echo,
    "if isDigitalHumanQAOverrideEnabled",
    "isolated QA launch arguments may retain the internal runtime harness",
)
require(
    echo,
    ".isServerPolicyManagedRouteAllowed(.digitalHumanLivePanel)",
    "ordinary Echo must use the public product gate",
)
require(
    echo,
    "guard shouldShowDigitalHumanLivePanel,",
    "Echo must reject digital-human preparation before capability or session calls",
)

print("product-confirmed digital-human closure check passed")
