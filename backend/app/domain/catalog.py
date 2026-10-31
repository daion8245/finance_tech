"""상황별 안심 모드, 가맹점 업종(MCC), 시연용 가맹점 목록."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Category:
    id: str
    label: str
    mcc: tuple[str, ...]


# 가맹점 업종 → 카드 업계 표준 MCC 코드
CATEGORIES: dict[str, Category] = {
    c.id: c
    for c in [
        Category("transport", "교통", ("4111", "4121")),
        Category("stationery", "문구", ("5943",)),
        Category("convenience", "편의점", ("5499",)),
        Category("bookstore", "서점", ("5942",)),
        Category("restaurant", "식당", ("5812",)),
        Category("hospital", "병원", ("8062", "8011")),
        Category("pharmacy", "약국", ("5912",)),
        Category("grocery", "마트", ("5411",)),
        Category("game", "게임", ("5816",)),
        Category("shopping", "쇼핑", ("5999",)),
        Category("giftcard", "상품권", ("6540",)),
        Category("adult", "유흥", ("5813",)),
    ]
}


@dataclass(frozen=True)
class Mode:
    id: str
    label: str
    short: str
    icon: str
    desc: str
    # None이면 모든 업종 허용 (화이트리스트 없음)
    allow: frozenset[str] | None
    schedule: str = ""

    @property
    def allowed_mcc(self) -> list[str]:
        if self.allow is None:
            return []
        return sorted(code for cat in self.allow for code in CATEGORIES[cat].mcc)


MODES: dict[str, Mode] = {
    m.id: m
    for m in [
        Mode("normal", "일반 모드", "일반", "🏠", "모든 결제처를 쓸 수 있어요", None),
        Mode(
            "school",
            "등교 모드",
            "등교",
            "🏫",
            "교통·문구점·편의점·서점·식당만 결제돼요",
            frozenset({"transport", "stationery", "convenience", "bookstore", "restaurant"}),
            "평일 08:00~19:00",
        ),
        Mode(
            "hospital",
            "병원 모드",
            "병원",
            "🏥",
            "병원·약국·교통·마트만 결제돼요",
            frozenset({"hospital", "pharmacy", "transport", "grocery"}),
        ),
    ]
}


@dataclass(frozen=True)
class Merchant:
    id: str
    name: str
    category: str
    amount: int
    emoji: str

    @property
    def mcc(self) -> str:
        return CATEGORIES[self.category].mcc[0]


# 사용자(Member id)마다 시연용 결제처. 보호자 본인 계좌도 같은 결제 기능을 씁니다.
MERCHANTS: dict[str, list[Merchant]] = {
    "senior": [
        Merchant("s-clinic", "행복내과의원", "hospital", 8000, "🏥"),
        Merchant("s-pharmacy", "온누리 약국", "pharmacy", 12400, "💊"),
        Merchant("s-taxi", "택시", "transport", 9800, "🚕"),
        Merchant("s-mart", "행복마트", "grocery", 38600, "🛒"),
        Merchant("s-gift", "상품권 대량 구매", "giftcard", 500000, "🎫"),
    ],
    "child": [
        Merchant("c-bus", "버스·지하철", "transport", 1450, "🚌"),
        Merchant("c-stationery", "모닝 문구점", "stationery", 3500, "✏️"),
        Merchant("c-cvs", "우리동네 편의점", "convenience", 2800, "🏪"),
        Merchant("c-clinic", "튼튼 소아청소년과", "hospital", 5000, "🏥"),
        Merchant("c-game", "게임 아이템 상점", "game", 33000, "🎮"),
        Merchant("c-shop", "온라인 쇼핑몰", "shopping", 24900, "🛍️"),
    ],
    "guardian": [
        Merchant("g-lunch", "점심 식당", "restaurant", 11000, "🍜"),
        Merchant("g-mart", "행복마트", "grocery", 52300, "🛒"),
        Merchant("g-pharmacy", "온누리 약국", "pharmacy", 7200, "💊"),
        Merchant("g-taxi", "택시", "transport", 12600, "🚕"),
        Merchant("g-shop", "온라인 쇼핑몰", "shopping", 39900, "🛍️"),
    ],
}

BANKS = ["핑거벨", "국민", "신한", "우리", "하나", "농협", "카카오뱅크", "토스뱅크"]

SOURCE_LABEL = {"LONG_PRESS": "길게 누르기", "SHAKE_MOTION": "흔들기", "GUARDIAN_REMOTE": "보호자 원격"}
REQUEST_EMOJI = {"transfer": "💸", "payment": "💳", "mode": "🔁", "unfreeze": "🔓"}


def merchant(member_id: str, merchant_id: str) -> Merchant | None:
    return next((m for m in MERCHANTS.get(member_id, []) if m.id == merchant_id), None)
