"""시연용 가족 데이터. HTML 시안의 초기 상태 + FDS 학습용 과거 거래 이력."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import inspect
from sqlalchemy.orm import Session

from . import clock
from .db import Base
from .models import Account, Alert, ApprovalRequest, Contact, Guardian, LedgerEntry, Member, RiskAssessment
from .service import uid

# 핑거벨 안의 가족 계좌 (서로 보내면 받는 계좌에 바로 들어갑니다)
DAUGHTER = "33330012341024"  # 김사랑 (보호자) 계좌
MOTHER = "33331200125678"  # 김순자 입출금 통장
MOTHER_SAVINGS = "33331500342086"
SON = "33333100560917"  # 이민준 용돈 통장
NEIGHBOR = "3020009874471"
FRIEND = "3330005555521"
COLLEAGUE = "11004521873390"

SEED_RISK = {
    "score": 70,
    "level": "high",
    "needs_approval": True,
    "sleep_window": False,
    "model": None,
    "signals": [
        {"id": "new", "label": "처음 보내는 계좌예요", "weight": 35},
        {"id": "large", "label": "평소보다 훨씬 큰 금액이에요", "weight": 30},
    ],
}

# (며칠 전, 시, 제목, 설명, 금액, 이모지, 분류, 상대 계좌)
SENIOR_HISTORY = [
    (8, 10, "김사랑님께 송금", "송금", -100000, "💸", "transfer", DAUGHTER),
    (11, 15, "행복마트", "마트", -45200, "🛒", "payment", None),
    (14, 11, "행복내과의원", "병원", -8000, "🏥", "payment", None),
    (14, 11, "온누리 약국", "약국", -9600, "💊", "payment", None),
    (19, 16, "박영희님께 송금", "송금", -50000, "💸", "transfer", NEIGHBOR),
    (24, 9, "택시", "교통", -9800, "🚕", "payment", None),
    (27, 13, "행복마트", "마트", -27300, "🛒", "payment", None),
    (31, 12, "연금 입금", "입금", 650000, "🏦", "deposit", None),
    (34, 18, "관리비 자동이체", "생활", -96000, "🏠", "payment", None),
    (38, 14, "김사랑님께 송금", "송금", -150000, "💸", "transfer", DAUGHTER),
    (45, 10, "온누리 약국", "약국", -15800, "💊", "payment", None),
    (52, 17, "박영희님께 송금", "송금", -80000, "💸", "transfer", NEIGHBOR),
    (58, 11, "행복마트", "마트", -33400, "🛒", "payment", None),
    (63, 19, "관리비 자동이체", "생활", -96000, "🏠", "payment", None),
    (69, 15, "김사랑님께 송금", "송금", -120000, "💸", "transfer", DAUGHTER),
    (76, 10, "행복내과의원", "병원", -8000, "🏥", "payment", None),
    (84, 16, "박영희님께 송금", "송금", -100000, "💸", "transfer", NEIGHBOR),
]

CHILD_HISTORY = [
    (5, 8, "버스", "교통", -1450, "🚌", "payment", None),
    (5, 16, "우리동네 편의점", "편의점", -2300, "🏪", "payment", None),
    (6, 15, "박서준님께 송금", "송금", -3000, "💸", "transfer", FRIEND),
    (8, 8, "버스", "교통", -1450, "🚌", "payment", None),
    (9, 17, "모닝 문구점", "문구", -4200, "✏️", "payment", None),
    (12, 14, "김사랑님께 송금", "송금", -5000, "💸", "transfer", DAUGHTER),
    (15, 16, "우리동네 편의점", "편의점", -1800, "🏪", "payment", None),
    (19, 15, "박서준님께 송금", "송금", -7000, "💸", "transfer", FRIEND),
    (22, 8, "버스", "교통", -1450, "🚌", "payment", None),
    (26, 13, "모닝 문구점", "문구", -2500, "✏️", "payment", None),
    (30, 18, "박서준님께 송금", "송금", -5000, "💸", "transfer", FRIEND),
    (34, 16, "우리동네 편의점", "편의점", -3100, "🏪", "payment", None),
    (41, 12, "김사랑님께 송금", "송금", -5000, "💸", "transfer", DAUGHTER),
]

# 보호자 본인 계좌. 위 가족 이력과 맞물리게 (어머니·아이가 보낸 돈이 들어와 있음)
GUARDIAN_HISTORY = [
    (6, 12, "점심 식당", "식당", -11000, "🍜", "payment", None),
    (8, 10, "김순자님이 보냄", "입금", 100000, "💌", "deposit", MOTHER),
    (9, 19, "행복마트", "마트", -64300, "🛒", "payment", None),
    (12, 14, "이민준님이 보냄", "입금", 5000, "💌", "deposit", SON),
    (13, 20, "이민준님께 송금", "송금", -20000, "💸", "transfer", SON),
    (15, 10, "통신비 자동이체", "생활", -55000, "📱", "payment", None),
    (20, 9, "급여 입금", "입금", 3200000, "🏢", "deposit", None),
    (24, 18, "김순자님께 송금", "송금", -150000, "💸", "transfer", MOTHER),
    (28, 13, "온라인 쇼핑몰", "쇼핑", -42800, "🛍️", "payment", None),
    (33, 20, "이민준님께 송금", "송금", -30000, "💸", "transfer", SON),
    (36, 12, "최지현님께 송금", "송금", -50000, "💸", "transfer", COLLEAGUE),
    (38, 14, "김순자님이 보냄", "입금", 150000, "💌", "deposit", MOTHER),
    (45, 10, "통신비 자동이체", "생활", -55000, "📱", "payment", None),
    (50, 9, "급여 입금", "입금", 3200000, "🏢", "deposit", None),
    (55, 15, "김순자님께 송금", "송금", -200000, "💸", "transfer", MOTHER),
    (62, 19, "행복마트", "마트", -71200, "🛒", "payment", None),
    (69, 15, "김순자님이 보냄", "입금", 120000, "💌", "deposit", MOTHER),
    (70, 14, "이민준님께 송금", "송금", -30000, "💸", "transfer", SON),
]


def _at_days(now: datetime, days: int, hour: int) -> datetime:
    local = clock.local(now - timedelta(days=days)).replace(hour=hour, minute=12, second=0, microsecond=0)
    return local.astimezone(now.tzinfo)


def reset_schema(engine) -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)


def schema_outdated(engine) -> bool:
    """예전 버전이 만든 DB인지 (지금 테이블에 있어야 할 컬럼이 빠져 있으면). 시연 데이터라 새로 만들면 됩니다."""
    db = inspect(engine)
    existing = set(db.get_table_names())
    for table in Base.metadata.sorted_tables:
        if table.name not in existing:
            continue
        columns = {c["name"] for c in db.get_columns(table.name)}
        if any(c.name not in columns for c in table.columns):
            return True
    return False


def seed(session: Session) -> None:
    now = clock.now()

    def ago(hours: float) -> datetime:
        return now - timedelta(hours=hours)

    session.add(Guardian(id="guardian", name="김사랑", avatar="👩", phone="010-••••-1024"))

    senior = Member(
        id="senior",
        guardian_id="guardian",
        role="SENIOR",
        name="김순자",
        relation_label="어머니",
        guardian_relation="딸",
        avatar="👵",
        daily_limit=1_000_000,
        limit_min=100_000,
        limit_max=3_000_000,
        limit_step=100_000,
        approval_threshold=300_000,
        baseline_avg_transfer=100_000,
        mode="normal",
        allowed_modes=["normal", "hospital"],
        require_approval_to_loosen=False,
        sleep_guard=True,
    )
    senior.accounts = [
        Account(id="acc-senior-1", name="핑거벨 입출금 통장", bank="핑거벨", number="3333-12-••••-5678", digits=MOTHER,
                kind="CHECKING", is_primary=True, balance=2_350_000, sort_order=0),
        Account(id="acc-senior-2", name="노후 생활비 통장", bank="핑거벨", number="3333-15-••••-2086", digits=MOTHER_SAVINGS,
                kind="SAVINGS", is_primary=False, balance=18_400_000, sort_order=1),
    ]
    senior.contacts = [
        Contact(id="c-sarang", name="김사랑", relation="딸", bank="핑거벨", account_digits=DAUGHTER, sort_order=0),
        Contact(id="c-younghee", name="박영희", relation="이웃", bank="농협", account_digits=NEIGHBOR, sort_order=1),
    ]

    child = Member(
        id="child",
        guardian_id="guardian",
        role="CHILD",
        name="이민준",
        nickname="민준",
        relation_label="아들",
        guardian_relation="엄마",
        avatar="🧒",
        daily_limit=20_000,
        limit_min=5_000,
        limit_max=100_000,
        limit_step=5_000,
        approval_threshold=10_000,
        baseline_avg_transfer=5_000,
        mode="school",
        allowed_modes=["normal", "school", "hospital"],
        require_approval_to_loosen=True,
        sleep_guard=True,
    )
    child.accounts = [
        Account(id="acc-child-1", name="민준이 용돈 통장", bank="핑거벨", number="3333-31-••••-0917", digits=SON,
                kind="CHECKING", is_primary=True, balance=120_000, sort_order=0),
    ]
    child.contacts = [
        Contact(id="c-mom", name="김사랑", relation="엄마", bank="핑거벨", account_digits=DAUGHTER, sort_order=0),
        Contact(id="c-seojun", name="박서준", relation="친구", bank="카카오뱅크", account_digits=FRIEND, sort_order=1),
    ]

    # 보호자 본인 계좌: 송금·결제·내역은 가족과 같고, 확인해 줄 사람이 없으니 보호자 승인·안심 모드·SOS는 없습니다
    me = Member(
        id="guardian",
        guardian_id="guardian",
        role="GUARDIAN",
        name="김사랑",
        relation_label="보호자",
        guardian_relation="본인",
        avatar="👩",
        daily_limit=5_000_000,
        limit_min=1_000_000,
        limit_max=10_000_000,
        limit_step=1_000_000,
        approval_threshold=0,
        baseline_avg_transfer=200_000,
        mode="normal",
        allowed_modes=["normal"],
        require_approval_to_loosen=False,
        sleep_guard=False,
    )
    me.accounts = [
        Account(id="acc-guardian-1", name="핑거벨 주거래 통장", bank="핑거벨", number="3333-00-••••-1024", digits=DAUGHTER,
                kind="CHECKING", is_primary=True, balance=3_480_000, sort_order=0),
    ]
    me.contacts = [
        Contact(id="c-g-mother", name="김순자", relation="어머니", bank="핑거벨", account_digits=MOTHER, sort_order=0),
        Contact(id="c-g-son", name="이민준", relation="아들", bank="핑거벨", account_digits=SON, sort_order=1),
        Contact(id="c-g-jihyun", name="최지현", relation="동료", bank="신한", account_digits=COLLEAGUE, sort_order=2),
    ]
    session.add_all([senior, child, me])

    def entry(member: str, at: datetime, kind: str, title: str, desc: str, amount: int = 0, emoji: str = "",
              category: str = "protect", counterparty: str | None = None, tag: str | None = None, tone: str | None = None):
        session.add(LedgerEntry(id=uid("t"), member_id=member, at=at,
                                kind=kind, title=title, desc=desc, amount=amount, emoji=emoji, category=category,
                                counterparty=counterparty, tag=tag, tone=tone))

    for member, history in (("senior", SENIOR_HISTORY), ("child", CHILD_HISTORY), ("guardian", GUARDIAN_HISTORY)):
        for days, hour, title, desc, amount, emoji, category, cp in history:
            entry(member, _at_days(now, days, hour), "in" if amount > 0 else "out", title, desc, amount, emoji, category, cp)

    # 최근 거래 (HTML 시안과 같은 순서)
    entry("senior", ago(3), "out", "온누리 약국", "약국", -12400, "💊", "payment")
    entry("senior", ago(26), "in", "연금 입금", "입금", 650000, "🏦", "deposit")
    entry("senior", ago(30), "out", "행복마트", "마트", -38600, "🛒", "payment")
    entry("senior", ago(50), "in", "김사랑님이 보냄", "입금", 200000, "💌", "deposit")
    entry("senior", ago(120), "protect", "낯선 계좌 송금 차단", "보호자가 거절했어요", 0, "🛡️", tag="거절", tone="red")
    entry("senior", ago(144), "out", "관리비 자동이체", "생활", -96000, "🏠", "payment")

    entry("child", ago(1), "out", "우리동네 편의점", "편의점", -3550, "🏪", "payment")
    entry("child", ago(2), "out", "모닝 문구점", "문구", -3500, "✏️", "payment")
    entry("child", ago(3), "out", "버스", "교통", -1450, "🚌", "payment")
    entry("child", ago(3.2), "protect", "등교 모드 시작", "보호자 설정", 0, "🏫", tag="모드", tone="green")
    entry("child", ago(72), "in", "용돈 (엄마)", "입금", 30000, "🎁", "deposit")
    entry("child", ago(96), "protect", "게임 아이템 결제 차단", "등교 모드", 0, "🎮", tag="차단", tone="amber")

    # 어머니·아이의 최근 입금과 짝이 맞는 보호자 출금
    entry("guardian", ago(2), "out", "점심 식당", "식당", -11000, "🍜", "payment")
    entry("guardian", ago(28), "out", "행복마트", "마트", -52300, "🛒", "payment")
    entry("guardian", ago(50), "out", "김순자님께 송금", "송금", -200000, "💸", "transfer", MOTHER)
    entry("guardian", ago(72), "out", "이민준님께 송금", "송금", -30000, "💸", "transfer", SON)

    session.add(
        ApprovalRequest(
            id="req-seed",
            member_id="senior",
            type="transfer",
            title="이정민님께 송금",
            amount=500000,
            detail="국민 123-••••-7788 · 처음 보내는 계좌",
            payload={"recipient": {"name": "이정민", "relation": "새 계좌", "bank": "국민", "digits": "12345678907788", "is_new": True}},
            risk=SEED_RISK,
            status="rejected",
            channel="ARS 전화 · 앱 알림",
            created_at=ago(120),
            expires_at=ago(120) + timedelta(minutes=3),
            decided_at=ago(119.9),
            decided_by="ars",
            push_sent_at=ago(120),
            ars_called_at=ago(119.95),
        )
    )
    for aid, who, title, amount, status, emoji, h, rid in [
        ("a1", "child", "우리동네 편의점 결제", 3550, "ok", "🏪", 1, None),
        ("a2", "child", "모닝 문구점 결제", 3500, "ok", "✏️", 2, None),
        ("a3", "senior", "온누리 약국 결제", 12400, "ok", "💊", 3, None),
        ("a4", "child", "등교 모드 시작", 0, "ok", "🏫", 3.2, None),
        ("a5", "child", "게임 아이템 결제 차단", 33000, "blocked", "🎮", 96, None),
        ("a6", "senior", "이정민님께 송금 확인 요청", 500000, "rejected", "💸", 120, "req-seed"),
    ]:
        session.add(Alert(id=aid, member_id=who, title=title, amount=amount, status=status, emoji=emoji, at=ago(h), request_id=rid))
    session.add(
        RiskAssessment(
            id="as-seed",
            member_id="senior",
            at=ago(120),
            amount=500000,
            recipient="이정민",
            is_new=True,
            score=70,
            level="high",
            signals=SEED_RISK["signals"],
            needs_approval=True,
        )
    )
    session.commit()
