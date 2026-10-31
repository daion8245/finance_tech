"""서버 시각. 저장은 UTC, 시간대 판단(심야·수면 모드·오늘)은 한국 시간으로 합니다.

테스트에서는 `clock.freeze_at(...)`으로 시각을 고정할 수 있습니다.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9), "KST")

_fixed: datetime | None = None
_offset = timedelta(0)


def now() -> datetime:
    if _fixed is not None:
        return _fixed + _offset
    return datetime.now(timezone.utc) + _offset


def freeze_at(moment: datetime | None) -> None:
    """시각을 고정합니다. None이면 실제 시각으로 돌아갑니다."""
    global _fixed, _offset
    _fixed = moment.astimezone(timezone.utc) if moment else None
    _offset = timedelta(0)


def advance(delta: timedelta) -> None:
    """고정된(또는 실제) 시각을 delta만큼 앞으로 보냅니다."""
    global _offset
    _offset += delta


def local(dt: datetime) -> datetime:
    return dt.astimezone(KST)


def local_hour(dt: datetime | None = None) -> int:
    return local(dt or now()).hour


def start_of_local_day(dt: datetime | None = None) -> datetime:
    d = local(dt or now())
    return d.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)


def is_night(hour: int) -> bool:
    """심야 시간대 23:00~06:00."""
    return hour >= 23 or hour < 6
