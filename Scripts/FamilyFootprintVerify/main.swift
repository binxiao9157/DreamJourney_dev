import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FamilyFootprint verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let memories = [
    MemoryModel(
        id: "verify_ancestor",
        title: "上海 · 1975年7月",
        subtitle: "外公结婚纪念日，全家在外滩合影",
        location: "上海外滩",
        year: 1975,
        month: 7,
        latitude: 31.2397,
        longitude: 121.4901,
        authorId: "user_001"
    ),
    MemoryModel(
        id: "verify_parent",
        title: "北京 · 1988年10月",
        subtitle: "爸爸第一次去北京出差",
        location: "北京故宫",
        year: 1988,
        month: 10,
        latitude: 39.9163,
        longitude: 116.3972,
        authorId: "user_001"
    ),
    MemoryModel(
        id: "verify_current",
        title: "深圳 · 2008年8月",
        subtitle: "陈岚第一次带着项目南下",
        location: "深圳南山",
        year: 2008,
        month: 8,
        latitude: 22.5316,
        longitude: 113.9236,
        authorId: "user_001"
    ),
    MemoryModel(
        id: "verify_next",
        title: "温哥华 · 2025年9月",
        subtitle: "孩子把第一封海外明信片寄回家",
        location: "温哥华",
        year: 2025,
        month: 9,
        latitude: 49.2827,
        longitude: -123.1207,
        authorId: "user_001"
    )
]

let points = FamilyFootprintTimeline.points(from: memories, ownerName: "陈家", includeDemoExpansion: false)
require(points.first?.year == 1975, "real-only timeline should not inject roadshow origin")
require(!points.contains { $0.location == "绍兴老宅" }, "real-only timeline should not include demo expansion")
require(points.contains { $0.location == "温哥华" }, "next generation should include larger world point")
require(!FamilyFootprintGeneration.ancestors.usesScriptedFootprintRange, "generation lighting should default to real memory points")
require(!FamilyFootprintGeneration.parents.usesScriptedFootprintRange, "parent lighting should default to real memory points")
require(!FamilyFootprintGeneration.current.usesScriptedFootprintRange, "current lighting should default to real memory points")
require(!FamilyFootprintGeneration.all.usesScriptedFootprintRange, "family lighting should default to real memory points")
require(FamilyFootprintTimeline.filtered(points, by: .ancestors).allSatisfy { $0.generation == .ancestors }, "ancestor filter leaked other generations")
require(FamilyFootprintTimeline.filtered(points, by: .parents).contains { $0.location == "北京故宫" }, "parent generation should include 1988 Beijing")
require(FamilyFootprintTimeline.filtered(points, by: .current).contains { $0.location == "深圳南山" }, "current generation should include 2008 Shenzhen")
require(FamilyFootprintTimeline.filtered(points, by: .next).contains { $0.location == "温哥华" }, "next generation should include Vancouver")

let stats = FamilyFootprintTimeline.statsText(for: points, generation: .all, isGuest: false)
require(stats.contains("全家足迹"), "stats should name family footprint")
require(stats.contains("跨越"), "stats should include year span")

let narrative = FamilyFootprintTimeline.narrativeText(for: points, generation: .all)
require(narrative.contains("上海") || narrative.contains("外滩"), "narrative should derive from first real memory location")
require(narrative.contains("温哥华"), "narrative should derive from latest real memory location")
require(!narrative.contains("江浙沪广"), "narrative should not force scripted generation range")

let journeySummary = FamilyFootprintTimeline.journeySummary(for: points, generation: .all)
require(journeySummary.routeText.contains("上海"), "journey summary should include first real city")
require(journeySummary.routeText.contains("北京"), "journey summary should include parent real city")
require(journeySummary.routeText.contains("深圳"), "journey summary should include current real city")
require(journeySummary.routeText.contains("温哥华"), "journey summary should include next real city")
require(journeySummary.detailText.contains("4 座城"), "journey summary should count real cities")
require(!journeySummary.routeText.contains("江浙沪广"), "journey summary should not force scripted generation range")

let parentJourneySummary = FamilyFootprintTimeline.journeySummary(for: points, generation: .parents)
require(parentJourneySummary.routeText.contains("北京"), "parent journey summary should use real parent point")
require(!parentJourneySummary.routeText.contains("浙江"), "parent journey summary should not force Zhejiang when real data says Beijing")

let currentJourneySummary = FamilyFootprintTimeline.journeySummary(for: points, generation: .current)
require(currentJourneySummary.routeText.contains("深圳"), "current journey summary should use real current point")
require(!currentJourneySummary.routeText.contains("江苏"), "current journey summary should not force Jiangsu")

let nextJourneySummary = FamilyFootprintTimeline.journeySummary(for: points, generation: .next)
require(nextJourneySummary.routeText.contains("温哥华"), "next journey summary should use real next point when available")

require(FamilyFootprintTimeline.nextPlaybackGeneration(after: .ancestors) == .parents, "playback should move ancestors to parents")
require(FamilyFootprintTimeline.nextPlaybackGeneration(after: .next) == .all, "playback should return to all after next")

print("FamilyFootprint verification passed")
