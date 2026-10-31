from datetime import timedelta

from app import clock

from .conftest import member, request, state

PHISHING = {"member_id": "senior", "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"}, "amount": 500000}


def hold(client):
    r = client.post("/api/v1/transaction/transfer", json=PHISHING)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "pending"
    return body["request"]["id"]


def decide(client, req_id, decision):
    return client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req_id, "guardian_id": "guardian", "decision": decision, "reason": "테스트"},
    )


def test_spec_request_approval_endpoint(client):
    r = client.post(
        "/api/v1/transaction/request-approval",
        json={"sender_id": "senior", "recipient_bank": "국민", "recipient_account": "12345678907788", "recipient_name": "이정민",
              "amount": 500000, "risk_score": 1, "risk_reasons": []},
    )
    body = r.json()
    assert body["status"] == "PENDING_APPROVAL"
    assert body["timeout_seconds"] == 180
    assert body["risk_score"] >= 60  # 클라이언트가 보낸 점수가 아니라 서버가 다시 계산한 점수


def test_pending_transfer_holds_money_until_guardian_approves(client):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    snap = state(client)
    assert member(snap, "senior")["balance"] == before
    req = request(snap, req_id)
    assert req["risk"]["level"] == "high"
    assert req["expires_at"] is not None

    r = decide(client, req_id, "APPROVE")
    assert r.json()["status"] == "APPROVED"
    snap = state(client)
    assert member(snap, "senior")["balance"] == before - 500000
    assert member(snap, "senior")["notices"][0]["status"] == "approved"


def test_reject_keeps_money_and_blocks_second_decision(client):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    assert decide(client, req_id, "REJECT").json()["status"] == "REJECTED"
    snap = state(client)
    assert member(snap, "senior")["balance"] == before
    assert member(snap, "senior")["ledger"][0]["tag"] == "거절"

    again = decide(client, req_id, "APPROVE")
    assert again.status_code == 409


def test_request_expires_after_three_minutes(client, tick):
    req_id = hold(client)
    clock.advance(timedelta(seconds=179))
    tick()
    assert request(state(client), req_id)["status"] == "pending"
    clock.advance(timedelta(seconds=2))
    tick()
    snap = state(client)
    assert request(snap, req_id)["status"] == "expired"
    assert member(snap, "senior")["notices"][0]["status"] == "expired"


def test_ars_call_when_push_not_acknowledged(client, tick):
    req_id = hold(client)
    clock.advance(timedelta(seconds=21))
    tick()
    req = request(state(client), req_id)
    assert req["ars_called_at"] is not None
    assert req["channel"] == "ARS 전화 · 앱 알림"
    logs = client.get("/api/v1/integrations/logs").json()["logs"]
    assert logs[0]["channel"] == "ARS"
    assert "승인은 1번, 거절은 2번" in logs[0]["message"]

    r = client.post("/api/v1/ars/callback", json={"request_id": req_id, "digit": "2"})
    assert r.json()["status"] == "REJECTED"


def test_acknowledged_push_skips_ars(client, tick):
    req_id = hold(client)
    client.post("/api/v1/guardian/ack", json={"guardian_id": "guardian", "request_ids": [req_id]})
    clock.advance(timedelta(seconds=30))
    tick()
    assert request(state(client), req_id)["ars_called_at"] is None


def test_ars_digit_validation(client):
    req_id = hold(client)
    r = client.post("/api/v1/ars/callback", json={"request_id": req_id, "digit": "9"})
    assert r.status_code == 400


def test_approved_transfer_fails_if_frozen_meanwhile(client):
    # 동결은 대기 중 요청을 취소하므로, 결정 시점에는 이미 처리된 요청
    req_id = hold(client)
    client.post("/api/v1/security/sos-freeze", json={"user_id": "senior", "trigger_type": "LONG_PRESS"})
    assert decide(client, req_id, "APPROVE").status_code == 409


def test_dismiss_notice(client):
    req_id = hold(client)
    decide(client, req_id, "REJECT")
    notice = member(state(client), "senior")["notices"][0]
    client.post(f"/api/v1/members/senior/notices/{notice['id']}/dismiss")
    assert member(state(client), "senior")["notices"] == []
