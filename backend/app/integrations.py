"""외부 연동 어댑터 (금융결제원 오픈뱅킹, FCM 푸시, SMS, ARS 음성 전화).

지금은 모의(Mock) 구현만 있습니다. 실제 API처럼 호출 내용을 만들고 IntegrationRecord로
돌려주면, 서비스가 연동 기록(integration_logs)에 남깁니다. 실제 연동으로 바꿀 때는
같은 메서드를 가진 클래스를 만들어 `Gateways`에 넣으면 됩니다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(frozen=True)
class IntegrationRecord:
    channel: str  # OPEN_BANKING / FCM / SMS / ARS
    action: str
    target: str
    message: str
    payload: dict[str, Any] = field(default_factory=dict)


class OpenBankingGateway(Protocol):
    def stop_withdrawals(self, owner: str, accounts: list[dict[str, Any]], reason: str) -> IntegrationRecord: ...
    def resume_withdrawals(self, owner: str, accounts: list[dict[str, Any]], reason: str) -> IntegrationRecord: ...
    def transfer(self, owner: str, from_account: str, to_bank: str, to_account: str, amount: int) -> IntegrationRecord: ...


class PushGateway(Protocol):
    def send(self, to: str, title: str, body: str, data: dict[str, Any]) -> IntegrationRecord: ...


class SmsGateway(Protocol):
    def send(self, to: str, text: str) -> IntegrationRecord: ...


class ArsGateway(Protocol):
    def call(self, to: str, script: str, request_id: str) -> IntegrationRecord: ...


class MockOpenBanking:
    """금융결제원 오픈뱅킹 테스트베드 형식을 흉내냅니다 (실제 요청은 보내지 않음)."""

    def stop_withdrawals(self, owner, accounts, reason):
        return IntegrationRecord(
            "OPEN_BANKING",
            "POST /v2.0/account/withdraw_stop",
            owner,
            f"연동 계좌 {len(accounts)}개 일괄 지급정지 ({reason})",
            {"accounts": accounts, "reason": reason, "mode": "mock"},
        )

    def resume_withdrawals(self, owner, accounts, reason):
        return IntegrationRecord(
            "OPEN_BANKING",
            "POST /v2.0/account/withdraw_resume",
            owner,
            f"연동 계좌 {len(accounts)}개 지급정지 해제 ({reason})",
            {"accounts": accounts, "reason": reason, "mode": "mock"},
        )

    def transfer(self, owner, from_account, to_bank, to_account, amount):
        return IntegrationRecord(
            "OPEN_BANKING",
            "POST /v2.0/transfer/withdraw/fin_num",
            owner,
            f"{to_bank} {to_account}로 {amount:,}원 출금이체",
            {"from": from_account, "to_bank": to_bank, "to_account": to_account, "amount": amount, "mode": "mock"},
        )


class MockPush:
    def send(self, to, title, body, data):
        return IntegrationRecord("FCM", "POST /v1/projects/fingerbell/messages:send", to, f"{title} · {body}", {"data": data, "mode": "mock"})


class MockSms:
    def send(self, to, text):
        return IntegrationRecord("SMS", "POST /sms/send", to, text, {"mode": "mock"})


class MockArs:
    def call(self, to, script, request_id):
        return IntegrationRecord(
            "ARS",
            "POST /calls (TwiML Gather 1|2)",
            to,
            script,
            {"request_id": request_id, "digits": {"1": "APPROVE", "2": "REJECT"}, "mode": "mock"},
        )


@dataclass
class Gateways:
    open_banking: OpenBankingGateway = field(default_factory=MockOpenBanking)
    push: PushGateway = field(default_factory=MockPush)
    sms: SmsGateway = field(default_factory=MockSms)
    ars: ArsGateway = field(default_factory=MockArs)
