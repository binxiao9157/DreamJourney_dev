import os
import unittest

from fastapi.testclient import TestClient

from app.main import app
from app.core.config import Settings
from app.services.in_memory_store import InMemoryStore
from app.services.postgres_store import PostgresStore
from app.services.privacy import filter_syncable_graph
from app.services.runtime_config import RuntimeConfigService
from app.services.store_factory import make_store
from app.services.tokens import TokenService
from app.services.tts import VolcTTSProxy
from app.services.amap import AMapDistrictProxy


class PrivacyFilteringTests(unittest.TestCase):
    def test_backend_sync_filters_local_only_entities(self):
        graph = {
            "people": [
                {"id": "p1", "name": "测试用户", "privacyMetadata": {"scope": "generationAllowed"}},
                {"id": "p2", "name": "林桂芳", "privacyMetadata": {"scope": "localOnly"}},
            ],
            "places": [
                {"id": "l1", "name": "绍兴", "privacyMetadata": {"scope": "familyCircle"}},
                {"id": "l2", "name": "私密地址", "privacyMetadata": {"scope": "localOnly"}},
            ],
            "events": [
                {
                    "id": "e1",
                    "title": "开照相馆",
                    "participantIds": ["p1", "p2"],
                    "locationId": "l1",
                    "privacyMetadata": {"scope": "generationAllowed"},
                }
            ],
            "facts": [
                {
                    "id": "f1",
                    "statement": "可同步事实",
                    "relatedPersonIds": ["p1", "p2"],
                    "relatedPlaceIds": ["l1", "l2"],
                    "relatedEventIds": ["e1"],
                    "privacyMetadata": {"scope": "generationAllowed"},
                },
                {"id": "f2", "statement": "本机事实", "privacyMetadata": {"scope": "localOnly"}},
            ],
        }

        filtered = filter_syncable_graph(graph)

        self.assertEqual([p["id"] for p in filtered["people"]], ["p1"])
        self.assertEqual([p["id"] for p in filtered["places"]], ["l1"])
        self.assertEqual(filtered["events"][0]["participantIds"], ["p1"])
        self.assertEqual(filtered["facts"][0]["relatedPersonIds"], ["p1"])
        self.assertEqual(filtered["facts"][0]["relatedPlaceIds"], ["l1"])
        self.assertEqual([f["id"] for f in filtered["facts"]], ["f1"])


class RuntimeConfigTests(unittest.TestCase):
    def test_runtime_config_exposes_capabilities_not_secrets(self):
        settings = Settings(
            deepseek_api_key="deepseek-secret",
            volcengine_api_key="volc-secret",
            volcengine_voice_type="zh_female_cancan_mars_bigtts",
            amap_web_service_key="amap-secret",
        )
        config = RuntimeConfigService(settings).public_config()

        serialized = str(config)
        self.assertNotIn("deepseek-secret", serialized)
        self.assertNotIn("volc-secret", serialized)
        self.assertNotIn("amap-secret", serialized)
        self.assertTrue(config["capabilities"]["deepseekProxy"])
        self.assertTrue(config["capabilities"]["ttsProxy"])
        self.assertEqual(config["voice"]["voiceType"], "zh_female_cancan_mars_bigtts")


class TokenAndProxyTests(unittest.TestCase):
    def test_realtime_token_uses_legacy_credentials_without_exposing_app_token(self):
        settings = Settings(
            volcengine_app_id="test-app-id",
            volcengine_app_key="PlgvMymc7f3tQnJ6",
            volcengine_app_token="access-token-secret",
        )

        payload = TokenService(settings).realtime_config(user_id="u1")

        self.assertEqual(payload["authMode"], "legacy")
        self.assertEqual(payload["headers"]["X-Api-App-ID"], "test-app-id")
        self.assertEqual(payload["headers"]["X-Api-App-Key"], "PlgvMymc7f3tQnJ6")
        self.assertNotIn("access-token-secret", str(payload))
        self.assertIn("tokenRef", payload)

    def test_tts_proxy_builds_volcengine_request(self):
        settings = Settings(
            volcengine_api_key="volc-secret",
            volcengine_voice_type="speaker-id",
        )
        proxy = VolcTTSProxy(settings)

        request = proxy.build_request(text="你好", user_id="u1")

        self.assertEqual(request["url"], "https://openspeech.bytedance.com/api/v1/tts")
        self.assertEqual(request["headers"]["x-api-key"], "volc-secret")
        self.assertEqual(request["json"]["audio"]["voice_type"], "speaker-id")
        self.assertEqual(request["json"]["request"]["text"], "你好")

    def test_amap_proxy_adds_server_side_key(self):
        settings = Settings(amap_web_service_key="amap-secret")
        proxy = AMapDistrictProxy(settings)

        url = proxy.build_url(keyword="绍兴市")

        self.assertIn("key=amap-secret", url)
        self.assertIn("keywords=", url)
        self.assertIn("%E7%BB%8D%E5%85%B4%E5%B8%82", url)


class StoreTests(unittest.TestCase):
    def test_store_factory_uses_postgres_by_default(self):
        store = make_store(Settings(database_url="postgresql://example"))

        self.assertIsInstance(store, PostgresStore)

    def test_store_factory_allows_explicit_memory_backend(self):
        store = make_store(Settings(store_backend="memory"))

        self.assertIsInstance(store, InMemoryStore)

    def test_store_keeps_user_snapshots_separate(self):
        store = InMemoryStore()

        store.save_kb_snapshot("u1", {"people": [{"id": "p1"}]})
        store.save_kb_snapshot("u2", {"people": [{"id": "p2"}]})

        self.assertEqual(store.get_kb_snapshot("u1")["people"][0]["id"], "p1")
        self.assertEqual(store.get_kb_snapshot("u2")["people"][0]["id"], "p2")

    def test_store_keeps_latest_care_snapshot_by_user_and_viewer(self):
        store = InMemoryStore()

        all_family = store.save_care_snapshot(
            "u1",
            {"riskLevel": "stable", "summary": "全家视角"},
            viewer_family_member_id=None,
        )
        daughter = store.save_care_snapshot(
            "u1",
            {"riskLevel": "watch", "summary": "女儿视角"},
            viewer_family_member_id="fm_daughter",
        )

        self.assertEqual(all_family["snapshot"]["summary"], "全家视角")
        self.assertEqual(daughter["viewerFamilyMemberID"], "fm_daughter")
        self.assertEqual(store.get_latest_care_snapshot("u1")["snapshot"]["summary"], "全家视角")
        self.assertEqual(
            store.get_latest_care_snapshot("u1", viewer_family_member_id="fm_daughter")["snapshot"]["summary"],
            "女儿视角",
        )
        self.assertEqual(
            [item["snapshot"]["summary"] for item in store.list_care_snapshots("u1", limit=10)],
            ["全家视角"],
        )
        self.assertEqual(
            [item["snapshot"]["summary"] for item in store.list_care_snapshots("u1", viewer_family_member_id="fm_daughter", limit=10)],
            ["女儿视角"],
        )
        self.assertIsNone(store.get_latest_care_snapshot("u2"))

    def test_store_marks_family_member_revoked(self):
        store = InMemoryStore()

        member = store.add_family_member("u1", {"name": "陈岚", "phone": "13900001111"})
        revoked = store.revoke_family_member("u1", member["id"])

        self.assertEqual(revoked["accessStatus"], "revoked")
        self.assertEqual(revoked["invitationStatus"], "revoked")
        self.assertFalse(revoked["isOnline"])
        self.assertIn("revokedAt", revoked)
        self.assertEqual(store.list_family_members("u1")[0]["accessStatus"], "revoked")

    def test_store_marks_family_member_accepted(self):
        store = InMemoryStore()

        member = store.add_family_member("u1", {"name": "陈岚", "phone": "13900001111"})
        accepted = store.accept_family_member("u1", member["id"], phone="13900001111")

        self.assertEqual(accepted["accessStatus"], "active")
        self.assertEqual(accepted["invitationStatus"], "accepted")
        self.assertTrue(accepted["isOnline"])
        self.assertIn("acceptedAt", accepted)
        self.assertEqual(store.list_family_members("u1")[0]["invitationStatus"], "accepted")

    def test_store_lists_archive_items_by_user(self):
        store = InMemoryStore()

        old_item = store.add_archive_item(
            "u1",
            {
                "id": "archive-old",
                "kind": "textNote",
                "title": "旧记录",
                "privacyMetadata": {"scope": "generationAllowed"},
            },
        )
        new_item = store.add_archive_item(
            "u1",
            {
                "id": "archive-new",
                "kind": "voiceSample",
                "title": "语音样本",
                "privacyMetadata": {"scope": "generationAllowed"},
            },
        )
        store.add_archive_item(
            "u2",
            {
                "id": "archive-other",
                "kind": "textNote",
                "title": "其他用户",
                "privacyMetadata": {"scope": "generationAllowed"},
            },
        )

        self.assertEqual(old_item["userId"], "u1")
        self.assertEqual([item["id"] for item in store.list_archive_items("u1")], ["archive-new", "archive-old"])
        self.assertEqual([item["id"] for item in store.list_archive_items("u2")], ["archive-other"])

    def test_store_lists_mailbox_letters_by_user(self):
        store = InMemoryStore()

        store.add_mailbox_letter("u1", {"id": "letter_1", "title": "第一封", "privacyMetadata": {"scope": "familyCircle"}})
        store.add_mailbox_letter("u1", {"id": "letter_2", "title": "第二封", "privacyMetadata": {"scope": "generationAllowed"}})
        store.add_mailbox_letter("u2", {"id": "letter_3", "title": "其他用户", "privacyMetadata": {"scope": "familyCircle"}})
        store.add_mailbox_letter("u1", {"id": "letter_1", "title": "第一封已读", "status": "read", "privacyMetadata": {"scope": "familyCircle"}})

        self.assertEqual([item["title"] for item in store.list_mailbox_letters("u1")], ["第一封已读", "第二封"])
        self.assertEqual(store.list_mailbox_letters("u1")[0]["status"], "read")
        self.assertEqual([item["title"] for item in store.list_mailbox_letters("u2")], ["其他用户"])


class CareSnapshotAPITests(unittest.TestCase):
    def test_care_snapshot_api_saves_and_returns_latest_by_viewer(self):
        client = TestClient(app)

        all_family = client.post(
            "/care/snapshots",
            json={
                "userId": "care_user_1",
                "snapshot": {"riskLevel": "stable", "summary": "全家视角"},
            },
        )
        daughter = client.post(
            "/care/snapshots",
            json={
                "userId": "care_user_1",
                "viewerFamilyMemberID": "fm_daughter",
                "snapshot": {"riskLevel": "watch", "summary": "女儿视角"},
            },
        )

        self.assertEqual(all_family.status_code, 200)
        self.assertEqual(daughter.status_code, 200)
        self.assertEqual(daughter.json()["item"]["viewerFamilyMemberID"], "fm_daughter")

        latest_all = client.get("/care/snapshots/latest/care_user_1")
        latest_daughter = client.get(
            "/care/snapshots/latest/care_user_1",
            params={"viewerFamilyMemberID": "fm_daughter"},
        )

        self.assertEqual(latest_all.status_code, 200)
        self.assertEqual(latest_all.json()["item"]["snapshot"]["summary"], "全家视角")
        self.assertEqual(latest_daughter.status_code, 200)
        self.assertEqual(latest_daughter.json()["item"]["snapshot"]["summary"], "女儿视角")

    def test_care_snapshot_api_404_for_missing_user(self):
        client = TestClient(app)

        response = client.get("/care/snapshots/latest/missing_user")

        self.assertEqual(response.status_code, 404)

    def test_care_snapshot_history_api_returns_recent_snapshots_by_viewer(self):
        client = TestClient(app)

        for index in range(3):
            response = client.post(
                "/care/snapshots",
                json={
                    "userId": "care_history_user",
                    "viewerFamilyMemberID": "fm_daughter",
                    "snapshot": {"riskLevel": "watch", "summary": f"女儿视角 {index}"},
                },
            )
            self.assertEqual(response.status_code, 200)
        client.post(
            "/care/snapshots",
            json={
                "userId": "care_history_user",
                "snapshot": {"riskLevel": "stable", "summary": "全家视角"},
            },
        )

        history = client.get(
            "/care/snapshots/care_history_user",
            params={"viewerFamilyMemberID": "fm_daughter", "limit": 2},
        )
        all_family_history = client.get("/care/snapshots/care_history_user", params={"limit": 10})

        self.assertEqual(history.status_code, 200)
        self.assertEqual(history.json()["items"][0]["snapshot"]["summary"], "女儿视角 2")
        self.assertEqual(len(history.json()["items"]), 2)
        self.assertEqual(all_family_history.status_code, 200)
        self.assertEqual([item["snapshot"]["summary"] for item in all_family_history.json()["items"]], ["全家视角"])


class ArchiveAPITests(unittest.TestCase):
    def test_archive_items_api_saves_sanitized_metadata_and_lists_by_user(self):
        client = TestClient(app)

        created = client.post(
            "/archive/items",
            json={
                "userId": "archive_user_1",
                "id": "archive-text-1",
                "kind": "textNote",
                "title": "仓桥直街",
                "note": "1968 年住在绍兴越城区仓桥直街。",
                "localPath": "/private/var/mobile/archive_photo.jpg",
                "privacyMetadata": {"scope": "generationAllowed"},
            },
        )
        listed = client.get("/archive/items/archive_user_1")

        self.assertEqual(created.status_code, 200)
        item = created.json()["item"]
        self.assertEqual(item["id"], "archive-text-1")
        self.assertEqual(item["title"], "仓桥直街")
        self.assertNotIn("localPath", item)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(listed.json()["items"][0]["id"], "archive-text-1")
        self.assertNotIn("localPath", listed.json()["items"][0])

    def test_archive_items_api_rejects_private_or_local_items(self):
        client = TestClient(app)

        private_response = client.post(
            "/archive/items",
            json={
                "userId": "archive_user_2",
                "id": "archive-private",
                "kind": "textNote",
                "title": "私密素材",
                "privacyMetadata": {"scope": "privateOnly"},
            },
        )
        local_response = client.post(
            "/archive/items",
            json={
                "userId": "archive_user_2",
                "id": "archive-local",
                "kind": "textNote",
                "title": "本机素材",
                "privacyMetadata": {"scope": "localOnly"},
            },
        )

        self.assertEqual(private_response.status_code, 403)
        self.assertEqual(local_response.status_code, 403)


class MailboxAPITests(unittest.TestCase):
    def test_mailbox_letters_api_saves_sanitized_metadata_and_lists_by_user(self):
        client = TestClient(app)

        response = client.post(
            "/mailbox/letters",
            json={
                "userId": "mailbox_user",
                "id": "letter_sync_1",
                "recipientName": "林桂芳",
                "title": "想说的话",
                "body": "这是一封完整正文，应该只留短预览，不应该完整返回。",
                "bodyPreview": "这是一封完整正文",
                "replyText": "不是逝者真实回复，但这段回声不应同步。",
                "createdAt": "2026-06-13T00:00:00Z",
                "deliverAt": "2026-06-14T00:00:00Z",
                "status": "sealed",
                "boundaryAcknowledged": True,
                "privacyMetadata": {"scope": "generationAllowed"},
            },
        )
        self.assertEqual(response.status_code, 200)
        item = response.json()["item"]
        self.assertEqual(item["id"], "letter_sync_1")
        self.assertEqual(item["bodyPreview"], "这是一封完整正文")
        self.assertTrue(item["metadataOnly"])
        self.assertTrue(item["contentRedacted"])
        self.assertNotIn("body", item)
        self.assertNotIn("replyText", item)

        listed = client.get("/mailbox/letters/mailbox_user")
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(listed.json()["items"][0]["id"], "letter_sync_1")
        self.assertNotIn("body", listed.json()["items"][0])

    def test_mailbox_letters_api_rejects_private_or_local_letters(self):
        client = TestClient(app)

        for scope in ["localOnly", "privateOnly"]:
            response = client.post(
                "/mailbox/letters",
                json={
                    "userId": "mailbox_private_user",
                    "id": f"letter_{scope}",
                    "recipientName": "林桂芳",
                    "title": "私密信件",
                    "body": "不应离开本机",
                    "privacyMetadata": {"scope": scope},
                },
            )
            self.assertEqual(response.status_code, 403)


class FamilyAPITests(unittest.TestCase):
    def test_family_member_accept_api_marks_member_active(self):
        client = TestClient(app)

        created = client.post(
            "/family/invite",
            json={
                "userId": "u1",
                "name": "陈岚",
                "relation": "女儿",
                "phone": "13900001111",
            },
        )
        member_id = created.json()["member"]["id"]
        accepted = client.post(
            f"/family/members/u1/{member_id}/accept",
            json={"phone": "13900001111"},
        )
        listed = client.get("/family/members/u1")

        self.assertEqual(created.status_code, 200)
        self.assertEqual(accepted.status_code, 200)
        self.assertEqual(accepted.json()["member"]["accessStatus"], "active")
        self.assertEqual(accepted.json()["member"]["invitationStatus"], "accepted")
        self.assertIn("acceptedAt", accepted.json()["member"])
        listed_member = next(item for item in listed.json()["members"] if item["id"] == member_id)
        self.assertEqual(listed_member["invitationStatus"], "accepted")

    def test_family_member_revoke_api_marks_member_revoked(self):
        client = TestClient(app)

        created = client.post(
            "/family/invite",
            json={
                "userId": "u1",
                "name": "陈岚",
                "relation": "女儿",
                "phone": "13900001111",
            },
        )
        member_id = created.json()["member"]["id"]
        revoked = client.post(f"/family/members/u1/{member_id}/revoke")
        listed = client.get("/family/members/u1")

        self.assertEqual(created.status_code, 200)
        self.assertEqual(revoked.status_code, 200)
        self.assertEqual(revoked.json()["member"]["accessStatus"], "revoked")
        self.assertEqual(revoked.json()["member"]["invitationStatus"], "revoked")
        self.assertIn("revokedAt", revoked.json()["member"])
        listed_member = next(item for item in listed.json()["members"] if item["id"] == member_id)
        self.assertEqual(listed_member["accessStatus"], "revoked")


if __name__ == "__main__":
    unittest.main()
