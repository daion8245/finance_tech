"""DB 테이블. 보호자 1명과 보호 대상 가족(어르신·아이)을 한 가족 단위로 다룹니다.

보호자도 은행 고객이므로 본인 계좌를 Member(role GUARDIAN) 한 줄로 가집니다.
송금·결제·내역은 누구든 같은 테이블과 같은 로직을 씁니다.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, Boolean, ForeignKey, Integer, String, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base, UTCDateTime


class Guardian(Base):
    __tablename__ = "guardians"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(40))
    avatar: Mapped[str] = mapped_column(String(8), default="")
    phone: Mapped[str] = mapped_column(String(20))


class Member(Base):
    """계좌를 가진 사용자. 보호 대상(어르신 SENIOR / 아이 CHILD)과 보호자 본인(GUARDIAN)."""

    __tablename__ = "members"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    guardian_id: Mapped[str] = mapped_column(ForeignKey("guardians.id"))
    role: Mapped[str] = mapped_column(String(10))
    name: Mapped[str] = mapped_column(String(40))
    nickname: Mapped[str | None] = mapped_column(String(40), nullable=True)
    relation_label: Mapped[str] = mapped_column(String(20))
    guardian_relation: Mapped[str] = mapped_column(String(20))
    avatar: Mapped[str] = mapped_column(String(8), default="")

    daily_limit: Mapped[int] = mapped_column(Integer)
    limit_min: Mapped[int] = mapped_column(Integer)
    limit_max: Mapped[int] = mapped_column(Integer)
    limit_step: Mapped[int] = mapped_column(Integer)
    approval_threshold: Mapped[int] = mapped_column(Integer)
    # 송금 이력이 없을 때 쓰는 평균 송금액
    baseline_avg_transfer: Mapped[int] = mapped_column(Integer)

    mode: Mapped[str] = mapped_column(String(16), default="normal")
    allowed_modes: Mapped[list[str]] = mapped_column(JSON)
    require_approval_to_loosen: Mapped[bool] = mapped_column(Boolean, default=False)
    sleep_guard: Mapped[bool] = mapped_column(Boolean, default=True)

    frozen_until: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    frozen_source: Mapped[str | None] = mapped_column(String(20), nullable=True)

    accounts: Mapped[list["Account"]] = relationship(
        back_populates="member", order_by="Account.sort_order", cascade="all, delete-orphan"
    )
    contacts: Mapped[list["Contact"]] = relationship(
        back_populates="member", order_by="Contact.sort_order", cascade="all, delete-orphan"
    )

    @property
    def supervised(self) -> bool:
        """보호자 확인·안심 모드·SOS 동결을 받는 가족인지 (보호자 본인 계좌는 아님)."""
        return self.role != "GUARDIAN"


class Account(Base):
    """오픈뱅킹으로 연동된 계좌."""

    __tablename__ = "accounts"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"))
    name: Mapped[str] = mapped_column(String(40))
    bank: Mapped[str] = mapped_column(String(20))
    number: Mapped[str] = mapped_column(String(40))
    # 실제 계좌번호 (숫자만). 가족끼리 보낸 돈을 받는 계좌에 넣을 때 씁니다
    digits: Mapped[str] = mapped_column(String(20), index=True)
    kind: Mapped[str] = mapped_column(String(12))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    balance: Mapped[int] = mapped_column(Integer)
    withdrawal_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    member: Mapped[Member] = relationship(back_populates="accounts")


class Contact(Base):
    """자주 보내는 받는 분 (등록 계좌)."""

    __tablename__ = "contacts"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"))
    name: Mapped[str] = mapped_column(String(40))
    relation: Mapped[str] = mapped_column(String(20))
    bank: Mapped[str] = mapped_column(String(20))
    account_digits: Mapped[str] = mapped_column(String(20))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    member: Mapped[Member] = relationship(back_populates="contacts")


class LedgerEntry(Base):
    """거래 내역. kind는 in(입금) / out(출금) / protect(보호 조치 기록)."""

    __tablename__ = "ledger"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"), index=True)
    kind: Mapped[str] = mapped_column(String(10))
    title: Mapped[str] = mapped_column(String(80))
    desc: Mapped[str] = mapped_column(String(80), default="")
    amount: Mapped[int] = mapped_column(Integer, default=0)
    emoji: Mapped[str] = mapped_column(String(8), default="")
    tag: Mapped[str | None] = mapped_column(String(10), nullable=True)
    tone: Mapped[str | None] = mapped_column(String(10), nullable=True)
    # transfer(송금) / payment(결제) / deposit(입금) / protect
    category: Mapped[str] = mapped_column(String(16), default="protect")
    counterparty: Mapped[str | None] = mapped_column(String(20), nullable=True)
    at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)


class ApprovalRequest(Base):
    """보호자 콜백 승인 요청 (송금 / 결제 / 모드 변경 / 동결 해제)."""

    __tablename__ = "approval_requests"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"), index=True)
    type: Mapped[str] = mapped_column(String(12))
    title: Mapped[str] = mapped_column(String(80))
    amount: Mapped[int] = mapped_column(Integer, default=0)
    detail: Mapped[str] = mapped_column(String(120), default="")
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    risk: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    # pending / approved / rejected / cancelled / expired / failed
    status: Mapped[str] = mapped_column(String(12), index=True)
    channel: Mapped[str] = mapped_column(String(40), default="앱 알림")
    created_at: Mapped[datetime] = mapped_column(UTCDateTime)
    expires_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    decided_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    decided_by: Mapped[str | None] = mapped_column(String(20), nullable=True)
    decision_reason: Mapped[str | None] = mapped_column(String(120), nullable=True)
    fail_reason: Mapped[str | None] = mapped_column(String(120), nullable=True)
    push_sent_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    push_ack_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    ars_called_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)


class Alert(Base):
    """보호자에게 보이는 가족 알림."""

    __tablename__ = "alerts"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"), index=True)
    title: Mapped[str] = mapped_column(String(80))
    amount: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(12))
    emoji: Mapped[str] = mapped_column(String(8), default="")
    request_id: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)


class RiskAssessment(Base):
    """AI FDS 판정 기록."""

    __tablename__ = "risk_assessments"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"), index=True)
    at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)
    amount: Mapped[int] = mapped_column(Integer)
    recipient: Mapped[str] = mapped_column(String(40))
    is_new: Mapped[bool] = mapped_column(Boolean)
    score: Mapped[int] = mapped_column(Integer)
    level: Mapped[str] = mapped_column(String(10))
    signals: Mapped[list[dict[str, Any]]] = mapped_column(JSON)
    needs_approval: Mapped[bool] = mapped_column(Boolean)
    anomaly_score: Mapped[float | None] = mapped_column(Float, nullable=True)


class Notice(Base):
    """보호자 결정 결과를 사용자에게 알려 주는 배너."""

    __tablename__ = "notices"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    member_id: Mapped[str] = mapped_column(ForeignKey("members.id"), index=True)
    request_id: Mapped[str | None] = mapped_column(String(40), nullable=True)
    status: Mapped[str] = mapped_column(String(12))
    title: Mapped[str] = mapped_column(String(80))
    amount: Mapped[int] = mapped_column(Integer, default=0)
    reason: Mapped[str] = mapped_column(String(120), default="")
    created_at: Mapped[datetime] = mapped_column(UTCDateTime)


class IntegrationLog(Base):
    """외부 연동(오픈뱅킹·FCM·SMS·ARS) 호출 기록. 모의 어댑터도 같은 형식으로 남깁니다."""

    __tablename__ = "integration_logs"

    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)
    channel: Mapped[str] = mapped_column(String(20))
    action: Mapped[str] = mapped_column(String(80))
    target: Mapped[str] = mapped_column(String(60))
    message: Mapped[str] = mapped_column(String(200))
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
