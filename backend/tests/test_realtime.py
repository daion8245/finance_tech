from .conftest import member, state


def test_state_snapshot_has_demo_family(client):
    snap = state(client)
    assert snap["guardian"]["name"] == "김사랑"
    senior = member(snap, "senior")
    child = member(snap, "child")
    assert senior["balance"] == 2_350_000
    assert senior["spent_today"] == 12_400
    assert child["spent_today"] == 8_500
    assert senior["avg_transfer"] == 100_000
    assert child["mode"] == "school"
    assert snap["config"]["approval_timeout_seconds"] == 180


def test_websocket_receives_freeze_event(client):
    with client.websocket_connect("/api/v1/ws") as ws:
        assert ws.receive_json()["type"] == "hello"
        client.post("/api/v1/security/sos-freeze", json={"user_id": "senior", "trigger_type": "LONG_PRESS"})
        event = ws.receive_json()
        assert event["type"] == "freeze"
        assert event["member_id"] == "senior"
        assert "동결" in event["message"]


def test_demo_reset_restores_seed(client):
    client.post("/api/v1/security/sos-freeze", json={"user_id": "senior", "trigger_type": "LONG_PRESS"})
    assert client.post("/api/v1/demo/reset").status_code == 200
    assert member(state(client), "senior")["is_frozen"] is False


def test_unknown_member_is_404(client):
    r = client.post("/api/v1/security/sos-freeze", json={"user_id": "nobody", "trigger_type": "LONG_PRESS"})
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "member"


def test_invalid_body_uses_error_envelope(client):
    r = client.post("/api/v1/security/sos-freeze", json={"user_id": "senior", "trigger_type": "DANCE"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid"
