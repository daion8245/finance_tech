from .conftest import member, state


def merchant(snapshot, member_id, merchant_id):
    return next(m for m in member(snapshot, member_id)["merchants"] if m["id"] == merchant_id)


def pay(client, member_id, merchant_id):
    return client.post("/api/v1/payments/pay", json={"member_id": member_id, "merchant_id": merchant_id}).json()


def test_snapshot_marks_merchants_by_mode(client):
    snap = state(client)
    assert merchant(snap, "child", "c-game")["check"]["code"] == "mode"
    assert merchant(snap, "child", "c-game")["mcc"] == "5816"
    assert merchant(snap, "child", "c-bus")["check"]["ok"] is True
    school = next(m for m in snap["catalog"]["modes"] if m["id"] == "school")
    assert "5816" not in school["allowed_mcc"]
    assert "4111" in school["allowed_mcc"]


def test_school_mode_blocks_game_payment_and_logs_it(client):
    result = pay(client, "child", "c-game")
    assert result["ok"] is False
    assert result["code"] == "mode"
    assert result["can_request"] is True
    child = member(state(client), "child")
    assert child["ledger"][0]["title"] == "게임 아이템 상점 결제 차단"
    snap = state(client)
    assert snap["alerts"][0]["status"] == "blocked"


def test_allowed_payment_goes_through(client):
    before = member(state(client), "child")["balance"]
    assert pay(client, "child", "c-bus")["ok"] is True
    assert member(state(client), "child")["balance"] == before - 1450


def test_blocked_payment_can_be_approved_by_guardian(client):
    req = client.post("/api/v1/payments/request-approval", json={"member_id": "child", "merchant_id": "c-game"}).json()
    assert req["status"] == "pending"
    dup = client.post("/api/v1/payments/request-approval", json={"member_id": "child", "merchant_id": "c-game"}).json()
    assert dup["code"] == "duplicate"
    before = member(state(client), "child")["balance"]
    d = client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req["request"]["id"], "guardian_id": "guardian", "decision": "APPROVE"},
    ).json()
    assert d["status"] == "APPROVED"
    assert member(state(client), "child")["balance"] == before - 33000


def test_hospital_mode_for_senior(client):
    client.post("/api/v1/modes", json={"member_id": "senior", "mode": "hospital", "actor": "SELF"})
    assert pay(client, "senior", "s-gift")["code"] == "mode"
    assert pay(client, "senior", "s-pharmacy")["ok"] is True


def test_child_needs_guardian_to_leave_school_mode(client):
    r = client.post("/api/v1/modes", json={"member_id": "child", "mode": "normal", "actor": "SELF"}).json()
    assert r["status"] == "pending"
    assert member(state(client), "child")["mode"] == "school"
    client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": r["request"]["id"], "guardian_id": "guardian", "decision": "APPROVE"},
    )
    assert member(state(client), "child")["mode"] == "normal"


def test_guardian_switches_mode_directly(client):
    r = client.post("/api/v1/modes", json={"member_id": "child", "mode": "normal", "actor": "GUARDIAN"}).json()
    assert r["status"] == "done"


def test_unknown_mode_is_rejected(client):
    r = client.post("/api/v1/modes", json={"member_id": "senior", "mode": "school", "actor": "GUARDIAN"})
    assert r.status_code == 400


def test_daily_limit_range(client):
    ok = client.post("/api/v1/guardian/limits", json={"member_id": "child", "daily_limit": 50000})
    assert ok.status_code == 200
    assert member(state(client), "child")["daily_limit"] == 50000
    bad = client.post("/api/v1/guardian/limits", json={"member_id": "child", "daily_limit": 1})
    assert bad.json()["error"]["code"] == "limit"


def test_over_limit_payment_needs_approval(client):
    client.post("/api/v1/guardian/limits", json={"member_id": "child", "daily_limit": 10000})
    result = pay(client, "child", "c-stationery")  # 오늘 8,500원 + 3,500원 > 10,000원
    assert result["code"] == "limit"
