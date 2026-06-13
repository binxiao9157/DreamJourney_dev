import CoreLocation
import Foundation
import UIKit

enum FootprintIlluminationScope: CaseIterable {
    case city
    case nation
    case world

    var title: String {
        switch self {
        case .city: return "城市"
        case .nation: return "全国"
        case .world: return "世界"
        }
    }

    var edgePadding: UIEdgeInsets {
        switch self {
        case .city:
            return UIEdgeInsets(top: 210, left: 32, bottom: 150, right: 32)
        case .nation:
            return UIEdgeInsets(top: 210, left: 38, bottom: 150, right: 38)
        case .world:
            return UIEdgeInsets(top: 210, left: 18, bottom: 150, right: 18)
        }
    }
}

struct FootprintIlluminationStyle {
    let fillColor: UIColor
    let strokeColor: UIColor
    let lineWidth: CGFloat

    static let glow = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#27D6E5").withAlphaComponent(0.22),
        strokeColor: UIColor(hex: "#55F3FF").withAlphaComponent(0.12),
        lineWidth: 5
    )

    static let cityFill = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#21CAD8").withAlphaComponent(0.58),
        strokeColor: UIColor(hex: "#7AFAFF").withAlphaComponent(0.72),
        lineWidth: 1.2
    )

    static let nationFill = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#22C7D4").withAlphaComponent(0.50),
        strokeColor: UIColor(hex: "#73F8FF").withAlphaComponent(0.64),
        lineWidth: 1.4
    )

    static let worldFill = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#21C5D5").withAlphaComponent(0.36),
        strokeColor: UIColor(hex: "#80F8FF").withAlphaComponent(0.68),
        lineWidth: 1.8
    )

    static let futureGlow = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#B8BCC4").withAlphaComponent(0.12),
        strokeColor: UIColor(hex: "#D8DCE2").withAlphaComponent(0.10),
        lineWidth: 5
    )

    static let futureFill = FootprintIlluminationStyle(
        fillColor: UIColor(hex: "#AEB4BE").withAlphaComponent(0.34),
        strokeColor: UIColor(hex: "#E1E4EA").withAlphaComponent(0.48),
        lineWidth: 1.4
    )
}

struct FootprintIlluminationOverlaySpec {
    let coordinates: [CLLocationCoordinate2D]
    let style: FootprintIlluminationStyle
}

struct FootprintIlluminationRegion {
    let name: String
    let center: CLLocationCoordinate2D
    let overlaySpecs: [FootprintIlluminationOverlaySpec]
    let approximateAreaKm2: Int
    let source: FootprintBoundarySource
}

enum FootprintBoundarySource: String {
    case bundledGeoJSON
    case builtInFallback
    case amapDistrict
}

enum FootprintIlluminationCatalog {
    static func regions(
        scope: FootprintIlluminationScope,
        points: [FamilyFootprintPoint],
        generation: FamilyFootprintGeneration
    ) -> [FootprintIlluminationRegion] {
        if let scripted = scriptedRegions(for: generation, scope: scope) {
            return scripted
        }
        return regions(scope: scope, points: points)
    }

    static func regions(scope: FootprintIlluminationScope, points: [FamilyFootprintPoint]) -> [FootprintIlluminationRegion] {
        let requestedKeys = regionKeys(scope: scope, points: points)
        let bundled = FamilyFootprintBoundaryStore.shared.regions(
            scope: scope,
            keys: requestedKeys
        )

        if bundled.count >= minRequiredRegionCount(scope: scope, requestedKeys: requestedKeys) {
            return bundled
        }

        switch scope {
        case .city:
            return cityRegions(points: points)
        case .nation:
            return nationRegions(points: points)
        case .world:
            return worldRegions(points: points)
        }
    }

    static func statsText(
        scope: FootprintIlluminationScope,
        points: [FamilyFootprintPoint],
        generation: FamilyFootprintGeneration,
        isGuest: Bool
    ) -> NSAttributedString {
        if let scripted = scriptedStatsText(for: generation) {
            return scripted
        }

        let visiblePoints = FamilyFootprintTimeline.filtered(points, by: generation)
        guard !visiblePoints.isEmpty else {
            return lineStats(numbers: ["0"], labels: [generation == .all ? "暂无足迹" : "\(generation.title)暂无足迹"], footer: "寻梦环游 · 家族足迹")
        }

        let regions = self.regions(scope: scope, points: visiblePoints, generation: generation)
        let minYear = visiblePoints.map(\.year).min() ?? Calendar.current.component(.year, from: Date())
        let maxYear = visiblePoints.map(\.year).max() ?? minYear
        let days = max(1, (maxYear - minYear + 1) * 365)
        let cityCount = Set(visiblePoints.map { normalizedCityName($0.location) }).count
        let prefix = isGuest ? "授权" : generation.title

        switch scope {
        case .city:
            let exploredCorners = max(visiblePoints.count * 7, regions.count * 12)
            let percent = min(99, max(1, regions.count * 4 + visiblePoints.count))
            return lineStats(
                numbers: ["\(percent)", "\(exploredCorners)"],
                labels: ["走过杭州(%)", "探索城市角落(个)"],
                footer: "\(prefix)足迹 · 城市微光"
            )
        case .nation:
            let area = max(visiblePoints.count * 3842, regions.reduce(0) { $0 + $1.approximateAreaKm2 })
            return lineStats(
                numbers: ["\(max(cityCount, regions.count))", "\(days)", "\(area)"],
                labels: ["全国城市(个)", "历时(天)", "约点亮全国(km²)"],
                footer: "\(prefix)足迹 · 家族迁徙"
            )
        case .world:
            let countryCount = Set(visiblePoints.map { countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location) }).count
            return lineStats(
                numbers: ["\(max(countryCount, regions.count))", "\(days)"],
                labels: ["全球国家(个)", "历时(天)"],
                footer: "\(prefix)足迹 · 更大的世界"
            )
        }
    }

    private static func scriptedStatsText(for generation: FamilyFootprintGeneration) -> NSAttributedString? {
        switch generation {
        case .ancestors:
            return lineStats(
                numbers: ["绍兴", "1"],
                labels: ["祖辈范围", "家族原点"],
                footer: "祖辈足迹 · 绍兴老家的根"
            )
        case .parents:
            return lineStats(
                numbers: ["浙江", "1"],
                labels: ["父辈范围", "省域点亮"],
                footer: "父辈足迹 · 生活半径铺到浙江"
            )
        case .current:
            return lineStats(
                numbers: ["4", "江浙沪广"],
                labels: ["省市范围", "我们这一代"],
                footer: "我们足迹 · 江苏 浙江 上海 广东"
            )
        case .next:
            return lineStats(
                numbers: ["灰色", "待定"],
                labels: ["下一代范围", "未来点亮"],
                footer: "下一代足迹 · 暂不绑定具体城市"
            )
        case .all:
            return lineStats(
                numbers: ["4代", "江浙沪广"],
                labels: ["家族范围", "当前版图"],
                footer: "全家足迹 · 绍兴 浙江 江浙沪广 未来"
            )
        }
    }

    static func normalizedCityName(_ location: String) -> String {
        let knownCities = [
            "上海", "北京", "南京", "成都", "杭州", "广州", "绍兴", "深圳",
            "温哥华", "新加坡", "重庆", "昆明", "贵阳", "庆阳", "徐州", "金华", "福州", "香港"
        ]
        return knownCities.first(where: { location.contains($0) }) ?? location
    }

    static func countryName(latitude: Double, longitude: Double, location: String) -> String {
        if location.contains("温哥华") || longitude < -60 {
            return "加拿大"
        }
        if location.contains("新加坡") {
            return "新加坡"
        }
        return "中国"
    }

    private static func regionKeys(scope: FootprintIlluminationScope, points: [FamilyFootprintPoint]) -> Set<String> {
        switch scope {
        case .city:
            let cityNames = Set(points.map { normalizedCityName($0.location) })
            return cityNames.contains("杭州") || cityNames.isEmpty ? Set(hangzhouDistrictKeys) : cityNames
        case .nation:
            return Set(points.map { normalizedCityName($0.location) })
        case .world:
            return Set(points.map { countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location) })
        }
    }

    private static func minRequiredRegionCount(scope: FootprintIlluminationScope, requestedKeys: Set<String>) -> Int {
        switch scope {
        case .city:
            return requestedKeys.contains("杭州") ? 8 : max(1, min(3, requestedKeys.count))
        case .nation:
            return max(1, requestedKeys.count)
        case .world:
            return max(1, requestedKeys.count)
        }
    }

    private static let hangzhouDistrictKeys = [
        "西湖", "拱墅", "上城", "滨江", "萧山", "余杭", "临平", "富阳", "临安", "桐庐", "建德", "淳安"
    ]

    private static func scriptedRegions(
        for generation: FamilyFootprintGeneration,
        scope: FootprintIlluminationScope
    ) -> [FootprintIlluminationRegion]? {
        switch generation {
        case .ancestors:
            return [
                region(
                    name: "绍兴",
                    center: .init(latitude: 30.030, longitude: 120.580),
                    latRadius: 0.35,
                    lonRadius: 0.42,
                    area: 8274,
                    style: .nationFill
                )
            ]
        case .parents:
            return [
                region(
                    name: "浙江",
                    center: .init(latitude: 29.160, longitude: 120.150),
                    latRadius: 1.75,
                    lonRadius: 2.20,
                    area: 105500,
                    style: .nationFill
                )
            ]
        case .current:
            return jiangzhehuguangRegions(style: .nationFill)
        case .next:
            return [
                region(
                    name: "下一代暂定区域",
                    center: .init(latitude: 32.900, longitude: 114.800),
                    latRadius: 3.10,
                    lonRadius: 5.10,
                    area: 0,
                    style: .futureFill,
                    glowStyle: .futureGlow
                )
            ]
        case .all:
            return [
                region(
                    name: "绍兴",
                    center: .init(latitude: 30.030, longitude: 120.580),
                    latRadius: 0.35,
                    lonRadius: 0.42,
                    area: 8274,
                    style: .cityFill
                ),
                region(
                    name: "浙江",
                    center: .init(latitude: 29.160, longitude: 120.150),
                    latRadius: 1.75,
                    lonRadius: 2.20,
                    area: 105500,
                    style: .nationFill
                )
            ] + jiangzhehuguangRegions(style: .nationFill) + [
                region(
                    name: "下一代暂定",
                    center: .init(latitude: 34.700, longitude: 112.000),
                    latRadius: 2.20,
                    lonRadius: 3.30,
                    area: 0,
                    style: .futureFill,
                    glowStyle: .futureGlow
                )
            ]
        }
    }

    private static func jiangzhehuguangRegions(style: FootprintIlluminationStyle) -> [FootprintIlluminationRegion] {
        [
            region(name: "江苏", center: .init(latitude: 32.060, longitude: 118.767), latRadius: 1.42, lonRadius: 1.64, area: 107200, style: style),
            region(name: "浙江", center: .init(latitude: 29.160, longitude: 120.150), latRadius: 1.75, lonRadius: 2.20, area: 105500, style: style),
            region(name: "上海", center: .init(latitude: 31.230, longitude: 121.474), latRadius: 0.36, lonRadius: 0.44, area: 6340, style: style),
            region(name: "广东", center: .init(latitude: 23.379, longitude: 113.763), latRadius: 1.92, lonRadius: 2.36, area: 179800, style: style)
        ]
    }

    private static func cityRegions(points: [FamilyFootprintPoint]) -> [FootprintIlluminationRegion] {
        let cityNames = Set(points.map { normalizedCityName($0.location) })
        let useHangzhouPoster = cityNames.contains("杭州") || cityNames.isEmpty
        guard useHangzhouPoster else {
            return points.prefix(12).map {
                region(
                    name: normalizedCityName($0.location),
                    center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    latRadius: 0.18,
                    lonRadius: 0.20,
                    area: 84,
                    style: .cityFill
                )
            }
        }

        return [
            region(name: "西湖", center: .init(latitude: 30.259, longitude: 120.130), latRadius: 0.075, lonRadius: 0.078, area: 79, style: .cityFill),
            region(name: "拱墅", center: .init(latitude: 30.330, longitude: 120.168), latRadius: 0.070, lonRadius: 0.072, area: 119, style: .cityFill),
            region(name: "上城", center: .init(latitude: 30.250, longitude: 120.185), latRadius: 0.060, lonRadius: 0.065, area: 122, style: .cityFill),
            region(name: "滨江", center: .init(latitude: 30.205, longitude: 120.210), latRadius: 0.050, lonRadius: 0.060, area: 73, style: .cityFill),
            region(name: "萧山", center: .init(latitude: 30.165, longitude: 120.270), latRadius: 0.115, lonRadius: 0.118, area: 1420, style: .cityFill),
            region(name: "余杭", center: .init(latitude: 30.420, longitude: 120.020), latRadius: 0.150, lonRadius: 0.170, area: 1228, style: .cityFill),
            region(name: "临平", center: .init(latitude: 30.420, longitude: 120.300), latRadius: 0.092, lonRadius: 0.108, area: 286, style: .cityFill),
            region(name: "富阳", center: .init(latitude: 30.050, longitude: 119.945), latRadius: 0.170, lonRadius: 0.178, area: 1821, style: .cityFill),
            region(name: "临安", center: .init(latitude: 30.235, longitude: 119.610), latRadius: 0.215, lonRadius: 0.245, area: 3126, style: .cityFill),
            region(name: "桐庐", center: .init(latitude: 29.800, longitude: 119.680), latRadius: 0.170, lonRadius: 0.180, area: 1825, style: .cityFill),
            region(name: "建德", center: .init(latitude: 29.475, longitude: 119.280), latRadius: 0.175, lonRadius: 0.190, area: 2314, style: .cityFill),
            region(name: "淳安", center: .init(latitude: 29.630, longitude: 118.960), latRadius: 0.205, lonRadius: 0.230, area: 4417, style: .cityFill)
        ]
    }

    private static func nationRegions(points: [FamilyFootprintPoint]) -> [FootprintIlluminationRegion] {
        let cities = Set(points.map { normalizedCityName($0.location) })
        let catalog: [String: FootprintIlluminationRegion] = [
            "杭州": region(name: "杭州", center: .init(latitude: 30.274, longitude: 120.155), latRadius: 0.55, lonRadius: 0.62, area: 16850, style: .nationFill),
            "绍兴": region(name: "绍兴", center: .init(latitude: 30.030, longitude: 120.580), latRadius: 0.35, lonRadius: 0.42, area: 8274, style: .nationFill),
            "上海": region(name: "上海", center: .init(latitude: 31.230, longitude: 121.474), latRadius: 0.36, lonRadius: 0.44, area: 6340, style: .nationFill),
            "南京": region(name: "南京", center: .init(latitude: 32.060, longitude: 118.797), latRadius: 0.42, lonRadius: 0.50, area: 6587, style: .nationFill),
            "徐州": region(name: "徐州", center: .init(latitude: 34.205, longitude: 117.284), latRadius: 0.48, lonRadius: 0.58, area: 11258, style: .nationFill),
            "成都": region(name: "成都", center: .init(latitude: 30.572, longitude: 104.066), latRadius: 0.58, lonRadius: 0.70, area: 14335, style: .nationFill),
            "重庆": region(name: "重庆", center: .init(latitude: 29.563, longitude: 106.551), latRadius: 0.72, lonRadius: 0.85, area: 82400, style: .nationFill),
            "昆明": region(name: "昆明", center: .init(latitude: 25.038, longitude: 102.718), latRadius: 0.58, lonRadius: 0.70, area: 21473, style: .nationFill),
            "贵阳": region(name: "贵阳", center: .init(latitude: 26.647, longitude: 106.630), latRadius: 0.43, lonRadius: 0.50, area: 8034, style: .nationFill),
            "庆阳": region(name: "庆阳", center: .init(latitude: 35.709, longitude: 107.642), latRadius: 0.52, lonRadius: 0.62, area: 27119, style: .nationFill),
            "金华": region(name: "金华", center: .init(latitude: 29.079, longitude: 119.647), latRadius: 0.42, lonRadius: 0.50, area: 10942, style: .nationFill),
            "福州": region(name: "福州", center: .init(latitude: 26.074, longitude: 119.296), latRadius: 0.50, lonRadius: 0.58, area: 11968, style: .nationFill),
            "香港": region(name: "香港", center: .init(latitude: 22.319, longitude: 114.169), latRadius: 0.18, lonRadius: 0.22, area: 1114, style: .nationFill),
            "深圳": region(name: "深圳", center: .init(latitude: 22.543, longitude: 114.058), latRadius: 0.24, lonRadius: 0.32, area: 1997, style: .nationFill)
        ]

        var selected = cities.compactMap { catalog[$0] }
        let knownCityNames = Set(catalog.keys)
        let missingCityRegions = points
            .filter { !knownCityNames.contains(normalizedCityName($0.location)) }
            .uniqueByNormalizedCity()
            .map {
                region(
                    name: normalizedCityName($0.location),
                    center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    latRadius: 0.28,
                    lonRadius: 0.34,
                    area: 520,
                    style: .nationFill
                )
            }
        selected.append(contentsOf: missingCityRegions)
        return selected.sorted { $0.name < $1.name }
    }

    private static func worldRegions(points: [FamilyFootprintPoint]) -> [FootprintIlluminationRegion] {
        let countries = Set(points.map { countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location) })
        var regions: [FootprintIlluminationRegion] = []

        if countries.contains("中国") {
            regions.append(
                region(
                    name: "中国",
                    center: .init(latitude: 35.8617, longitude: 104.1954),
                    latRadius: 8.6,
                    lonRadius: 13.0,
                    area: 9600000,
                    style: .worldFill
                )
            )
        }

        if countries.contains("加拿大") {
            regions.append(
                region(
                    name: "加拿大",
                    center: .init(latitude: 49.2827, longitude: -123.1207),
                    latRadius: 3.2,
                    lonRadius: 4.8,
                    area: 9984670,
                    style: .worldFill
                )
            )
        }

        if countries.contains("新加坡") {
            regions.append(
                region(
                    name: "新加坡",
                    center: .init(latitude: 1.3521, longitude: 103.8198),
                    latRadius: 0.24,
                    lonRadius: 0.30,
                    area: 734,
                    style: .worldFill
                )
            )
        }

        return regions
    }

    private static func region(
        name: String,
        center: CLLocationCoordinate2D,
        latRadius: CLLocationDegrees,
        lonRadius: CLLocationDegrees,
        area: Int,
        style: FootprintIlluminationStyle,
        glowStyle: FootprintIlluminationStyle = .glow
    ) -> FootprintIlluminationRegion {
        let glow = FootprintIlluminationOverlaySpec(
            coordinates: blob(center: center, latRadius: latRadius * 1.14, lonRadius: lonRadius * 1.14),
            style: glowStyle
        )
        let fill = FootprintIlluminationOverlaySpec(
            coordinates: blob(center: center, latRadius: latRadius, lonRadius: lonRadius),
            style: style
        )
        return FootprintIlluminationRegion(
            name: name,
            center: center,
            overlaySpecs: [glow, fill],
            approximateAreaKm2: area,
            source: .builtInFallback
        )
    }

    private static func blob(
        center: CLLocationCoordinate2D,
        latRadius: CLLocationDegrees,
        lonRadius: CLLocationDegrees
    ) -> [CLLocationCoordinate2D] {
        let factors: [(Double, Double, Double)] = [
            (0, 0.92, 1.08),
            (32, 1.05, 0.96),
            (67, 0.88, 1.12),
            (105, 1.12, 0.90),
            (146, 0.96, 1.04),
            (188, 1.08, 0.86),
            (225, 0.90, 1.10),
            (263, 1.13, 0.94),
            (302, 0.94, 1.02),
            (334, 1.02, 0.88)
        ]

        return factors.map { degree, latFactor, lonFactor in
            let radians = degree * .pi / 180
            return CLLocationCoordinate2D(
                latitude: center.latitude + sin(radians) * latRadius * latFactor,
                longitude: center.longitude + cos(radians) * lonRadius * lonFactor
            )
        }
    }

    private static func lineStats(numbers: [String], labels: [String], footer: String) -> NSAttributedString {
        let firstLine = numbers.joined(separator: "      ")
        let secondLine = labels.joined(separator: "    ")
        let text = "\(firstLine)\n\(secondLine)\n\(footer)"
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.72)
            ]
        )

        if let firstRange = text.range(of: firstLine) {
            attr.addAttributes(
                [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .heavy),
                    .foregroundColor: UIColor.white
                ],
                range: NSRange(firstRange, in: text)
            )
        }

        if let footerRange = text.range(of: footer) {
            attr.addAttributes(
                [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.56)
                ],
                range: NSRange(footerRange, in: text)
            )
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 7
        attr.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attr.length))
        return attr
    }
}

final class FamilyFootprintBoundaryStore {
    static let shared = FamilyFootprintBoundaryStore()

    private let regionsByScope: [FootprintIlluminationScope: [String: FootprintIlluminationRegion]]

    init(bundle: Bundle = .main, resourceName: String = "family_footprint_boundaries") {
        regionsByScope = Self.loadBundledRegions(bundle: bundle, resourceName: resourceName)
    }

    func regions(scope: FootprintIlluminationScope, keys: Set<String>) -> [FootprintIlluminationRegion] {
        guard let regions = regionsByScope[scope], !regions.isEmpty else { return [] }
        return keys.compactMap { regions[$0] }
    }

    private static func loadBundledRegions(bundle: Bundle, resourceName: String) -> [FootprintIlluminationScope: [String: FootprintIlluminationRegion]] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let boundaryFile = try? JSONDecoder().decode(FootprintBoundaryFile.self, from: data) else {
            return [:]
        }

        var result: [FootprintIlluminationScope: [String: FootprintIlluminationRegion]] = [:]
        for region in boundaryFile.regions {
            guard let scope = region.scope.illuminationScope,
                  let illuminationRegion = region.illuminationRegion else {
                continue
            }
            result[scope, default: [:]][region.name] = illuminationRegion
        }
        return result
    }
}

private struct FootprintBoundaryFile: Decodable {
    let regions: [FootprintBoundaryRecord]
}

private struct FootprintBoundaryRecord: Decodable {
    let scope: FootprintBoundaryScope
    let name: String
    let center: [Double]
    let approximateAreaKm2: Int
    let polygons: [[[Double]]]

    var illuminationRegion: FootprintIlluminationRegion? {
        guard center.count == 2, !polygons.isEmpty else { return nil }
        let style = scope.style
        let overlays = polygons.compactMap { rawCoordinates -> FootprintIlluminationOverlaySpec? in
            let coordinates = rawCoordinates.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            guard coordinates.count >= 3 else { return nil }
            return FootprintIlluminationOverlaySpec(coordinates: coordinates, style: style)
        }

        guard !overlays.isEmpty else { return nil }
        return FootprintIlluminationRegion(
            name: name,
            center: CLLocationCoordinate2D(latitude: center[1], longitude: center[0]),
            overlaySpecs: overlays,
            approximateAreaKm2: approximateAreaKm2,
            source: .bundledGeoJSON
        )
    }
}

private enum FootprintBoundaryScope: String, Decodable {
    case city
    case nation
    case world

    var illuminationScope: FootprintIlluminationScope? {
        switch self {
        case .city: return .city
        case .nation: return .nation
        case .world: return .world
        }
    }

    var style: FootprintIlluminationStyle {
        switch self {
        case .city: return .cityFill
        case .nation: return .nationFill
        case .world: return .worldFill
        }
    }
}

private extension Array where Element == FamilyFootprintPoint {
    func uniqueByNormalizedCity() -> [FamilyFootprintPoint] {
        var seen = Set<String>()
        return filter { point in
            let city = FootprintIlluminationCatalog.normalizedCityName(point.location)
            guard !seen.contains(city) else { return false }
            seen.insert(city)
            return true
        }
    }
}
