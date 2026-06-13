import Foundation

enum FamilyFootprintGeneration: String, CaseIterable {
    case all
    case ancestors
    case parents
    case current
    case next

    var title: String {
        switch self {
        case .all: return "全家"
        case .ancestors: return "祖辈"
        case .parents: return "父辈"
        case .current: return "我们"
        case .next: return "下一代"
        }
    }

    var narrativeTitle: String {
        switch self {
        case .all: return "家族足迹从绍兴铺向江浙沪广"
        case .ancestors: return "祖辈守着绍兴老家的根"
        case .parents: return "父辈把生活半径铺到浙江"
        case .current: return "我们走到江浙沪广"
        case .next: return "下一代的地图先留一片灰色"
        }
    }

    var usesScriptedFootprintRange: Bool {
        true
    }

    var sortOrder: Int {
        switch self {
        case .all: return 0
        case .ancestors: return 1
        case .parents: return 2
        case .current: return 3
        case .next: return 4
        }
    }
}

struct FamilyFootprintPoint: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let location: String
    let year: Int
    let month: Int
    let latitude: Double
    let longitude: Double
    let generation: FamilyFootprintGeneration
    let ownerName: String
    let sourceMemoryId: String?
    let isPrivate: Bool

    var timeText: String {
        "\(year)年\(month)月"
    }
}

struct FamilyFootprintJourneySummary: Equatable {
    let title: String
    let routeText: String
    let detailText: String
    let scaleText: String
}

enum FamilyFootprintTimeline {

    static let displayGenerations: [FamilyFootprintGeneration] = [
        .all, .ancestors, .parents, .current, .next
    ]

    static func points(from memories: [MemoryModel], ownerName: String? = nil, includeDemoExpansion: Bool) -> [FamilyFootprintPoint] {
        let memoryPoints = memories.map { memory in
            FamilyFootprintPoint(
                id: memory.id,
                title: memory.title,
                subtitle: memory.subtitle,
                location: memory.location,
                year: memory.year,
                month: memory.month,
                latitude: memory.latitude,
                longitude: memory.longitude,
                generation: generation(for: memory),
                ownerName: ownerName ?? "家人",
                sourceMemoryId: memory.id,
                isPrivate: memory.isPrivate
            )
        }

        guard includeDemoExpansion else {
            return memoryPoints.sortedForTimeline()
        }

        return merge(memoryPoints: memoryPoints, demoPoints: roadshowExpansionPoints())
    }

    static func filtered(_ points: [FamilyFootprintPoint], by generation: FamilyFootprintGeneration) -> [FamilyFootprintPoint] {
        guard generation != .all else { return points.sortedForTimeline() }
        return points.filter { $0.generation == generation }.sortedForTimeline()
    }

    static func statsText(for points: [FamilyFootprintPoint], generation: FamilyFootprintGeneration, isGuest: Bool) -> String {
        let visiblePoints = filtered(points, by: generation)
        guard !visiblePoints.isEmpty else {
            return generation == .all ? "暂无足迹" : "\(generation.title)暂无足迹"
        }

        let cityCount = Set(visiblePoints.map { normalizedCityName($0.location) }).count
        let minYear = visiblePoints.map(\.year).min() ?? 0
        let maxYear = visiblePoints.map(\.year).max() ?? minYear
        let span = maxYear - minYear
        let prefix = isGuest ? "授权足迹" : (generation == .all ? "全家足迹" : "\(generation.title)足迹")
        return "\(prefix) \(visiblePoints.count) 个点 · \(cityCount) 座城 · 跨越 \(span) 年"
    }

    static func narrativeText(for points: [FamilyFootprintPoint], generation: FamilyFootprintGeneration) -> String {
        if let scripted = scriptedNarrativeText(for: generation) {
            return scripted
        }
        let visiblePoints = filtered(points, by: generation)
        guard let first = visiblePoints.first, let last = visiblePoints.last else {
            return "把回忆补充到地图上，家族迁徙会一点点被点亮。"
        }

        if generation == .all {
            return "从\(normalizedCityName(first.location))到\(normalizedCityName(last.location))，一家人的生活半径被一代代铺开。"
        }

        return "\(generation.narrativeTitle)：\(normalizedCityName(first.location)) → \(normalizedCityName(last.location))"
    }

    static func journeySummary(for points: [FamilyFootprintPoint], generation: FamilyFootprintGeneration) -> FamilyFootprintJourneySummary {
        if let scripted = scriptedJourneySummary(for: generation) {
            return scripted
        }
        let visiblePoints = filtered(points, by: generation)
        guard !visiblePoints.isEmpty else {
            return FamilyFootprintJourneySummary(
                title: generation == .all ? "等待点亮第一段家族足迹" : "\(generation.title)还没有足迹",
                routeText: "补充一段地点回忆，地图会开始发光",
                detailText: "暂无城市 · 暂无年代",
                scaleText: "家族世界待点亮"
            )
        }

        let orderedCities = orderedUnique(visiblePoints.map { normalizedCityName($0.location) })
        let orderedCountries = orderedUnique(visiblePoints.map { countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location) })
        let minYear = visiblePoints.map(\.year).min() ?? 0
        let maxYear = visiblePoints.map(\.year).max() ?? minYear
        let route = representativeRoute(from: orderedCities)
        let spanText = minYear == maxYear ? "\(minYear)年" : "\(minYear)-\(maxYear)"
        let countryText = orderedCountries.count > 1 ? "\(orderedCountries.count) 个国家" : "\(orderedCountries.first ?? "1 个国家")"
        let scaleText: String
        if orderedCountries.count > 1 {
            scaleText = "更大的世界"
        } else if orderedCities.count >= 4 {
            scaleText = "更大的中国"
        } else {
            scaleText = "正在变大的生活半径"
        }

        return FamilyFootprintJourneySummary(
            title: generation.narrativeTitle,
            routeText: route,
            detailText: "\(spanText) · \(orderedCities.count) 座城 · \(countryText)",
            scaleText: scaleText
        )
    }

    static func scriptedNarrativeText(for generation: FamilyFootprintGeneration) -> String? {
        switch generation {
        case .all:
            return "从绍兴老家，到浙江生活半径，再到江浙沪广，下一代的未来区域也会被一代代点亮。"
        case .ancestors:
            return "祖辈足迹聚在绍兴，那里是家族故事最早被记住的地方。"
        case .parents:
            return "父辈把生活半径铺到浙江，家的坐标从一个城市变成一片区域。"
        case .current:
            return "我们这一代走到江浙沪广，工作、团聚和新的生活一起展开。"
        case .next:
            return "下一代暂时不设定具体城市，先用灰色区域留下未来会被点亮的位置。"
        }
    }

    static func scriptedJourneySummary(for generation: FamilyFootprintGeneration) -> FamilyFootprintJourneySummary? {
        switch generation {
        case .all:
            return FamilyFootprintJourneySummary(
                title: "家族足迹从绍兴铺向江浙沪广",
                routeText: "绍兴 → 浙江 → 江浙沪广 → 未来区域",
                detailText: "四代范围 · 家族迁徙 · 下一代待点亮",
                scaleText: "一代代变大的生活半径"
            )
        case .ancestors:
            return FamilyFootprintJourneySummary(
                title: "祖辈守着绍兴老家的根",
                routeText: "点亮范围：绍兴",
                detailText: "祖辈范围 · 家族原点",
                scaleText: "老家的根"
            )
        case .parents:
            return FamilyFootprintJourneySummary(
                title: "父辈把生活半径铺到浙江",
                routeText: "点亮范围：浙江",
                detailText: "父辈范围 · 从城市走向省域",
                scaleText: "变大的生活半径"
            )
        case .current:
            return FamilyFootprintJourneySummary(
                title: "我们走到江浙沪广",
                routeText: "点亮范围：江苏、浙江、上海、广东",
                detailText: "我们这一代 · 工作与团聚的版图",
                scaleText: "更大的中国"
            )
        case .next:
            return FamilyFootprintJourneySummary(
                title: "下一代的地图先留一片灰色",
                routeText: "暂定范围：未来待点亮",
                detailText: "下一代范围 · 不绑定具体城市",
                scaleText: "未来会继续变大"
            )
        }
    }

    static func nextPlaybackGeneration(after generation: FamilyFootprintGeneration) -> FamilyFootprintGeneration {
        let playback = Array(displayGenerations.dropFirst())
        guard let index = playback.firstIndex(of: generation) else { return playback.first ?? .ancestors }
        let nextIndex = playback.index(after: index)
        return nextIndex < playback.endIndex ? playback[nextIndex] : .all
    }

    static func generation(for memory: MemoryModel) -> FamilyFootprintGeneration {
        let combined = "\(memory.title) \(memory.subtitle) \(memory.location)"
        return generation(year: memory.year, text: combined)
    }

    static func generation(year: Int, text: String) -> FamilyFootprintGeneration {
        let text = text.lowercased()
        if text.contains("孙") || text.contains("下一代") || text.contains("孩子") || text.contains("留学") || text.contains("温哥华") || text.contains("新加坡") {
            return .next
        }
        if text.contains("爷") || text.contains("奶") || text.contains("外公") || text.contains("外婆") || text.contains("祖") || year <= 1979 {
            return .ancestors
        }
        if text.contains("爸爸") || text.contains("妈妈") || text.contains("父") || text.contains("母") || (1980...1999).contains(year) {
            return .parents
        }
        if year >= 2020 {
            return .next
        }
        return .current
    }

    static func roadshowExpansionPoints() -> [FamilyFootprintPoint] {
        [
            FamilyFootprintPoint(
                id: "roadshow_family_origin_shaoxing",
                title: "绍兴 · 1962年2月",
                subtitle: "陈家老宅门口的第一张全家照，家从这里被记住。",
                location: "绍兴老宅",
                year: 1962,
                month: 2,
                latitude: 30.0303,
                longitude: 120.5802,
                generation: .ancestors,
                ownerName: "陈树安",
                sourceMemoryId: nil,
                isPrivate: false
            ),
            FamilyFootprintPoint(
                id: "roadshow_family_shenzhen",
                title: "深圳 · 2008年8月",
                subtitle: "陈岚第一次带着项目南下，家族地图从江南走向海边。",
                location: "深圳南山",
                year: 2008,
                month: 8,
                latitude: 22.5316,
                longitude: 113.9236,
                generation: .current,
                ownerName: "陈岚",
                sourceMemoryId: nil,
                isPrivate: false
            ),
            FamilyFootprintPoint(
                id: "roadshow_family_vancouver",
                title: "温哥华 · 2025年9月",
                subtitle: "陈予把第一封海外明信片寄回家，世界变大但家仍有坐标。",
                location: "温哥华",
                year: 2025,
                month: 9,
                latitude: 49.2827,
                longitude: -123.1207,
                generation: .next,
                ownerName: "陈予",
                sourceMemoryId: nil,
                isPrivate: false
            )
        ]
    }

    private static func merge(memoryPoints: [FamilyFootprintPoint], demoPoints: [FamilyFootprintPoint]) -> [FamilyFootprintPoint] {
        var result = memoryPoints
        let existingCities = Set(memoryPoints.map { normalizedCityName($0.location) })
        for point in demoPoints where !existingCities.contains(normalizedCityName(point.location)) {
            result.append(point)
        }
        return result.sortedForTimeline()
    }

    private static func normalizedCityName(_ location: String) -> String {
        let knownCities = ["上海", "北京", "南京", "成都", "杭州", "广州", "绍兴", "深圳", "温哥华", "新加坡"]
        return knownCities.first(where: { location.contains($0) }) ?? location
    }

    private static func countryName(latitude: Double, longitude: Double, location: String) -> String {
        if location.contains("温哥华") || longitude < -60 {
            return "加拿大"
        }
        if location.contains("新加坡") {
            return "新加坡"
        }
        return "中国"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    private static func representativeRoute(from cities: [String]) -> String {
        guard cities.count > 3 else {
            return cities.joined(separator: " → ")
        }

        let middleIndex = cities.count / 2
        return [cities.first, cities[middleIndex], cities.last]
            .compactMap { $0 }
            .joined(separator: " → ")
    }
}

private extension Array where Element == FamilyFootprintPoint {
    func sortedForTimeline() -> [FamilyFootprintPoint] {
        sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            if $0.month != $1.month { return $0.month < $1.month }
            return $0.location < $1.location
        }
    }
}
