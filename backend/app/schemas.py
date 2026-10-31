"""요청 본문 스키마. 필드 이름은 기획서 5.1 API 명세를 따릅니다 (snake_case)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

TriggerType = Literal["SHAKE_MOTION", "LONG_PRESS", "GUARDIAN_REMOTE"]


class SosFreezeRequest(BaseModel):
    user_id: str
    trigger_type: TriggerType
    sensor_intensity: float | None = Field(default=None, ge=0, le=50)


class MemberRequest(BaseModel):
    member_id: str


class NewAccount(BaseModel):
    bank: str
    number: str
    name: str


class TransferDraft(BaseModel):
    member_id: str
    contact_id: str | None = None
    new_account: NewAccount | None = None
    amount: int

    def to_draft(self) -> dict:
        return {
            "contact_id": self.contact_id,
            "new_account": self.new_account.model_dump() if self.new_account else None,
            "amount": self.amount,
        }


class ApprovalRequestBody(BaseModel):
    """기획서의 이상 거래 콜백 승인 요청. 위험도는 서버가 다시 계산합니다 (클라이언트 값은 참고용)."""

    sender_id: str
    recipient_bank: str
    recipient_account: str
    recipient_name: str
    amount: int
    risk_score: int | None = None
    risk_reasons: list[str] | None = None


class CallbackDecision(BaseModel):
    transaction_id: str
    guardian_id: str
    decision: Literal["APPROVE", "REJECT"]
    reason: str | None = Field(default=None, max_length=120)


class PaymentBody(BaseModel):
    member_id: str
    merchant_id: str


class ModeBody(BaseModel):
    member_id: str
    mode: str
    actor: Literal["SELF", "GUARDIAN"] = "SELF"


class LimitBody(BaseModel):
    member_id: str
    daily_limit: int


class SleepGuardBody(BaseModel):
    member_id: str
    enabled: bool


class UnfreezeBody(BaseModel):
    member_id: str
    guardian_id: str


class AckBody(BaseModel):
    guardian_id: str
    request_ids: list[str] = Field(max_length=100)


class ArsCallback(BaseModel):
    request_id: str
    digit: str

    @field_validator("digit")
    @classmethod
    def strip(cls, v: str) -> str:
        return v.strip()
