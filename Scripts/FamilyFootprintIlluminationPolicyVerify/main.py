#!/usr/bin/env python3
from pathlib import Path
import sys

source = Path("DreamJourney/Sources/Modules/Map/FamilyFootprintIllumination.swift").read_text()
provider = Path("DreamJourney/Sources/Modules/Map/AmapDistrictBoundaryProvider.swift").read_text()
timeline = Path("DreamJourney/Sources/Modules/Map/FamilyFootprintTimeline.swift").read_text()

checks = [
    (
        "nation should not fall back to the default city poster when selected generation has only a few points",
        "return defaultNationKeys.compactMap" not in source,
    ),
    (
        "world scope should only include China when visible points map to China",
        'if countries.contains("中国")' in source,
    ),
    (
        "generation lighting should default to raw visible memory points",
        "private static func scriptedRegions" not in source
        and "scriptedStatsText" not in source
        and "usesScriptedFootprintRange\n            ? []" not in Path("DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift").read_text(),
    ),
    (
        "AMap district WebService should request visible point keywords, not scripted generation ranges",
        "scriptedKeywords" not in provider
        and "if let scripted = scriptedKeywords" not in provider,
    ),
    (
        "generation copy should not force the Shaoxing/Zhejiang/Jiangsu-Zhejiang-Shanghai-Guangdong story",
        "scriptedNarrativeText" not in timeline
        and "scriptedJourneySummary" not in timeline
        and "江浙沪广" not in timeline,
    ),
    (
        "real-device footprint timeline should not expose roadshow/demo expansion hooks",
        "includeDemoExpansion" not in timeline
        and "roadshowExpansionPoints" not in timeline
        and "merge(memoryPoints:" not in timeline,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"FamilyFootprintIlluminationPolicy verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("FamilyFootprintIlluminationPolicy verification passed")
