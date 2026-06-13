import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("CareDashboardSnapshotSelection verification failed: \(message)\n", stderr)
        exit(1)
    }
}

func snapshot(
    userTurns: Int,
    days: Int,
    risk: CareSignalRiskLevel,
    generatedAt: Date = Date(timeIntervalSince1970: 1_781_234_567)
) -> CareSignalSnapshot {
    CareSignalSnapshot(
        generatedAt: generatedAt,
        windowStart: generatedAt.addingTimeInterval(Double(-max(0, days - 1)) * 86_400),
        windowEnd: generatedAt,
        windowDayCount: days,
        dataCoverageSummary: "近 \(days) 天，用户发言 \(userTurns) 轮。",
        totalTurns: userTurns,
        userTurnCount: userTurns,
        characterCount: userTurns * 12,
        uniqueTokenCount: userTurns * 8,
        lexicalDiversity: 0.66,
        negativeEmotionMentions: 0,
        sleepMentions: 0,
        bodyDiscomfortMentions: 0,
        repetitionRatio: 0,
        averageWordsPerMinute: nil,
        slowSpeechTurnCount: nil,
        longPauseTurnCount: nil,
        emotionVolatilityScore: nil,
        riskLevel: risk,
        summary: "summary",
        suggestions: [],
        weeklyHighlights: [],
        riskSignalDescriptions: [],
        dailyTrend: [],
        trendSummary: "trend"
    )
}

let remoteRich = snapshot(userTurns: 18, days: 7, risk: .stable)
let localEmpty = snapshot(userTurns: 0, days: 0, risk: .insufficientData)
let localThin = snapshot(userTurns: 1, days: 1, risk: .stable)
let localRicher = snapshot(userTurns: 20, days: 7, risk: .stable)
let remoteEmpty = snapshot(userTurns: 0, days: 0, risk: .insufficientData)
let remoteNewerButThin = snapshot(
    userTurns: 1,
    days: 1,
    risk: .stable,
    generatedAt: Date(timeIntervalSince1970: 1_781_235_567)
)

require(
    CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: nil, remote: remoteRich),
    "should use remote snapshot when no current snapshot exists"
)
require(
    CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: localEmpty, remote: remoteRich),
    "should use remote snapshot when local has no usable turns"
)
require(
    CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: localThin, remote: remoteRich),
    "should use remote snapshot when it has broader coverage than thin local data"
)
require(
    !CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: localRicher, remote: remoteRich),
    "should keep local snapshot when local has equal coverage and more turns"
)
require(
    !CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: localThin, remote: remoteEmpty),
    "should not use empty remote snapshot"
)
require(
    !CareDashboardSnapshotSelectionPolicy.shouldPreferRemote(current: localThin, remote: remoteNewerButThin),
    "should not replace local data only because remote generatedAt is newer"
)

print("CareDashboardSnapshotSelection verification passed")
