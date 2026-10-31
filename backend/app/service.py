"""핑거벨 핵심 업무 로직.

- 원터치 SOS 계좌 동결 (기획서 3.1)
- AI FDS 이상거래 탐지 + 보호자 콜백 승인, 3분 타임아웃, ARS 자동 발신 (3.2)
- 상황별 안심 모드 (MCC 화이트리스트 결제 제어, 수면 안심 모드) (3.3)

송금·결제·내역은 어르신·아이·보호자 본인 모두 같은 기능입니다. 보호자 본인 계좌는
확인해 줄 사람이 없으므로 AI 점검 결과만 보여 주고 바로 보내며, 보호 기능(SOS 동결·
안심 모드·한도·보호자 요청)은 보호 대상 가족에게만 씁니다. 핑거벨 안의 계좌로 보낸 돈은
받는 계좌에 바로 들어갑니다.

요청마다 FamilyService를 하나 만들고, 작업이 끝나면 commit()으로 저장한 뒤
쌓인 실시간 이벤트를 보냅니다.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass, replace
from datetime import datetime, timedelta
from typing import Any, Callable

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from . import clock
from .config import Settings
from .domain.catalog import BANKS, CATEGORIES, MERCHANTS, MODES, REQUEST_EMOJI, SOURCE_LABEL, Merchant, merchant
from .domain.fds import FdsEngine, RiskResult, Sample, TransferContext
from .events import EventHub
from .integrations import Gateways, IntegrationRecord
from .models import (
    Account,
    Alert,
    ApprovalRequest,
    Contact,
    Guardian,
    IntegrationLog,
    LedgerEntry,
    Member,
    Notice,
    RiskAssessment,
)

MAX_LIST = 40
MAX_LEDGER = 60
MAX_AMOUNT = 100_000_000
HISTORY_DAYS = 180  # 신규 계좌 판단: 최근 6개월 송금 이력
AVERAGE_DAYS = 90  # 평균 송금액: 최근 3개월
SPLIT_WINDOW = timedelta(minutes=10)
EXPIRING_TYPES = {"transfer", "payment", "mode"}
ARS_TYPES = {"transfer", "payment"}
DONE_ALERT = {"blocked", "rejected", "frozen", "cancelled", "expired"}


class DomainError(Exception):
    def __init__(self, code: str, message: str, status: int = 400, **extra: Any) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
        self.extra = extra


def uid(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:12]}"


def digits_only(value: Any) -> str:
    return re.sub(r"\D", "", str(value or ""))


def mask_account(digits: str) -> str:
    d = digits_only(digits)
    return d if len(d) < 8 else f"{d[:3]}-••••-{d[-4:]}"


def won(n: int) -> str:
    return f"{int(n):,}원"


def iso(dt: datetime | None) -> str | None:
    return dt.isoformat() if dt else None


@dataclass(frozen=True)
class Recipient:
    name: str
    relation: str
    bank: str
    digits: str
    is_new: bool
    contact_id: str | None = None

    @property
    def number(self) -> str:
        return mask_account(self.digits)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "relation": self.relation,
            "bank": self.bank,
            "number": self.number,
            "is_new": self.is_new,
            "contact_id": self.contact_id,
            "digits": self.digits,
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Recipient":
        return cls(d["name"], d.get("relation", ""), d["bank"], d["digits"], bool(d.get("is_new")), d.get("contact_id"))


@dataclass(frozen=True)
class PaymentCheck:
    ok: bool
    code: str
    message: str = ""
    can_request: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {"ok": self.ok, "code": self.code, "message": self.message, "can_request": self.can_request}


class FamilyService:
    def __init__(
        self,
        session: Session,
        settings: Settings,
        fds: FdsEngine,
        gateways: Gateways,
        hub: EventHub | None = None,
        origin: str | None = None,
    ) -> None:
        self.s = session
        # 요청을 보낸 기기 식별자. 이벤트에 담아, 그 기기가 자기 이벤트를 구분하게 합니다.
        self.origin = origin
        self.settings = settings
        self.fds = fds
        self.gw = gateways
        self.hub = hub
        self.events: list[dict[str, Any]] = []

    # ------------------------------------------------------------------ 공통
    def commit(self) -> None:
        self.s.commit()
        if self.hub is not None and self.events:
            self.hub.publish(self.events)
        self.events = []

    def _emit(self, type_: str, message: str = "", **data: Any) -> None:
        self.events.append({"type": type_, "message": message, "origin": self.origin, **data})

    def _integrate(self, record: IntegrationRecord) -> None:
        self.s.add(
            IntegrationLog(
                id=uid("log"),
                at=clock.now(),
                channel=record.channel,
                action=record.action,
                target=record.target,
                message=record.message[:200],
                payload=record.payload,
            )
        )

    # ------------------------------------------------------------------ 조회
    def guardian(self) -> Guardian:
        g = self.s.scalars(select(Guardian).limit(1)).first()
        if g is None:
            raise DomainError("guardian", "등록된 보호자가 없어요.", 404)
        return g

    def member(self, member_id: str) -> Member:
        """계좌 주인 (보호 대상 가족 또는 보호자 본인)."""
        m = self.s.get(Member, member_id)
        if m is None:
            raise DomainError("member", f"알 수 없는 사용자예요: {member_id}", 404)
        return m

    def protected(self, member_id: str) -> Member:
        """보호 기능(SOS 동결·안심 모드·한도·보호자 요청)을 쓰는 가족."""
        m = self.member(member_id)
        if not m.supervised:
            raise DomainError("role", "보호자 본인 계좌에는 쓸 수 없는 기능이에요.")
        return m

    def members(self) -> list[Member]:
        """보호 대상 가족 (보호자 본인 계좌는 빼고)."""
        return list(self.s.scalars(select(Member).where(Member.role != "GUARDIAN").order_by(Member.role.desc())))

    def own_banking(self, g: Guardian) -> Member | None:
        return self.s.scalars(select(Member).where(Member.role == "GUARDIAN", Member.guardian_id == g.id)).first()

    @staticmethod
    def primary(m: Member) -> Account:
        return next((a for a in m.accounts if a.is_primary), m.accounts[0])

    def is_frozen(self, m: Member) -> bool:
        return m.frozen_until is not None and m.frozen_until > clock.now()

    def pending(self, member_id: str | None = None) -> list[ApprovalRequest]:
        q = select(ApprovalRequest).where(ApprovalRequest.status == "pending")
        if member_id:
            q = q.where(ApprovalRequest.member_id == member_id)
        return list(self.s.scalars(q.order_by(ApprovalRequest.created_at.desc())))

    def has_pending(self, member_id: str, type_: str, match: Callable[[ApprovalRequest], bool] = lambda r: True) -> bool:
        return any(r.type == type_ and match(r) for r in self.pending(member_id))

    def spent_today(self, m: Member) -> int:
        total = self.s.scalar(
            select(func.coalesce(func.sum(LedgerEntry.amount), 0)).where(
                LedgerEntry.member_id == m.id,
                LedgerEntry.kind == "out",
                LedgerEntry.at >= clock.start_of_local_day(),
            )
        )
        return -int(total or 0)

    def avg_transfer(self, m: Member) -> int:
        since = clock.now() - timedelta(days=AVERAGE_DAYS)
        avg = self.s.scalar(
            select(func.avg(LedgerEntry.amount)).where(
                LedgerEntry.member_id == m.id,
                LedgerEntry.category == "transfer",
                LedgerEntry.kind == "out",
                LedgerEntry.at >= since,
            )
        )
        return int(round(-avg)) if avg else m.baseline_avg_transfer

    def is_new_recipient(self, m: Member, digits: str) -> bool:
        if any(c.account_digits == digits for c in m.contacts):
            return False
        since = clock.now() - timedelta(days=HISTORY_DAYS)
        sent = self.s.scalar(
            select(func.count()).select_from(LedgerEntry).where(
                LedgerEntry.member_id == m.id,
                LedgerEntry.category == "transfer",
                LedgerEntry.counterparty == digits,
                LedgerEntry.at >= since,
            )
        )
        return not sent

    def recent_attempts(self, m: Member) -> int:
        return int(
            self.s.scalar(
                select(func.count()).select_from(RiskAssessment).where(
                    RiskAssessment.member_id == m.id, RiskAssessment.at >= clock.now() - SPLIT_WINDOW
                )
            )
            or 0
        )

    def training_history(self, m: Member) -> tuple[list[Sample], tuple]:
        """최근 6개월 출금(송금·결제)을 시간순으로 모아 이상치 모델 학습 데이터로 만듭니다."""
        since = clock.now() - timedelta(days=HISTORY_DAYS)
        rows = list(
            self.s.scalars(
                select(LedgerEntry)
                .where(LedgerEntry.member_id == m.id, LedgerEntry.kind == "out", LedgerEntry.at >= since)
                .order_by(LedgerEntry.at)
            )
        )
        seen: set[str] = {c.account_digits for c in m.contacts}
        samples: list[Sample] = []
        recent: list[datetime] = []
        for r in rows:
            is_new = False
            if r.category == "transfer" and r.counterparty:
                is_new = r.counterparty not in seen
                seen.add(r.counterparty)
            recent = [t for t in recent if r.at - t <= SPLIT_WINDOW]
            samples.append(Sample(-r.amount, clock.local_hour(r.at), is_new, len(recent)))
            recent.append(r.at)
        fingerprint = (len(rows), rows[-1].id if rows else None)
        return samples, fingerprint

    # ------------------------------------------------------------------ 기록 헬퍼
    def _log(self, m: Member, **entry: Any) -> LedgerEntry:
        e = LedgerEntry(id=uid("t"), member_id=m.id, at=clock.now(), **entry)
        self.s.add(e)
        return e

    def _protect(self, m: Member, title: str, desc: str, tag: str, tone: str, emoji: str) -> None:
        self._log(m, kind="protect", title=title, desc=desc, tag=tag, tone=tone, emoji=emoji, amount=0, category="protect")

    def _alert(self, m: Member, title: str, status: str, emoji: str, amount: int = 0, request_id: str | None = None) -> None:
        if not m.supervised:  # 가족 알림은 보호 대상 가족의 일만 모읍니다
            return
        self.s.add(
            Alert(id=uid("a"), member_id=m.id, title=title, amount=amount, status=status, emoji=emoji, request_id=request_id, at=clock.now())
        )

    def _sync_alert(self, req: ApprovalRequest) -> None:
        for a in self.s.scalars(select(Alert).where(Alert.request_id == req.id)):
            a.status = req.status

    def _notice(self, m: Member, req: ApprovalRequest, reason: str = "") -> None:
        self.s.add(
            Notice(
                id=uid("n"),
                member_id=m.id,
                request_id=req.id,
                status=req.status,
                title=req.title,
                amount=req.amount,
                reason=reason,
                created_at=clock.now(),
            )
        )

    def _who(self, m: Member) -> str:
        return f"{m.relation_label} {m.name}님"

    # ------------------------------------------------------------------ 송금 + AI FDS
    def resolve_recipient(self, m: Member, contact_id: str | None, new_account: dict[str, Any] | None) -> Recipient:
        if contact_id:
            c = next((c for c in m.contacts if c.id == contact_id), None)
            if c is None:
                raise DomainError("recipient", "받는 분을 찾을 수 없어요.")
            return Recipient(c.name, c.relation, c.bank, c.account_digits, False, c.id)
        if not new_account:
            raise DomainError("recipient", "받는 분을 선택해 주세요.")
        digits = digits_only(new_account.get("number"))
        name = str(new_account.get("name") or "").strip()
        bank = str(new_account.get("bank") or "").strip()
        if bank not in BANKS:
            raise DomainError("bank", "은행을 선택해 주세요.")
        if not 10 <= len(digits) <= 14:
            raise DomainError("account", "계좌번호는 숫자 10~14자리로 입력해 주세요.")
        if not name:
            raise DomainError("name", "받는 분 이름을 입력해 주세요.")
        known = next((c for c in m.contacts if c.account_digits == digits), None)
        if known:
            return Recipient(known.name, known.relation, known.bank, digits, False, known.id)
        return Recipient(name[:20], "새 계좌", bank, digits, self.is_new_recipient(m, digits))

    def _validate_transfer(self, m: Member, draft: dict[str, Any]) -> tuple[Recipient, int]:
        if self.is_frozen(m):
            raise DomainError("frozen", "계좌가 동결되어 있어 보낼 수 없어요.")
        recipient = self.resolve_recipient(m, draft.get("contact_id"), draft.get("new_account"))
        if any(a.digits == recipient.digits for a in m.accounts):
            raise DomainError("recipient", "내 계좌로는 보낼 수 없어요.")
        amount = draft.get("amount")
        if not isinstance(amount, int) or isinstance(amount, bool) or amount <= 0:
            raise DomainError("amount", "1원 이상 금액을 입력해 주세요.")
        if amount > MAX_AMOUNT:
            raise DomainError("amount", f"한 번에 {won(MAX_AMOUNT)}까지 보낼 수 있어요.")
        if amount > self.primary(m).balance:
            raise DomainError("balance", "잔액보다 큰 금액은 보낼 수 없어요.")
        return recipient, amount

    def _risk(self, m: Member, recipient: Recipient, amount: int) -> RiskResult:
        ctx = TransferContext(
            amount=amount,
            is_new=recipient.is_new,
            hour=clock.local_hour(),
            avg_transfer=self.avg_transfer(m),
            spent_today=self.spent_today(m),
            daily_limit=m.daily_limit,
            approval_threshold=m.approval_threshold,
            recent_attempts=self.recent_attempts(m),
            sleep_guard=m.sleep_guard,
        )
        history, fingerprint = self.training_history(m)
        detector = self.fds.detector(m.id, history, fingerprint)
        risk = self.fds.assess(ctx, detector)
        if not m.supervised:
            # 보호자 본인은 확인해 줄 사람이 없으므로 위험도만 알려 주고 본인이 판단합니다
            risk = replace(risk, needs_approval=False)
        return risk

    def assess_transfer(self, member_id: str, draft: dict[str, Any]) -> dict[str, Any]:
        m = self.member(member_id)
        recipient, amount = self._validate_transfer(m, draft)
        risk = self._risk(m, recipient, amount)
        return {"recipient": recipient.to_dict(), "amount": amount, "risk": risk.to_dict()}

    def submit_transfer(self, member_id: str, draft: dict[str, Any], force_approval: bool = False) -> dict[str, Any]:
        m = self.member(member_id)
        recipient, amount = self._validate_transfer(m, draft)
        risk = self._risk(m, recipient, amount)
        self.s.add(
            RiskAssessment(
                id=uid("as"),
                member_id=m.id,
                at=clock.now(),
                amount=amount,
                recipient=recipient.name,
                is_new=recipient.is_new,
                score=risk.score,
                level=risk.level,
                signals=risk.to_dict()["signals"],
                needs_approval=risk.needs_approval,
                anomaly_score=risk.anomaly.decision if risk.anomaly else None,
            )
        )

        if risk.needs_approval or force_approval:
            req = self._create_request(
                m,
                "transfer",
                {"recipient": recipient.to_dict()},
                title=f"{recipient.name}님께 송금",
                amount=amount,
                detail=f"{recipient.bank} {recipient.number}" + (" · 처음 보내는 계좌" if recipient.is_new else ""),
                risk=risk.to_dict(),
            )
            return {"status": "pending", "request": self._request_dict(req), "risk": risk.to_dict()}

        self._do_transfer(m, recipient, amount)
        self._emit("transfer", f"{self._who(m)}이 {recipient.name}님께 {won(amount)}을 보냈어요", member_id=m.id)
        return {"status": "done", "amount": amount, "recipient": recipient.to_dict(), "risk": risk.to_dict()}

    def _do_transfer(self, m: Member, recipient: Recipient, amount: int, alert: bool = True) -> None:
        acct = self.primary(m)
        if acct.withdrawal_blocked:
            raise DomainError("frozen", "출금이 정지된 계좌예요.")
        acct.balance -= amount
        if recipient.is_new and not any(c.account_digits == recipient.digits for c in m.contacts):
            m.contacts.append(
                Contact(
                    id=uid("c"),
                    name=recipient.name,
                    relation="최근 보냄",
                    bank=recipient.bank,
                    account_digits=recipient.digits,
                    sort_order=len(m.contacts),
                )
            )
        self._log(
            m,
            kind="out",
            title=f"{recipient.name}님께 송금",
            desc="송금",
            amount=-amount,
            emoji="💸",
            category="transfer",
            counterparty=recipient.digits,
        )
        self._integrate(self.gw.open_banking.transfer(m.name, acct.number, recipient.bank, recipient.number, amount))
        if alert:
            self._alert(m, f"{recipient.name}님께 송금", "ok", "💸", amount)
        payee = self.s.scalars(select(Account).where(Account.digits == recipient.digits)).first()
        if payee is not None:
            self._deposit(payee, m, amount)

    def _deposit(self, acct: Account, sender: Member, amount: int) -> None:
        """핑거벨 안의 계좌로 보낸 돈을 받는 사람 계좌에 넣습니다 (예: 보호자가 아이에게 보낸 용돈)."""
        acct.balance += amount
        owner = acct.member
        self._log(
            owner,
            kind="in",
            title=f"{sender.name}님이 보냄",
            desc="입금",
            amount=amount,
            emoji="💌",
            category="deposit",
            counterparty=self.primary(sender).digits,
        )
        # 보호자가 받는 돈은 보낸 가족의 송금 알림으로 이미 알게 됩니다
        if owner.supervised:
            self._emit("deposit", f"{sender.name}님이 {won(amount)}을 보냈어요", member_id=owner.id)

    # ------------------------------------------------------------------ 결제 + 상황별 안심 모드
    def check_payment(self, m: Member, mc: Merchant, spent_today: int | None = None) -> PaymentCheck:
        if self.is_frozen(m):
            return PaymentCheck(False, "frozen", "계좌가 동결되어 결제할 수 없어요.")
        mode = MODES[m.mode]
        if mode.allow is not None and mc.category not in mode.allow:
            label = CATEGORIES[mc.category].label
            return PaymentCheck(False, "mode", f"{mode.label}에서는 {label} 결제가 막혀 있어요.", True)
        if mc.amount > self.primary(m).balance:
            return PaymentCheck(False, "balance", "잔액이 부족해요.")
        spent = self.spent_today(m) if spent_today is None else spent_today
        if spent + mc.amount > m.daily_limit:
            return PaymentCheck(False, "limit", f"오늘 쓸 수 있는 한도({won(m.daily_limit)})를 넘어요.", m.supervised)
        if m.supervised and mc.amount >= m.approval_threshold:
            return PaymentCheck(False, "approval", f"{won(m.approval_threshold)} 이상은 보호자 확인이 필요해요.", True)
        return PaymentCheck(True, "ok")

    def _merchant(self, m: Member, merchant_id: str) -> Merchant:
        mc = merchant(m.id, merchant_id)
        if mc is None:
            raise DomainError("merchant", "결제처를 찾을 수 없어요.", 404)
        return mc

    def pay(self, member_id: str, merchant_id: str) -> dict[str, Any]:
        m = self.member(member_id)
        mc = self._merchant(m, merchant_id)
        check = self.check_payment(m, mc)
        if check.ok:
            self._do_payment(m, mc)
            self._emit("payment", f"{self._who(m)}이 {mc.name}에서 {won(mc.amount)}을 결제했어요", member_id=m.id)
        elif check.code in ("mode", "frozen"):
            why = MODES[m.mode].label if check.code == "mode" else "SOS 동결"
            self._protect(m, f"{mc.name} 결제 차단", why, "차단", "amber", mc.emoji)
            self._alert(m, f"{mc.name} 결제 차단", "blocked", mc.emoji, mc.amount)
            self._emit("blocked", f"{self._who(m)}의 {mc.name} 결제를 {why}로 막았어요", member_id=m.id)
        return {**check.to_dict(), "merchant": self._merchant_dict(mc)}

    def request_payment(self, member_id: str, merchant_id: str) -> dict[str, Any]:
        m = self.protected(member_id)
        mc = self._merchant(m, merchant_id)
        check = self.check_payment(m, mc)
        if check.ok:
            return self.pay(member_id, merchant_id)
        if not check.can_request:
            return {**check.to_dict(), "merchant": self._merchant_dict(mc)}
        if self.has_pending(m.id, "payment", lambda r: r.payload.get("merchant_id") == merchant_id):
            return {**PaymentCheck(False, "duplicate", "이미 보호자에게 요청했어요.").to_dict(), "merchant": self._merchant_dict(mc)}
        req = self._create_request(
            m,
            "payment",
            {"merchant_id": mc.id, "mcc": mc.mcc},
            title=f"{mc.name} 결제",
            amount=mc.amount,
            detail=f"{CATEGORIES[mc.category].label} · {check.message}",
        )
        return {"ok": True, "code": "pending", "status": "pending", "message": "", "can_request": False,
                "request": self._request_dict(req), "merchant": self._merchant_dict(mc)}

    def _do_payment(self, m: Member, mc: Merchant, alert: bool = True) -> None:
        acct = self.primary(m)
        if acct.withdrawal_blocked:
            raise DomainError("frozen", "출금이 정지된 계좌예요.")
        acct.balance -= mc.amount
        self._log(m, kind="out", title=mc.name, desc=CATEGORIES[mc.category].label, amount=-mc.amount, emoji=mc.emoji, category="payment")
        if alert:
            self._alert(m, f"{mc.name} 결제", "ok", mc.emoji, mc.amount)

    # ------------------------------------------------------------------ SOS 계좌 동결
    def freeze(self, member_id: str, trigger_type: str, intensity: float | None = None) -> dict[str, Any]:
        m = self.protected(member_id)
        if trigger_type not in SOURCE_LABEL:
            raise DomainError("trigger", "알 수 없는 SOS 트리거예요.")
        g = self.guardian()
        if self.is_frozen(m):
            return self._freeze_result(m, already=True)

        now = clock.now()
        m.frozen_until = now + timedelta(hours=self.settings.freeze_hours)
        m.frozen_source = trigger_type
        for a in m.accounts:
            a.withdrawal_blocked = True
        how = SOURCE_LABEL[trigger_type]
        self._integrate(self.gw.open_banking.stop_withdrawals(m.name, self._accounts_payload(m), f"SOS {how}"))

        # 동결되면 기다리던 송금·결제 요청은 자동 취소
        for r in self.pending(m.id):
            if r.type in ("transfer", "payment"):
                r.status = "cancelled"
                r.decided_at = now
                r.decided_by = "system"
                r.decision_reason = "SOS 동결"
                self._sync_alert(r)

        self._protect(m, "SOS 계좌 동결", f"{how} · {self.settings.freeze_hours}시간 출금 정지", "동결", "red", "🔒")
        self._alert(m, f"SOS 계좌 동결 ({how})", "frozen", "🔒")

        detail = f"{len(m.accounts)}개 계좌 출금 정지"
        if intensity:
            detail += f" · 센서 {intensity:.1f}g"
        if trigger_type == "GUARDIAN_REMOTE":
            self._integrate(self.gw.push.send(m.name, "보호자가 계좌를 잠갔어요", detail, {"type": "freeze", "member_id": m.id}))
        else:
            self._integrate(
                self.gw.push.send(g.name, f"긴급 SOS · {self._who(m)}", f"{how}로 {detail}", {"type": "freeze", "member_id": m.id})
            )
            self._integrate(
                self.gw.sms.send(g.phone, f"[핑거벨] 긴급 SOS 발생: {self._who(m)}의 계좌 {len(m.accounts)}개 출금이 동결되었습니다 ({how}).")
            )
        self._emit("freeze", f"{self._who(m)} 계좌를 동결했어요 ({how})", member_id=m.id, source=trigger_type)
        return self._freeze_result(m)

    def _freeze_result(self, m: Member, already: bool = False) -> dict[str, Any]:
        return {
            "status": "SUCCESS",
            "already_frozen": already,
            "frozen_accounts_count": sum(1 for a in m.accounts if a.withdrawal_blocked),
            "freeze_expires_at": iso(m.frozen_until),
            "guardian_notified": True,
        }

    @staticmethod
    def _accounts_payload(m: Member) -> list[dict[str, Any]]:
        return [{"bank": a.bank, "number": a.number, "name": a.name} for a in m.accounts]

    def request_unfreeze(self, member_id: str) -> dict[str, Any]:
        m = self.protected(member_id)
        if not self.is_frozen(m):
            raise DomainError("not-frozen", "동결된 계좌가 없어요.")
        if self.has_pending(m.id, "unfreeze"):
            raise DomainError("duplicate", "이미 해제를 요청했어요.")
        req = self._create_request(m, "unfreeze", {}, title="계좌 동결 해제", detail="본인이 동결 해제를 요청했어요")
        return {"status": "pending", "request": self._request_dict(req)}

    def unfreeze(self, member_id: str, reason: str = "보호자 해제") -> dict[str, Any]:
        m = self.protected(member_id)
        if not self.is_frozen(m):
            raise DomainError("not-frozen", "동결 상태가 아니에요.")
        self._unfreeze(m, reason)
        return {"status": "SUCCESS"}

    def _unfreeze(self, m: Member, reason: str, alert: bool = True) -> None:
        m.frozen_until = None
        m.frozen_source = None
        for a in m.accounts:
            a.withdrawal_blocked = False
        self._integrate(self.gw.open_banking.resume_withdrawals(m.name, self._accounts_payload(m), reason))
        for r in self.pending(m.id):
            if r.type == "unfreeze":
                r.status = "approved"
                r.decided_at = clock.now()
                r.decided_by = "system" if reason == "24시간 경과" else "guardian"
                self._sync_alert(r)
        self._protect(m, "계좌 동결 해제", reason, "해제", "green", "🔓")
        if alert:
            self._alert(m, "계좌 동결 해제", "ok", "🔓")
        self._emit("unfreeze", f"{self._who(m)} 계좌 동결을 풀었어요 ({reason})", member_id=m.id)

    # ------------------------------------------------------------------ 모드 · 한도
    def set_mode(self, member_id: str, mode_id: str, actor: str = "self") -> dict[str, Any]:
        m = self.protected(member_id)
        if mode_id not in MODES or mode_id not in m.allowed_modes:
            raise DomainError("mode", "사용할 수 없는 모드예요.")
        if m.mode == mode_id:
            return {"status": "same"}
        current, target = MODES[m.mode], MODES[mode_id]
        loosening = actor == "self" and m.require_approval_to_loosen and current.allow is not None and target.allow is None
        if loosening:
            if self.has_pending(m.id, "mode"):
                raise DomainError("duplicate", "이미 보호자에게 요청했어요.")
            req = self._create_request(
                m, "mode", {"mode": mode_id}, title=f"{target.label}로 변경", detail=f"{current.label} 해제를 요청했어요"
            )
            return {"status": "pending", "request": self._request_dict(req)}
        self._set_mode(m, mode_id, actor)
        return {"status": "done"}

    def _set_mode(self, m: Member, mode_id: str, actor: str, alert: bool = True) -> None:
        mode = MODES[mode_id]
        m.mode = mode_id
        self._protect(m, f"{mode.label} 시작", "보호자 설정" if actor == "guardian" else "직접 설정", "모드", "green", mode.icon)
        if alert:
            self._alert(m, f"{mode.label} 시작", "ok", mode.icon)
        self._emit("mode", f"{self._who(m)}: {mode.label}로 바뀌었어요", member_id=m.id)

    def set_daily_limit(self, member_id: str, value: int) -> dict[str, Any]:
        m = self.protected(member_id)
        if not m.limit_min <= value <= m.limit_max:
            raise DomainError("limit", f"{won(m.limit_min)}~{won(m.limit_max)} 사이로 정해 주세요.")
        m.daily_limit = int(value)
        self._emit("limit", f"{self._who(m)} 하루 한도가 {won(value)}으로 바뀌었어요", member_id=m.id)
        return {"status": "done", "daily_limit": m.daily_limit}

    def set_sleep_guard(self, member_id: str, enabled: bool) -> dict[str, Any]:
        m = self.protected(member_id)
        m.sleep_guard = bool(enabled)
        self._emit("sleep", "", member_id=m.id)
        return {"status": "done", "sleep_guard": m.sleep_guard}

    # ------------------------------------------------------------------ 보호자 콜백 승인
    def _create_request(
        self,
        m: Member,
        type_: str,
        payload: dict[str, Any],
        *,
        title: str,
        amount: int = 0,
        detail: str = "",
        risk: dict[str, Any] | None = None,
    ) -> ApprovalRequest:
        if not m.supervised:
            raise DomainError("role", "보호자 본인 거래는 승인 요청 없이 진행돼요.")
        now = clock.now()
        g = self.guardian()
        req = ApprovalRequest(
            id=uid("req"),
            member_id=m.id,
            type=type_,
            title=title,
            amount=amount,
            detail=detail,
            payload=payload,
            risk=risk,
            status="pending",
            channel="앱 알림",
            created_at=now,
            expires_at=now + timedelta(seconds=self.settings.approval_timeout_seconds) if type_ in EXPIRING_TYPES else None,
            push_sent_at=now,
        )
        self.s.add(req)
        self._alert(m, f"{title} 확인 요청", "pending", REQUEST_EMOJI[type_], amount, req.id)

        body = f"{self._who(m)} · {title}" + (f" {won(amount)}" if amount else "")
        if risk:
            reasons = ", ".join(s["label"] for s in risk["signals"][:3])
            body += f" · 위험도 {risk['score']}점" + (f" ({reasons})" if reasons else "")
        self._integrate(self.gw.push.send(g.name, "보호자 확인 요청", body, {"type": "request", "request_id": req.id}))
        self._emit("request", f"{self._who(m)}이 {title} 확인을 요청했어요", member_id=m.id, request_id=req.id)
        return req

    def _get_request(self, request_id: str) -> ApprovalRequest:
        req = self.s.get(ApprovalRequest, request_id)
        if req is None:
            raise DomainError("missing", "요청을 찾을 수 없어요.", 404)
        return req

    def decide(self, request_id: str, approve: bool, by: str = "guardian", reason: str | None = None) -> dict[str, Any]:
        req = self._get_request(request_id)
        if req.status != "pending":
            raise DomainError("done", "이미 처리된 요청이에요.", 409, status_now=req.status)
        m = self.member(req.member_id)

        message = ""
        if approve:
            ok, message = self._execute(req, m)
            req.status = "approved" if ok else "failed"
            if not ok:
                req.fail_reason = message
        else:
            req.status = "rejected"
            self._protect(m, f"{req.title} 거절", "보호자가 거절했어요", "거절", "red", "🛡️")
        req.decided_at = clock.now()
        req.decided_by = by
        req.decision_reason = reason
        self._sync_alert(req)
        self._notice(m, req, req.fail_reason or "")

        verdict = {"approved": "승인했어요", "rejected": "거절했어요", "failed": "처리하지 못했어요"}[req.status]
        self._integrate(self.gw.push.send(m.name, f"보호자가 {verdict}", req.title, {"type": "decision", "request_id": req.id}))
        via = " (ARS)" if by == "ars" else ""
        self._emit("decision", f"보호자가 {req.title} 요청을 {verdict}{via}", member_id=m.id, request_id=req.id, status=req.status)
        return {"status": req.status, "message": message, "request": self._request_dict(req)}

    def _execute(self, req: ApprovalRequest, m: Member) -> tuple[bool, str]:
        if req.type == "transfer":
            if self.is_frozen(m):
                return False, "계좌가 동결되어 보내지 못했어요."
            if req.amount > self.primary(m).balance:
                return False, "잔액이 부족해 보내지 못했어요."
            self._do_transfer(m, Recipient.from_dict(req.payload["recipient"]), req.amount, alert=False)
            return True, ""
        if req.type == "payment":
            mc = merchant(m.id, req.payload.get("merchant_id", ""))
            if mc is None:
                return False, "결제처를 찾을 수 없어요."
            if self.is_frozen(m):
                return False, "계좌가 동결되어 결제하지 못했어요."
            if mc.amount > self.primary(m).balance:
                return False, "잔액이 부족해 결제하지 못했어요."
            self._do_payment(m, mc, alert=False)
            return True, ""
        if req.type == "mode":
            self._set_mode(m, req.payload["mode"], "guardian", alert=False)
            return True, ""
        if req.type == "unfreeze":
            if self.is_frozen(m):
                self._unfreeze(m, "보호자 승인", alert=False)
            return True, ""
        return False, "알 수 없는 요청이에요."

    def acknowledge(self, request_ids: list[str]) -> dict[str, Any]:
        """보호자 앱이 요청을 화면에 띄웠다는 확인. 확인한 요청에는 ARS 전화를 걸지 않습니다."""
        now = clock.now()
        count = 0
        for rid in request_ids:
            req = self.s.get(ApprovalRequest, rid)
            if req and req.status == "pending" and req.push_ack_at is None:
                req.push_ack_at = now
                count += 1
        return {"acknowledged": count}

    def ars_answer(self, request_id: str, digit: str) -> dict[str, Any]:
        if digit not in ("1", "2"):
            raise DomainError("digit", "1번(승인) 또는 2번(거절)만 누를 수 있어요.")
        return self.decide(request_id, digit == "1", by="ars", reason=f"ARS {digit}번")

    def dismiss_notice(self, member_id: str, notice_id: str) -> dict[str, Any]:
        self.member(member_id)
        self.s.execute(delete(Notice).where(Notice.id == notice_id, Notice.member_id == member_id))
        self._emit("notice", "", member_id=member_id)
        return {"status": "done"}

    # ------------------------------------------------------------------ 타이머 (스케줄러가 1초마다 호출)
    def tick(self) -> bool:
        now = clock.now()
        changed = False
        for m in self.members():
            if m.frozen_until is not None and m.frozen_until <= now:
                self._unfreeze(m, "24시간 경과")
                changed = True
        for req in self.pending():
            if req.expires_at is not None and now >= req.expires_at:
                self._expire(req)
                changed = True
            elif (
                req.type in ARS_TYPES
                and req.push_ack_at is None
                and req.ars_called_at is None
                and now - req.created_at >= timedelta(seconds=self.settings.ars_after_seconds)
            ):
                self._call_ars(req)
                changed = True
        return changed

    def _expire(self, req: ApprovalRequest) -> None:
        m = self.member(req.member_id)
        req.status = "expired"
        req.decided_at = clock.now()
        req.decided_by = "system"
        minutes = max(1, self.settings.approval_timeout_seconds // 60)
        reason = f"{minutes}분 안에 보호자 응답이 없어 자동으로 취소했어요"
        self._protect(m, f"{req.title} 자동 취소", f"{minutes}분 안에 응답 없음", "취소", "red", "🛡️")
        self._sync_alert(req)
        self._notice(m, req, reason)
        self._emit("expired", f"{req.title} 요청이 시간 초과로 취소됐어요", member_id=m.id, request_id=req.id)

    def _call_ars(self, req: ApprovalRequest) -> None:
        m = self.member(req.member_id)
        g = self.guardian()
        what = f"{req.title} {won(req.amount)}" if req.amount else req.title
        script = (
            f"핑거벨 안심 확인 전화입니다. {m.name}님의 계좌에서 {what} 요청이 감지되었습니다. "
            "승인은 1번, 거절은 2번을 눌러주세요."
        )
        req.ars_called_at = clock.now()
        req.channel = "ARS 전화 · 앱 알림"
        self._integrate(self.gw.ars.call(g.phone, script, req.id))
        self._emit("ars_call", "보호자에게 ARS 확인 전화를 걸었어요", member_id=m.id, request_id=req.id, script=script)

    # ------------------------------------------------------------------ 스냅샷 (앱이 그리는 전체 상태)
    def snapshot(self) -> dict[str, Any]:
        g = self.guardian()
        members = self.members()
        own = self.own_banking(g)
        requests = list(self.s.scalars(select(ApprovalRequest).order_by(ApprovalRequest.created_at.desc()).limit(MAX_LIST)))
        alerts = list(self.s.scalars(select(Alert).order_by(Alert.at.desc()).limit(MAX_LIST)))
        assessments = list(
            self.s.scalars(
                select(RiskAssessment)
                .where(RiskAssessment.member_id.in_([m.id for m in members]))
                .order_by(RiskAssessment.at.desc())
                .limit(MAX_LIST)
            )
        )
        today = clock.start_of_local_day()
        return {
            "server_time": iso(clock.now()),
            "config": {
                "approval_timeout_seconds": self.settings.approval_timeout_seconds,
                "ars_after_seconds": self.settings.ars_after_seconds,
                "freeze_hours": self.settings.freeze_hours,
            },
            # banking: 보호자 본인 계좌 (가족과 같은 모양 · 송금·결제·내역에 씀)
            "guardian": {
                "id": g.id,
                "name": g.name,
                "avatar": g.avatar,
                "phone": g.phone,
                "banking": self._member_dict(own) if own else None,
            },
            "members": [self._member_dict(m) for m in members],
            "requests": [self._request_dict(r) for r in requests],
            "alerts": [
                {
                    "id": a.id,
                    "member_id": a.member_id,
                    "title": a.title,
                    "amount": a.amount,
                    "status": a.status,
                    "emoji": a.emoji,
                    "request_id": a.request_id,
                    "at": iso(a.at),
                }
                for a in alerts
            ],
            "assessments": [
                {
                    "id": x.id,
                    "member_id": x.member_id,
                    "at": iso(x.at),
                    "amount": x.amount,
                    "recipient": x.recipient,
                    "is_new": x.is_new,
                    "score": x.score,
                    "level": x.level,
                    "signals": x.signals,
                }
                for x in assessments
            ],
            "stats": {
                "blocked_today": sum(1 for a in alerts if a.status in DONE_ALERT and a.at >= today),
                "risky_transfers": sum(1 for x in assessments if x.level != "safe"),
            },
            "catalog": {
                "modes": [
                    {
                        "id": md.id,
                        "label": md.label,
                        "short": md.short,
                        "icon": md.icon,
                        "desc": md.desc,
                        "schedule": md.schedule,
                        "allow": sorted(md.allow) if md.allow is not None else None,
                        "allowed_mcc": md.allowed_mcc,
                    }
                    for md in MODES.values()
                ],
                "categories": {c.id: {"label": c.label, "mcc": list(c.mcc)} for c in CATEGORIES.values()},
                "banks": BANKS,
            },
        }

    def _member_dict(self, m: Member) -> dict[str, Any]:
        acct = self.primary(m)
        spent = self.spent_today(m)
        ledger = list(
            self.s.scalars(select(LedgerEntry).where(LedgerEntry.member_id == m.id).order_by(LedgerEntry.at.desc()).limit(MAX_LEDGER))
        )
        notices = list(self.s.scalars(select(Notice).where(Notice.member_id == m.id).order_by(Notice.created_at.desc())))
        frozen = self.is_frozen(m)
        return {
            "id": m.id,
            "role": m.role,
            "name": m.name,
            "nickname": m.nickname,
            "relation_label": m.relation_label,
            "guardian_relation": m.guardian_relation,
            "avatar": m.avatar,
            "balance": acct.balance,
            "account": self._account_dict(acct),
            "accounts": [self._account_dict(a) for a in m.accounts],
            "spent_today": spent,
            "daily_limit": m.daily_limit,
            "limit_range": {"min": m.limit_min, "max": m.limit_max, "step": m.limit_step},
            "approval_threshold": m.approval_threshold,
            "avg_transfer": self.avg_transfer(m),
            "mode": m.mode,
            "modes": list(m.allowed_modes),
            "require_approval_to_loosen": m.require_approval_to_loosen,
            "sleep_guard": m.sleep_guard,
            "sleep_active": m.sleep_guard and clock.is_night(clock.local_hour()),
            "is_frozen": frozen,
            "frozen_until": iso(m.frozen_until) if frozen else None,
            "frozen_source": m.frozen_source if frozen else None,
            "contacts": [
                {"id": c.id, "name": c.name, "relation": c.relation, "bank": c.bank, "number": mask_account(c.account_digits)}
                for c in m.contacts
            ],
            "ledger": [
                {
                    "id": e.id,
                    "kind": e.kind,
                    "title": e.title,
                    "desc": e.desc,
                    "amount": e.amount,
                    "emoji": e.emoji,
                    "tag": e.tag,
                    "tone": e.tone,
                    "category": e.category,
                    "at": iso(e.at),
                }
                for e in ledger
            ],
            "notices": [
                {
                    "id": n.id,
                    "request_id": n.request_id,
                    "status": n.status,
                    "title": n.title,
                    "amount": n.amount,
                    "reason": n.reason,
                    "created_at": iso(n.created_at),
                }
                for n in notices
            ],
            "merchants": [
                {**self._merchant_dict(mc), "check": self.check_payment(m, mc, spent).to_dict()} for mc in MERCHANTS.get(m.id, [])
            ],
        }

    @staticmethod
    def _account_dict(a: Account) -> dict[str, Any]:
        return {
            "id": a.id,
            "name": a.name,
            "bank": a.bank,
            "number": a.number,
            "kind": a.kind,
            "balance": a.balance,
            "withdrawal_blocked": a.withdrawal_blocked,
        }

    @staticmethod
    def _merchant_dict(mc: Merchant) -> dict[str, Any]:
        return {
            "id": mc.id,
            "name": mc.name,
            "category": mc.category,
            "category_label": CATEGORIES[mc.category].label,
            "mcc": mc.mcc,
            "amount": mc.amount,
            "emoji": mc.emoji,
        }

    @staticmethod
    def _request_dict(r: ApprovalRequest) -> dict[str, Any]:
        return {
            "id": r.id,
            "member_id": r.member_id,
            "type": r.type,
            "title": r.title,
            "amount": r.amount,
            "detail": r.detail,
            "risk": r.risk,
            "status": r.status,
            "channel": r.channel,
            "created_at": iso(r.created_at),
            "expires_at": iso(r.expires_at),
            "decided_at": iso(r.decided_at),
            "decided_by": r.decided_by,
            "fail_reason": r.fail_reason,
            "push_ack_at": iso(r.push_ack_at),
            "ars_called_at": iso(r.ars_called_at),
        }

    def integration_logs(self, limit: int = 30) -> list[dict[str, Any]]:
        rows = self.s.scalars(select(IntegrationLog).order_by(IntegrationLog.at.desc()).limit(max(1, min(limit, 200))))
        return [
            {"id": r.id, "at": iso(r.at), "channel": r.channel, "action": r.action, "target": r.target, "message": r.message}
            for r in rows
        ]
