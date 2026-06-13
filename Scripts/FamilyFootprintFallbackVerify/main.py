#!/usr/bin/env python3
from pathlib import Path
import sys

source = Path("DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift").read_text()
poster = Path("DreamJourney/Sources/Modules/Map/FamilyFootprintSharePoster.swift").read_text()


def contains_in_order(haystack, fragments):
    offset = 0
    for fragment in fragments:
        index = haystack.find(fragment, offset)
        if index == -1:
            return False
        offset = index + len(fragment)
    return True


checks = [
    (
        "poster preview should be explicitly deferred while the lighting map is being stabilized",
        "private let isFootprintPosterPreviewEnabled = false" in source
        and "posterButton.isHidden = true" in source
        and "posterFallbackCard.isHidden = true" in source,
    ),
    (
        "missing AMap key should skip MAMapView creation and show map configuration copy only",
        contains_in_order(
            source,
            [
                'guard AppConfiguration.string(forKey: "AMapAPIKey") != nil else',
                "mapView = nil",
                "地图暂时不可用",
                "请检查网络或 AMapAPIKey 配置",
                "return",
                "let map = MAMapView(frame: view.bounds)",
            ],
        )
        and "先用点亮预览查看家族足迹" not in source,
    ),
    (
        "fallback visibility should keep poster UI hidden and expose the illumination canvas on failures",
        contains_in_order(
            source,
            [
                "private func updatePosterFallbackVisibility()",
                "posterButton.isHidden = true",
                "posterFallbackCard.isHidden = true",
                'if mapView == nil || didEncounterMapLoadingFailure || AppConfiguration.string(forKey: "AMapAPIKey") == nil',
                "mapPlaceholderLabel.isHidden = true",
                "fallbackIlluminationView.isHidden = false",
            ],
        )
        and "private let fallbackIlluminationView = FootprintIlluminationCanvasView()" in source,
    ),
    (
        "map loading failure should switch into WebService-backed illumination mode, not poster preview copy",
        contains_in_order(
            source,
            [
                "func mapViewDidFailLoadingMap",
                "didEncounterMapLoadingFailure = true",
                "mapView.isHidden = true",
                "正在使用行政区点亮模式",
                "updatePosterFallbackVisibility()",
                "updateIlluminationLayer()",
            ],
        )
        and "本地足迹海报兜底" not in source
        and "可使用本地足迹海报继续演示" not in source,
    ),
    (
        "successful map load should clear failure state and recompute fallback visibility",
        contains_in_order(
            source,
            [
                "func mapViewDidFinishLoadingMap",
                "didEncounterMapLoadingFailure = false",
                "updatePosterFallbackVisibility()",
            ],
        ),
    ),
    (
        "illumination canvas should render WebService district polygons when native map is unavailable",
        "private final class FootprintIlluminationCanvasView" in source
        and "drawRegions(in: context, rect: mapRect, bounds: bounds)" in source
        and "使用高德 WebService 边界自绘" in source
        and contains_in_order(
            source,
            [
                "guard let mapView, !didEncounterMapLoadingFailure else",
                "fallbackIlluminationView.render(",
                "requestAmapIlluminationRegions(",
                "fallbackToLocal: true",
            ],
        ),
    ),
    (
        "poster tap handlers should remain guarded until preview work resumes",
        contains_in_order(source, ["@objc private func posterTapped()", "guard isFootprintPosterPreviewEnabled else { return }"])
        and contains_in_order(source, ["@objc private func posterFallbackTapped()", "guard isFootprintPosterPreviewEnabled else { return }"]),
    ),
    (
        "poster renderer can remain available but should stay independent from AMap SDK and photo-library writes",
        "MAMapKit" not in poster
        and "MAMapView" not in poster
        and "UIImageWriteToSavedPhotosAlbum" not in poster
        and "UIDocumentPickerViewController(forExporting:" in poster,
    ),
    (
        "poster descriptor should stay independent from AMap tiles for later preview work",
        "MAMapKit" not in poster
        and "MAMapView" not in poster
        and "FootprintIlluminationCatalog.regions" in poster,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"FamilyFootprintFallback verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("FamilyFootprintFallback verification passed")
