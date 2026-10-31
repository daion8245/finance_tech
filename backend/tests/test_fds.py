from datetime import datetime, timedelta

from app import clock
from app.domain.fds import AnomalyDetector, FdsEngine, Sample, TransferContext

from .conftest import member, state

PHISHING = {"bank": "국민", "number": "12345678907788", "name": "이정민"}


def assess(client, **body):
    return client.post("/api/v1/transaction/assess", json={"member_id": "senior", **body})


def labels(risk):
    return {s["id"] for s in risk["signals"]}


def test_transfer_to_known_contact_at_usual_amount_is_safe(client):
    r = assess(client, contact_id="c-sarang", amount=100000)
    assert r.status_code == 200, r.text
    risk = r.json()["risk"]
    assert risk["level"] == "safe"
    assert risk["needs_approval"] is False
    assert risk["model"]["name"] == "IsolationForest"
    assert risk["model"]["trained_on"] >= 8


def test_phishing_pattern_is_high_risk(client):
    risk = assess(client, new_account=PHISHING, amount=500000).json()["risk"]
    assert risk["level"] == "high"
    assert risk["score"] >= 60
    assert {"new", "large"} <= labels(risk)
    assert risk["needs_approval"] is True


def test_amount_over_threshold_needs_approval_even_when_safe(client):
    risk = assess(client, contact_id="c-sarang", amount=300000).json()["risk"]
    assert "large" not in labels(risk)  # 300%를 '초과'할 때만 신호
    assert risk["needs_approval"] is True


def test_night_transfer_adds_signal_and_sleep_guard(client, at):
    at(datetime(2026, 10, 27, 2, 0, tzinfo=clock.KST))
    risk = assess(client, contact_id="c-sarang", amount=20000).json()["risk"]
    assert {"night", "sleep"} <= labels(risk)
    assert risk["sleep_window"] is True
    assert risk["needs_approval"] is True


def test_sleep_guard_can_be_turned_off(client, at):
    at(datetime(2026, 10, 27, 2, 0, tzinfo=clock.KST))
    client.post("/api/v1/guardian/sleep-guard", json={"member_id": "senior", "enabled": False})
    risk = assess(client, contact_id="c-sarang", amount=20000).json()["risk"]
    assert "sleep" not in labels(risk)


def test_split_transfers_within_ten_minutes(client):
    for _ in range(2):
        r = client.post("/api/v1/transaction/transfer", json={"member_id": "senior", "contact_id": "c-younghee", "amount": 30000})
        assert r.status_code == 200, r.text
        clock.advance(timedelta(minutes=2))
    risk = assess(client, contact_id="c-younghee", amount=30000).json()["risk"]
    assert "split" in labels(risk)


def test_validation_errors(client):
    r = assess(client, contact_id="c-sarang", amount=0)
    assert r.json()["error"]["code"] == "amount"
    r = assess(client, contact_id="c-sarang", amount=99_000_000)
    assert r.json()["error"]["code"] == "balance"
    r = assess(client, new_account={"bank": "국민", "number": "123", "name": "가"}, amount=1000)
    assert r.json()["error"]["code"] == "account"
    r = assess(client, amount=1000)
    assert r.json()["error"]["code"] == "recipient"


def test_safe_transfer_completes_immediately(client):
    before = member(state(client), "senior")["balance"]
    r = client.post("/api/v1/transaction/transfer", json={"member_id": "senior", "contact_id": "c-sarang", "amount": 50000})
    assert r.json()["status"] == "done"
    after = member(state(client), "senior")
    assert after["balance"] == before - 50000
    assert after["ledger"][0]["title"] == "김사랑님께 송금"


def test_new_account_is_remembered_after_completed_transfer(client):
    body = {"member_id": "child", "new_account": {"bank": "신한", "number": "1102223334444", "name": "최하늘"}, "amount": 2000}
    first = client.post("/api/v1/transaction/transfer", json=body).json()
    assert first["status"] == "pending"
    client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": first["request"]["id"], "guardian_id": "guardian", "decision": "APPROVE"},
    )
    contacts = member(state(client), "child")["contacts"]
    assert any(c["name"] == "최하늘" and c["relation"] == "최근 보냄" for c in contacts)


def test_isolation_forest_separates_usual_and_unusual():
    usual = [Sample(a, h) for a, h in [(100000, 10), (50000, 15), (120000, 14), (80000, 11), (12000, 16),
                                         (38000, 13), (96000, 18), (9800, 9), (100000, 12), (45000, 17)]]
    det = AnomalyDetector()
    assert det.fit(usual)
    assert det.score(Sample(90000, 13)).anomaly is False
    odd = det.score(Sample(4_000_000, 3, is_new=True, burst=3))
    assert odd.anomaly is True
    assert odd.strength > 0.5


def test_detector_needs_enough_history():
    det = AnomalyDetector()
    assert det.fit([Sample(1000, 10)] * 3) is False
    assert det.score(Sample(1000, 10)) is None


def test_rule_scores_without_model():
    ctx = TransferContext(
        amount=500000, is_new=True, hour=14, avg_transfer=100000, spent_today=0, daily_limit=1_000_000,
        approval_threshold=300000, recent_attempts=0,
    )
    risk = FdsEngine().assess(ctx)
    assert risk.score == 70
    assert risk.level == "high"
