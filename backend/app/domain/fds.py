"""AI 이상거래탐지(FDS).

두 단계로 위험도를 계산합니다.
1. 설명 가능한 규칙 (기획서 3.2): 신규 계좌, 평균의 300% 초과, 심야, 10분 내 분할 송금, 하루 한도 초과
2. Isolation Forest: 사용자의 최근 6개월 출금 패턴(금액·시간대·신규 여부·연속 시도)을 학습해
   평소와 동떨어진 거래를 찾아냅니다 (비지도 학습).

최종 점수는 0~99점이고, 60점 이상은 위험(high), 30점 이상은 주의(caution)입니다.
"""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass, field
from typing import Callable, Sequence

import numpy as np
from sklearn.ensemble import IsolationForest

from ..clock import is_night

BASE_SCORE = 5
HIGH_SCORE = 60
CAUTION_SCORE = 30
LARGE_RATIO = 3.0  # 3개월 평균 송금액의 300% 초과
SPLIT_ATTEMPTS = 2  # 10분 안에 이미 2번 이상 보냈으면 분할 송금 의심


@dataclass(frozen=True)
class TransferContext:
    amount: int
    is_new: bool
    hour: int
    avg_transfer: int
    spent_today: int
    daily_limit: int
    approval_threshold: int
    recent_attempts: int  # 최근 10분 동안의 송금 시도 수 (이번 건 제외)
    sleep_guard: bool = False

    @property
    def sleep_window(self) -> bool:
        return self.sleep_guard and is_night(self.hour)


@dataclass(frozen=True)
class Signal:
    id: str
    label: str
    weight: int


@dataclass(frozen=True)
class Rule:
    id: str
    label: str
    weight: int
    test: Callable[[TransferContext], bool]


RULES: tuple[Rule, ...] = (
    Rule("new", "처음 보내는 계좌예요", 35, lambda c: c.is_new),
    Rule(
        "large",
        "평소보다 훨씬 큰 금액이에요",
        30,
        lambda c: c.avg_transfer > 0 and c.amount > c.avg_transfer * LARGE_RATIO,
    ),
    Rule("limit", "하루 한도를 넘는 금액이에요", 20, lambda c: c.spent_today + c.amount > c.daily_limit),
    Rule("night", "심야 시간대(23시~6시) 송금이에요", 15, lambda c: is_night(c.hour)),
    Rule("split", "10분 안에 여러 번 나눠 보내고 있어요", 25, lambda c: c.recent_attempts >= SPLIT_ATTEMPTS),
)

PATTERN_LABEL = "AI가 평소 거래 패턴과 다르다고 판단했어요"
SLEEP_LABEL = "수면 안심 시간(23:00~06:00)이라 보호자 확인이 필요해요"


@dataclass(frozen=True)
class Sample:
    """학습·판정에 쓰는 출금 한 건."""

    amount: int
    hour: int
    is_new: bool = False
    burst: int = 0  # 직전 10분 동안의 출금 수


@dataclass(frozen=True)
class AnomalyResult:
    anomaly: bool
    strength: float  # 0~1, 평소와 멀수록 큼
    decision: float  # IsolationForest decision_function (음수면 이상치)
    trained_on: int


@dataclass(frozen=True)
class RiskResult:
    score: int
    level: str
    signals: list[Signal]
    needs_approval: bool
    anomaly: AnomalyResult | None = None
    sleep_window: bool = False

    def to_dict(self) -> dict:
        return {
            "score": self.score,
            "level": self.level,
            "signals": [asdict(s) for s in self.signals],
            "needs_approval": self.needs_approval,
            "sleep_window": self.sleep_window,
            "model": (
                {
                    "name": "IsolationForest",
                    "anomaly": self.anomaly.anomaly,
                    "strength": round(self.anomaly.strength, 3),
                    "decision": round(self.anomaly.decision, 4),
                    "trained_on": self.anomaly.trained_on,
                }
                if self.anomaly
                else None
            ),
        }


def features(s: Sample) -> list[float]:
    angle = 2 * math.pi * (s.hour % 24) / 24
    return [
        math.log10(max(s.amount, 0) + 1),
        math.sin(angle),
        math.cos(angle),
        1.0 if s.is_new else 0.0,
        float(min(s.burst, 5)),
    ]


@dataclass
class AnomalyDetector:
    """사용자별 Isolation Forest. 이력이 적으면 부트스트랩 + 잡음으로 학습 데이터를 늘립니다."""

    random_state: int = 42
    augment_to: int = 256
    min_samples: int = 8
    _model: IsolationForest | None = field(default=None, init=False, repr=False)
    _trained_on: int = field(default=0, init=False)

    @property
    def ready(self) -> bool:
        return self._model is not None

    def fit(self, samples: Sequence[Sample]) -> bool:
        if len(samples) < self.min_samples:
            self._model = None
            self._trained_on = 0
            return False
        rng = np.random.default_rng(self.random_state)
        base = list(samples)
        rows = [features(s) for s in base]
        while len(rows) < self.augment_to:
            s = base[int(rng.integers(len(base)))]
            amount = max(1, int(s.amount * float(np.exp(rng.normal(0, 0.18)))))
            hour = int(round(s.hour + rng.normal(0, 1.0))) % 24
            rows.append(features(Sample(amount, hour, s.is_new, s.burst)))
        model = IsolationForest(n_estimators=150, contamination="auto", random_state=self.random_state)
        model.fit(np.asarray(rows))
        self._model = model
        self._trained_on = len(base)
        return True

    def score(self, sample: Sample) -> AnomalyResult | None:
        if self._model is None:
            return None
        decision = float(self._model.decision_function(np.asarray([features(sample)]))[0])
        strength = min(1.0, max(0.0, -decision / 0.12))
        return AnomalyResult(decision < 0, strength, decision, self._trained_on)


class FdsEngine:
    """규칙 + 사용자별 이상치 모델. 모델은 이력이 바뀔 때만 다시 학습합니다."""

    def __init__(self) -> None:
        self._detectors: dict[str, tuple[tuple, AnomalyDetector]] = {}

    def reset(self) -> None:
        self._detectors.clear()

    def detector(self, member_id: str, history: Sequence[Sample], fingerprint: tuple) -> AnomalyDetector:
        cached = self._detectors.get(member_id)
        if cached and cached[0] == fingerprint:
            return cached[1]
        det = AnomalyDetector()
        det.fit(history)
        self._detectors[member_id] = (fingerprint, det)
        return det

    def assess(
        self,
        ctx: TransferContext,
        detector: AnomalyDetector | None = None,
    ) -> RiskResult:
        signals = [Signal(r.id, r.label, r.weight) for r in RULES if r.test(ctx)]

        anomaly = None
        if detector is not None and detector.ready:
            anomaly = detector.score(Sample(ctx.amount, ctx.hour, ctx.is_new, ctx.recent_attempts))
            if anomaly and anomaly.anomaly:
                signals.append(Signal("pattern", PATTERN_LABEL, round(5 + 10 * anomaly.strength)))

        if ctx.sleep_window:
            signals.append(Signal("sleep", SLEEP_LABEL, 0))

        score = min(99, BASE_SCORE + sum(s.weight for s in signals))
        level = "high" if score >= HIGH_SCORE else "caution" if score >= CAUTION_SCORE else "safe"
        needs_approval = level != "safe" or ctx.amount >= ctx.approval_threshold or ctx.sleep_window
        return RiskResult(score, level, signals, needs_approval, anomaly, ctx.sleep_window)
