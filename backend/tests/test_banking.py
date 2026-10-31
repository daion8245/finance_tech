"""송금·결제·내역은 어르신·아이·보호자 본인 모두 같은 기능입니다."""

from sqlalchemy import create_engine, text

from app.seed import DAUGHTER, reset_schema, schema_outdated

from .conftest import member, state


def banking(snapshot: dict) -> dict:
    return snapshot["guardian"]["banking"]


def send(client, member_id: str, **draft):
    return client.post("/api/v1/transaction/transfer", json={"member_id": member_id, **draft})


def test_guardian_has_own_account_outside_the_family_list(client):
    snap = state(client)
    me = banking(snap)
    assert me["id"] == "guardian"
    assert me["role"] == "GUARDIAN"
    assert me["balance"] == 3_480_000
    assert {c["name"] for c in me["contacts"]} >= {"김순자", "이민준"}
    assert me["merchants"] and all(m["check"]["ok"] for m in me["merchants"])
    assert me["ledger"][0]["title"] == "점심 식당"
    assert "guardian" not in {m["id"] for m in snap["members"]}


def test_guardian_sends_pocket_money_and_it_arrives(client):
    before = state(client)
    r = send(client, "guardian", contact_id="c-g-son", amount=30000)
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "done"

    after = state(client)
    assert banking(after)["balance"] == banking(before)["balance"] - 30000
    assert member(after, "child")["balance"] == member(before, "child")["balance"] + 30000
    deposit = member(after, "child")["ledger"][0]
    assert (deposit["kind"], deposit["title"], deposit["amount"]) == ("in", "김사랑님이 보냄", 30000)
    assert banking(after)["ledger"][0]["title"] == "이민준님께 송금"
    # 보호자 본인 거래는 가족 알림에 섞이지 않습니다
    assert len(after["alerts"]) == len(before["alerts"])


def test_family_transfer_to_guardian_lands_in_guardian_account(client):
    before = banking(state(client))["balance"]
    assert send(client, "senior", contact_id="c-sarang", amount=50000).json()["status"] == "done"
    me = banking(state(client))
    assert me["balance"] == before + 50000
    assert me["ledger"][0]["title"] == "김순자님이 보냄"


def test_guardian_risky_transfer_shows_risk_but_needs_no_approval(client):
    draft = {"new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"}, "amount": 2_000_000}
    risk = client.post("/api/v1/transaction/assess", json={"member_id": "guardian", **draft}).json()["risk"]
    assert risk["level"] == "high"
    assert risk["needs_approval"] is False

    before = banking(state(client))["balance"]
    body = send(client, "guardian", **draft).json()
    assert body["status"] == "done"
    snap = state(client)
    assert banking(snap)["balance"] == before - 2_000_000
    assert not [r for r in snap["requests"] if r["status"] == "pending"]


def test_guardian_pays_like_everyone_else(client):
    before = banking(state(client))["balance"]
    r = client.post("/api/v1/payments/pay", json={"member_id": "guardian", "merchant_id": "g-mart"}).json()
    assert r["ok"] is True
    assert banking(state(client))["balance"] == before - 52300


def test_senior_and_child_still_pay_with_their_own_rules(client):
    assert client.post("/api/v1/payments/pay", json={"member_id": "senior", "merchant_id": "s-pharmacy"}).json()["ok"] is True
    assert client.post("/api/v1/payments/pay", json={"member_id": "child", "merchant_id": "c-bus"}).json()["ok"] is True


def test_protection_features_are_not_for_the_guardian_account(client):
    freeze = client.post("/api/v1/security/sos-freeze", json={"user_id": "guardian", "trigger_type": "LONG_PRESS"})
    assert freeze.status_code == 400
    assert freeze.json()["error"]["code"] == "role"
    mode = client.post("/api/v1/modes", json={"member_id": "guardian", "mode": "normal", "actor": "SELF"})
    assert mode.json()["error"]["code"] == "role"
    approval = client.post(
        "/api/v1/transaction/request-approval",
        json={"sender_id": "guardian", "recipient_bank": "국민", "recipient_account": "12345678907788",
              "recipient_name": "이정민", "amount": 10000},
    )
    assert approval.json()["error"]["code"] == "role"


def test_cannot_send_to_own_account(client):
    r = send(client, "guardian", new_account={"bank": "핑거벨", "number": DAUGHTER, "name": "김사랑"}, amount=1000)
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "recipient"


def test_deposit_event_reaches_the_receiver(client):
    with client.websocket_connect("/api/v1/ws") as ws:
        assert ws.receive_json()["type"] == "hello"
        send(client, "guardian", contact_id="c-g-son", amount=10000)
        events = [ws.receive_json(), ws.receive_json()]
    deposit = next(e for e in events if e["type"] == "deposit")
    assert deposit["member_id"] == "child"
    assert "10,000원" in deposit["message"]


def test_old_database_is_detected(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'old.db'}")
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE accounts (id VARCHAR(32) PRIMARY KEY, number VARCHAR(40))"))
    assert schema_outdated(engine) is True
    reset_schema(engine)
    assert schema_outdated(engine) is False
