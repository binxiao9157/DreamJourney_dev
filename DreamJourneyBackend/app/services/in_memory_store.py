from copy import deepcopy
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


class InMemoryStore:
    def __init__(self):
        self._users: Dict[str, Dict[str, Any]] = {}
        self._kb_snapshots: Dict[str, Dict[str, Any]] = {}
        self._memories: Dict[str, List[Dict[str, Any]]] = {}
        self._archive_items: Dict[str, List[Dict[str, Any]]] = {}
        self._family_members: Dict[str, List[Dict[str, Any]]] = {}
        self._care_snapshots: Dict[str, List[Dict[str, Any]]] = {}

    def upsert_user(self, phone: str, nickname: str) -> Dict[str, Any]:
        user_id = f"user_{phone[-4:]}" if phone else f"user_{len(self._users) + 1}"
        user = {
            "id": user_id,
            "phone": phone,
            "nickname": nickname or "寻梦环游用户",
            "updatedAt": self._now(),
        }
        self._users[user_id] = user
        return deepcopy(user)

    def save_kb_snapshot(self, user_id: str, graph: Dict[str, Any]) -> Dict[str, Any]:
        snapshot = {
            "userId": user_id,
            "graph": deepcopy(graph),
            "updatedAt": self._now(),
        }
        self._kb_snapshots[user_id] = snapshot
        return deepcopy(snapshot)

    def get_kb_snapshot(self, user_id: str) -> Optional[Dict[str, Any]]:
        snapshot = self._kb_snapshots.get(user_id)
        if snapshot is None:
            return None
        return deepcopy(snapshot["graph"])

    def add_memory(self, user_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        item = deepcopy(payload)
        item.setdefault("id", f"memory_{len(self._memories.get(user_id, [])) + 1}")
        item["userId"] = user_id
        item["createdAt"] = self._now()
        self._memories.setdefault(user_id, []).insert(0, item)
        return deepcopy(item)

    def list_memories(self, user_id: str) -> List[Dict[str, Any]]:
        return deepcopy(self._memories.get(user_id, []))

    def add_archive_item(self, user_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        item = deepcopy(payload)
        item.setdefault("id", f"archive_{len(self._archive_items.get(user_id, [])) + 1}")
        item["userId"] = user_id
        item["createdAt"] = self._now()
        self._archive_items.setdefault(user_id, []).insert(0, item)
        return deepcopy(item)

    def add_family_member(self, user_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        item = deepcopy(payload)
        item.setdefault("id", f"family_{len(self._family_members.get(user_id, [])) + 1}")
        item["userId"] = user_id
        item["createdAt"] = self._now()
        self._family_members.setdefault(user_id, []).append(item)
        return deepcopy(item)

    def list_family_members(self, user_id: str) -> List[Dict[str, Any]]:
        return deepcopy(self._family_members.get(user_id, []))

    def revoke_family_member(self, user_id: str, member_id: str) -> Optional[Dict[str, Any]]:
        members = self._family_members.get(user_id, [])
        for index, item in enumerate(members):
            if item.get("id") != member_id:
                continue
            revoked = deepcopy(item)
            revoked["accessStatus"] = "revoked"
            revoked["invitationStatus"] = "revoked"
            revoked["isOnline"] = False
            revoked["revokedAt"] = self._now()
            revoked["lastUpdated"] = "访问已撤回"
            members[index] = revoked
            return deepcopy(revoked)
        return None

    def save_care_snapshot(
        self,
        user_id: str,
        snapshot: Dict[str, Any],
        viewer_family_member_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        item = {
            "id": f"care_{len(self._care_snapshots.get(user_id, [])) + 1}",
            "userId": user_id,
            "viewerFamilyMemberID": viewer_family_member_id,
            "snapshot": deepcopy(snapshot),
            "createdAt": self._now(),
        }
        self._care_snapshots.setdefault(user_id, []).insert(0, item)
        return deepcopy(item)

    def get_latest_care_snapshot(
        self,
        user_id: str,
        viewer_family_member_id: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        snapshots = self._care_snapshots.get(user_id, [])
        for item in snapshots:
            if item.get("viewerFamilyMemberID") == viewer_family_member_id:
                return deepcopy(item)
        return None

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat()
