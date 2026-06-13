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
        "generation lighting should use fixed product ranges instead of raw memory-point spread",
        'case .ancestors:' in source
        and 'name: "绍兴"' in source
        and 'case .parents:' in source
        and 'name: "浙江"' in source
        and 'case .current:' in source
        and 'jiangzhehuguangRegions' in source
        and 'name: "下一代暂定区域"' in source
        and '.futureFill' in source,
    ),
    (
        "AMap district WebService should request the same scripted generation ranges",
        'case .ancestors:' in provider
        and 'return ["绍兴市"]' in provider
        and 'case .parents:' in provider
        and 'return ["浙江省"]' in provider
        and 'return ["江苏省", "浙江省", "上海市", "广东省"]' in provider
        and 'case .next:' in provider
        and 'return []' in provider,
    ),
    (
        "generation copy should match the Shaoxing/Zhejiang/Jiangsu-Zhejiang-Shanghai-Guangdong story",
        "祖辈守着绍兴老家的根" in timeline
        and "父辈把生活半径铺到浙江" in timeline
        and "我们走到江浙沪广" in timeline
        and "下一代的地图先留一片灰色" in timeline,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"FamilyFootprintIlluminationPolicy verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("FamilyFootprintIlluminationPolicy verification passed")
