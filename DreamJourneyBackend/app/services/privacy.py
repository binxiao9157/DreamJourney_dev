from copy import deepcopy
from typing import Any, Dict, Iterable, List


SYNCABLE_SCOPES = {"generationAllowed", "familyCircle"}

CARE_SNAPSHOT_SCALAR_KEYS = {
    "generatedAt",
    "windowStart",
    "windowEnd",
    "windowDayCount",
    "dataCoverageSummary",
    "totalTurns",
    "userTurnCount",
    "characterCount",
    "uniqueTokenCount",
    "lexicalDiversity",
    "negativeEmotionMentions",
    "sleepMentions",
    "bodyDiscomfortMentions",
    "repetitionRatio",
    "riskLevel",
    "summary",
    "trendSummary",
}

CARE_SNAPSHOT_STRING_LIST_KEYS = {
    "suggestions",
    "weeklyHighlights",
    "riskSignalDescriptions",
}

CARE_DAILY_TREND_SCALAR_KEYS = {
    "date",
    "userTurnCount",
    "negativeEmotionMentions",
    "sleepMentions",
    "bodyDiscomfortMentions",
    "repetitionRatio",
    "signalScore",
}


def _scope(entity: Dict[str, Any]) -> str:
    metadata = entity.get("privacyMetadata") or {}
    return metadata.get("scope") or "localOnly"


def _is_syncable(entity: Dict[str, Any]) -> bool:
    return _scope(entity) in SYNCABLE_SCOPES


def _filter_ids(values: Iterable[str], allowed: set) -> List[str]:
    return [value for value in values if value in allowed]


def filter_syncable_graph(graph: Dict[str, Any]) -> Dict[str, Any]:
    """Return a backend-safe KBLite graph without localOnly entities."""
    people = [deepcopy(item) for item in graph.get("people", []) if _is_syncable(item)]
    places = [deepcopy(item) for item in graph.get("places", []) if _is_syncable(item)]
    people_ids = {item.get("id") for item in people}
    place_ids = {item.get("id") for item in places}

    events = []
    for event in graph.get("events", []):
        if not _is_syncable(event):
            continue
        copied = deepcopy(event)
        copied["participantIds"] = _filter_ids(copied.get("participantIds", []), people_ids)
        if copied.get("locationId") not in place_ids:
            copied.pop("locationId", None)
        events.append(copied)

    event_ids = {item.get("id") for item in events}
    facts = []
    for fact in graph.get("facts", []):
        if not _is_syncable(fact):
            continue
        copied = deepcopy(fact)
        copied["relatedPersonIds"] = _filter_ids(copied.get("relatedPersonIds", []), people_ids)
        copied["relatedPlaceIds"] = _filter_ids(copied.get("relatedPlaceIds", []), place_ids)
        copied["relatedEventIds"] = _filter_ids(copied.get("relatedEventIds", []), event_ids)
        facts.append(copied)

    return {
        "version": graph.get("version", 1),
        "lastUpdated": graph.get("lastUpdated"),
        "sessionCount": graph.get("sessionCount", 0),
        "people": people,
        "places": places,
        "events": events,
        "facts": facts,
    }


def sanitize_archive_item_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Return backend-safe archive metadata without local files or private scopes."""
    if not _is_syncable(payload):
        raise ValueError("archive item is not syncable")

    item = deepcopy(payload)
    item.pop("localPath", None)
    item.pop("fileURL", None)
    item.pop("absolutePath", None)
    item["metadataOnly"] = True
    return item


def sanitize_mailbox_letter_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Return backend-safe mailbox metadata without full letter or echo text."""
    if not _is_syncable(payload):
        raise ValueError("mailbox letter is not syncable")

    allowed_keys = {
        "id",
        "recipientName",
        "title",
        "createdAt",
        "deliverAt",
        "deliveredAt",
        "status",
        "boundaryAcknowledged",
        "privacyMetadata",
    }
    item = {key: deepcopy(payload[key]) for key in allowed_keys if key in payload}

    item["metadataOnly"] = True
    item["contentRedacted"] = True
    return item


def _is_json_scalar(value: Any) -> bool:
    return value is None or isinstance(value, (str, int, float, bool))


def _string_list(value: Any) -> List[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str)]


def _sanitize_daily_trend(value: Any) -> List[Dict[str, Any]]:
    if not isinstance(value, list):
        return []

    points = []
    for point in value:
        if not isinstance(point, dict):
            continue
        sanitized_point = {
            key: deepcopy(point[key])
            for key in CARE_DAILY_TREND_SCALAR_KEYS
            if key in point and _is_json_scalar(point[key])
        }
        if sanitized_point:
            points.append(sanitized_point)
    return points


def sanitize_care_snapshot_payload(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    """Return backend-safe care dashboard aggregates without raw conversation text."""
    item = {
        key: deepcopy(snapshot[key])
        for key in CARE_SNAPSHOT_SCALAR_KEYS
        if key in snapshot and _is_json_scalar(snapshot[key])
    }

    for key in CARE_SNAPSHOT_STRING_LIST_KEYS:
        if key in snapshot:
            item[key] = _string_list(snapshot[key])

    if "dailyTrend" in snapshot:
        item["dailyTrend"] = _sanitize_daily_trend(snapshot["dailyTrend"])

    item["metadataOnly"] = True
    item["contentRedacted"] = True
    return item
