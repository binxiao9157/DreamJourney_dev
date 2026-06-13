#!/usr/bin/env python3
from pathlib import Path
import sys

poster = Path("DreamJourney/Sources/Modules/Map/FamilyFootprintSharePoster.swift").read_text()
map_vc = Path("DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift").read_text()
provider = Path("DreamJourney/Sources/Modules/Map/AmapDistrictBoundaryProvider.swift").read_text()
illumination = Path("DreamJourney/Sources/Modules/Map/FamilyFootprintIllumination.swift").read_text()
config = Path("DreamJourney/Sources/Services/AppConfiguration.swift").read_text()
project = Path("DreamJourney.xcodeproj/project.pbxproj").read_text()


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
        "poster descriptor should use current illumination scope",
        "scope: FootprintIlluminationScope" in poster and "scope.title" in poster,
    ),
    (
        "poster descriptor should use current generation",
        "generation: FamilyFootprintGeneration" in poster and "FamilyFootprintTimeline.filtered" in poster,
    ),
    (
        "poster should include QR payload and caption",
        "CIQRCodeGenerator" in poster and "扫码查看家族足迹" in poster,
    ),
    (
        "poster should explain map symbols with user-facing legend copy",
        "drawLegend(in: cg, size: size)" in poster
        and "点亮区域" in poster
        and "到过的城市" in poster
        and "迁徙路线" in poster
        and "家族足迹点亮图" in poster
        and "本地" not in poster
        and "兜底" not in poster,
    ),
    (
        "poster should reuse journey summary and draw migration route lines",
        "journeySummary: FamilyFootprintJourneySummary" in poster
        and "FamilyFootprintTimeline.journeySummary" in poster
        and "path.addLine(to: center)" in poster
        and "更大的世界" not in poster,
    ),
    (
        "poster migration points and illuminated regions should share one map coordinate bounds",
        contains_in_order(
            poster,
            [
                "let mapBounds = coordinateBounds(points: descriptor.points, regions: descriptor.regions)",
                "drawRegions(in: cg, rect: rect, descriptor: descriptor, bounds: mapBounds)",
                "drawPoints(in: cg, rect: rect, points: descriptor.points, bounds: mapBounds)",
            ],
        )
        and "coordinateBounds(points: points, regions: [])" not in poster,
    ),
    (
        "poster should prefer a real map snapshot when available",
        "mapSnapshot: UIImage? = nil" in poster
        and "drawSnapshot(mapSnapshot, in: rect)" in poster
        and "takeSnapshot(in: mapView.bounds" in map_vc
        and "timeoutInterval: 1.5" in map_vc,
    ),
    (
        "offline poster should draw administrative polygons instead of grid bubbles",
        "polygonPath(for: overlaySpec.coordinates" in poster
        and "overlaySpec.style.fillColor.setFill()" in poster
        and "drawGrid(in:" not in poster
        and "glowRect" not in poster
        and "UIBezierPath(ovalIn: glowRect" not in poster,
    ),
    (
        "poster coordinate bounds should include region centers and overlay coordinates",
        "let regionCoordinates = regions.flatMap" in poster
        and "[region.center] + region.overlaySpecs.flatMap(\\.coordinates)" in poster
        and "regionCoordinates.map(\\.latitude)" in poster
        and "regionCoordinates.map(\\.longitude)" in poster,
    ),
    (
        "map journey card should reuse journey summary",
        "FamilyFootprintTimeline.journeySummary" in map_vc
        and "summary.routeText" in map_vc
        and "summary.scaleText" in map_vc,
    ),
    (
        "poster text should wrap and scale down instead of hard truncating long demo copy",
        "minimumScaleFactor: CGFloat = 0.72" in poster
        and "boundingRect(" in poster
        and "fittingFont = fittingFont.withSize" in poster,
    ),
    (
        "poster text renderer should not use tail truncation",
        "paragraph.lineBreakMode = .byWordWrapping" in poster
        and ".byTruncatingTail" not in poster,
    ),
    (
        "preview should export files instead of direct photo-library writes",
        "UIDocumentPickerViewController(forExporting:" in poster and "UIImageWriteToSavedPhotosAlbum" not in poster,
    ),
    (
        "poster preview entry should be hidden until administrative lighting is stable",
        "private let isFootprintPosterPreviewEnabled = false" in map_vc
        and "posterButton" in map_vc
        and "posterTapped" in map_vc
        and "生成家族足迹海报" in map_vc
        and contains_in_order(map_vc, ["@objc private func posterTapped()", "guard isFootprintPosterPreviewEnabled else { return }"])
        and contains_in_order(map_vc, ["private func updatePosterFallbackVisibility()", "posterButton.isHidden = true", "posterFallbackCard.isHidden = true"]),
    ),
    (
        "map screen should merge AMap district boundaries with local scripted fallbacks",
        "AmapDistrictBoundaryProvider.shared.regions" in map_vc
        and "requestAmapIlluminationRegions" in map_vc
        and "completedIlluminationRegions" in map_vc
        and "renderIlluminationRegions(completedRegions, on: mapView)" in map_vc
        and "self.illuminationRequestSerial == requestSerial" in map_vc,
    ),
    (
        "AMap district provider should use WebService district polyline and keep existing key fallback",
        "https://restapi.amap.com/v3/config/district" in provider
        and 'URLQueryItem(name: "extensions", value: "all")' in provider
        and "parsePolyline" in provider
        and "FootprintIlluminationRegion(" in provider
        and "AMapWebServiceKey" in provider
        and "AMapAPIKey" in provider
        and '"AMapWebServiceKey"' in config
        and "case amapDistrict" in illumination,
    ),
    (
        "poster source should be included in Xcode target",
        "FamilyFootprintSharePoster.swift in Sources" in project
        and "AmapDistrictBoundaryProvider.swift in Sources" in project,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"FamilyFootprintPoster verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("FamilyFootprintPoster verification passed")
