from datetime import timedelta

from app import clock

from .conftest import member, state


def freeze(client, user="senior", trigger="LONG_PRESS", intensity=None):
    return client.post(
        "/api/v1/security/sos-freeze",
        json={"user_id": user, "trigger_type": trigger, "sensor_intensity": intensity},
    )


def test_long_press_freezes_every_linked_account_for_24_hours(client):
    r = freeze(client)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "SUCCESS"
    assert body["frozen_accounts_count"] == 2
    assert body["guardian_notified"] is True
    expires = clock.now() + timedelta(hours=24)
    assert body["freeze_expires_at"].startswith(expires.isoformat()[:16])

    senior = member(state(client), "senior")
    assert senior["is_frozen"] is True
    assert all(a["withdrawal_blocked"] for a in senior["accounts"])
    assert senior["ledger"][0]["title"] == "SOS 계좌 동결"
    assert senior["ledger"][0]["desc"].startswith("길게 누르기")

    channels = [log["channel"] for log in client.get("/api/v1/integrations/logs").json()["logs"]]
    assert {"OPEN_BANKING", "FCM", "SMS"} <= set(channels)


def test_spec_alias_and_shake_trigger(client):
    r = client.post("/api/v1/emergency/freeze", json={"user_id": "child", "trigger_type": "SHAKE_MOTION", "sensor_intensity": 2.8})
    assert r.status_code == 200
    child = member(state(client), "child")
    assert child["frozen_source"] == "SHAKE_MOTION"
    assert "흔들기" in child["ledger"][0]["desc"]


def test_second_freeze_reports_already_frozen(client):
    freeze(client)
    again = freeze(client).json()
    assert again["already_frozen"] is True


def test_frozen_account_blocks_transfers_and_payments(client):
    freeze(client)
    r = client.post("/api/v1/transaction/transfer", json={"member_id": "senior", "contact_id": "c-sarang", "amount": 10000})
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "frozen"

    pay = client.post("/api/v1/payments/pay", json={"member_id": "senior", "merchant_id": "s-pharmacy"}).json()
    assert pay["ok"] is False and pay["code"] == "frozen"


def test_freeze_cancels_pending_transfer_requests(client):
    r = client.post(
        "/api/v1/transaction/transfer",
        json={"member_id": "senior", "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"}, "amount": 500000},
    )
    req_id = r.json()["request"]["id"]
    freeze(client)
    snap = state(client)
    assert next(x for x in snap["requests"] if x["id"] == req_id)["status"] == "cancelled"


def test_freeze_expires_automatically_after_24_hours(client, tick):
    freeze(client)
    clock.advance(timedelta(hours=24, seconds=1))
    tick()
    senior = member(state(client), "senior")
    assert senior["is_frozen"] is False
    assert not any(a["withdrawal_blocked"] for a in senior["accounts"])
    assert senior["ledger"][0]["desc"] == "24시간 경과"


def test_guardian_can_unfreeze_directly(client):
    freeze(client)
    r = client.post("/api/v1/security/unfreeze", json={"member_id": "senior", "guardian_id": "guardian"})
    assert r.status_code == 200
    assert member(state(client), "senior")["is_frozen"] is False


def test_unfreeze_rejects_non_guardian(client):
    freeze(client)
    r = client.post("/api/v1/security/unfreeze", json={"member_id": "senior", "guardian_id": "senior"})
    assert r.status_code == 403


def test_user_requests_unfreeze_and_guardian_approves(client):
    freeze(client)
    r = client.post("/api/v1/security/unfreeze-request", json={"member_id": "senior"})
    req_id = r.json()["request"]["id"]
    dup = client.post("/api/v1/security/unfreeze-request", json={"member_id": "senior"})
    assert dup.json()["error"]["code"] == "duplicate"

    d = client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req_id, "guardian_id": "guardian", "decision": "APPROVE"},
    )
    assert d.json()["status"] == "APPROVED"
    assert member(state(client), "senior")["is_frozen"] is False


def test_guardian_remote_freeze(client):
    r = freeze(client, "child", "GUARDIAN_REMOTE")
    assert r.status_code == 200
    assert "보호자 원격" in member(state(client), "child")["ledger"][0]["desc"]
