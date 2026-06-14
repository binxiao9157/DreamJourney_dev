#!/usr/bin/env python3
import json
import os
import sys
import uuid


os.environ["STORE_BACKEND"] = "memory"
os.environ["BACKEND_API_TOKEN"] = ""

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


RAW_SENTINEL = "CARE_TRUE_BACKEND_RAW_SENTINEL"


def fail(message: str) -> None:
    print(f"CareDashboardTrueBackendFlow verification failed: {message}", file=sys.stderr)
    sys.exit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_status(response, expected: int, context: str) -> None:
    if response.status_code != expected:
        fail(f"{context}: expected HTTP {expected}, got {response.status_code}: {response.text}")


def serialized(payload) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True)


def care_snapshot(summary: str, risk_level: str = "watch") -> dict:
    return {
        "generatedAt": "2026-06-13T10:00:00Z",
        "windowStart": "2026-06-07T00:00:00Z",
        "windowEnd": "2026-06-13T10:00:00Z",
        "windowDayCount": 7,
        "dataCoverageSummary": "近 7 天 6 轮授权对话",
        "totalTurns": 12,
        "userTurnCount": 6,
        "characterCount": 196,
        "uniqueTokenCount": 56,
        "lexicalDiversity": 0.62,
        "negativeEmotionMentions": 1,
        "sleepMentions": 2,
        "bodyDiscomfortMentions": 1,
        "repetitionRatio": 0.18,
        "averageWordsPerMinute": 82.5,
        "slowSpeechTurnCount": 1,
        "longPauseTurnCount": 2,
        "emotionVolatilityScore": 0.31,
        "riskLevel": risk_level,
        "summary": summary,
        "suggestions": ["今晚主动电话问候，确认睡眠和身体情况。"],
        "weeklyHighlights": ["近 7 天提到睡眠和身体不适。"],
        "riskSignalDescriptions": ["睡眠信号 2 次，长停顿 2 次。"],
        "dailyTrend": [
            {
                "date": "2026-06-13T00:00:00Z",
                "userTurnCount": 6,
                "negativeEmotionMentions": 1,
                "sleepMentions": 2,
                "bodyDiscomfortMentions": 1,
                "repetitionRatio": 0.18,
                "averageWordsPerMinute": 82.5,
                "slowSpeechTurnCount": 1,
                "longPauseTurnCount": 2,
                "emotionVolatilityScore": 0.31,
                "signalScore": 5,
                "rawText": RAW_SENTINEL,
            }
        ],
        "trendSummary": "睡眠和长停顿信号较集中。",
        "rawTranscript": RAW_SENTINEL,
        "messages": [{"role": "user", "text": RAW_SENTINEL}],
        "sourceTexts": [RAW_SENTINEL],
    }


client = TestClient(app)
user_id = f"care_true_backend_owner_{uuid.uuid4().hex}"
phone = "13900001111"

invite = client.post(
    "/family/invite",
    json={
        "userId": user_id,
        "name": "陈岚",
        "relation": "女儿",
        "phone": phone,
    },
)
require_status(invite, 200, "family invite")
member = invite.json()["member"]
member_id = member["id"]
invitation_code = member["invitationCode"]
require(invitation_code, "family invite should return invitation code")
require(member["accessStatus"] == "pending", "new family member should start pending")

pending_latest = client.get(
    f"/care/snapshots/latest/{user_id}",
    params={"viewerFamilyMemberID": member_id},
)
require_status(pending_latest, 403, "pending family member should not read care snapshots")

accepted = client.post(
    f"/family/invitations/{invitation_code}/accept",
    json={"phone": phone},
)
require_status(accepted, 200, "invitation-code accept")
accepted_member = accepted.json()["member"]
require(accepted_member["id"] == member_id, "accepted invitation should keep member id")
require(accepted_member["accessStatus"] == "active", "accepted member should be active")
require(accepted_member["invitationStatus"] == "accepted", "accepted member should be accepted")

save_all = client.post(
    "/care/snapshots",
    json={
        "userId": user_id,
        "snapshot": care_snapshot("全家聚合视角：近 7 天有轻微信号。", risk_level="stable"),
    },
)
require_status(save_all, 200, "all-family care snapshot save")

save_member = client.post(
    "/care/snapshots",
    json={
        "userId": user_id,
        "viewerFamilyMemberID": member_id,
        "snapshot": care_snapshot("女儿视角：建议今晚主动电话问候。", risk_level="watch"),
    },
)
require_status(save_member, 200, "member care snapshot save")

latest_all = client.get(f"/care/snapshots/latest/{user_id}")
latest_member = client.get(
    f"/care/snapshots/latest/{user_id}",
    params={"viewerFamilyMemberID": member_id},
)
history_member = client.get(
    f"/care/snapshots/{user_id}",
    params={"viewerFamilyMemberID": member_id, "limit": 7},
)
require_status(latest_all, 200, "all-family latest care snapshot")
require_status(latest_member, 200, "member latest care snapshot")
require_status(history_member, 200, "member care snapshot history")

require(
    latest_all.json()["item"]["snapshot"]["summary"].startswith("全家聚合视角"),
    "all-family latest should not be replaced by member-specific snapshot",
)
member_snapshot = latest_member.json()["item"]["snapshot"]
require(member_snapshot["summary"].startswith("女儿视角"), "member latest should return member-specific snapshot")
require(member_snapshot["metadataOnly"] is True, "care snapshot should be marked metadata-only")
require(member_snapshot["contentRedacted"] is True, "care snapshot should be marked redacted")
require(len(history_member.json()["items"]) == 1, "member history should return saved member-specific snapshot")

combined_responses = serialized({
    "save_all": save_all.json(),
    "save_member": save_member.json(),
    "latest_all": latest_all.json(),
    "latest_member": latest_member.json(),
    "history_member": history_member.json(),
})
require(RAW_SENTINEL not in combined_responses, "raw conversation sentinel should not appear in care responses")
require("rawTranscript" not in combined_responses, "raw transcript field should be stripped")
require("messages" not in combined_responses, "raw messages field should be stripped")
require("sourceTexts" not in combined_responses, "raw source texts field should be stripped")
require("rawText" not in combined_responses, "raw daily trend text should be stripped")

revoked = client.post(f"/family/members/{user_id}/{member_id}/revoke")
require_status(revoked, 200, "family member revoke")
require(revoked.json()["member"]["accessStatus"] == "revoked", "revoked member should lose active access")

revoked_write = client.post(
    "/care/snapshots",
    json={
        "userId": user_id,
        "viewerFamilyMemberID": member_id,
        "snapshot": care_snapshot("撤回后不应保存。"),
    },
)
revoked_latest = client.get(
    f"/care/snapshots/latest/{user_id}",
    params={"viewerFamilyMemberID": member_id},
)
revoked_history = client.get(
    f"/care/snapshots/{user_id}",
    params={"viewerFamilyMemberID": member_id},
)
require_status(revoked_write, 403, "revoked family member should not write care snapshot")
require_status(revoked_latest, 403, "revoked family member should not read latest care snapshot")
require_status(revoked_history, 403, "revoked family member should not read care history")

print("CareDashboardTrueBackendFlow verification passed")
