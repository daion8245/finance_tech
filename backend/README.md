# FingerBell 백엔드 (FastAPI)

핑거벨의 핵심 시스템이 모두 서버에서 동작합니다. 앱은 결과를 그리기만 하고, 위험도·차단 여부·타이머는 서버가 정합니다.

| 파일 | 역할 |
| :--- | :--- |
| `app/main.py` | FastAPI 앱 팩토리, 라우트, WebSocket, 1초마다 도는 타이머(동결 만료 · ARS 발신 · 3분 타임아웃) |
| `app/service.py` | 업무 로직: SOS 동결/해제, 송금 보류·승인, 결제 제어, 모드·한도, 상태 스냅샷 |
| `app/domain/fds.py` | AI FDS: 규칙 점수 + 사용자별 Isolation Forest (scikit-learn) |
| `app/domain/catalog.py` | 안심 모드, 업종 MCC, 시연 가맹점 |
| `app/integrations.py` | 오픈뱅킹 · FCM · SMS · ARS 어댑터 (지금은 모의) |
| `app/seed.py` | 시연 가족(김사랑 보호자, 김순자 어르신, 이민준 아이)과 FDS 학습용 과거 거래 |
| `tests/` | pytest 46개 |

## 실행

저장소 루트에서 `.\run-backend.ps1`을 쓰는 것이 가장 쉽습니다. 직접 실행하려면:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.asgi:app --host 127.0.0.1 --port 8765
```

## 테스트

```powershell
.\.venv\Scripts\python.exe -m pytest
```

테스트는 임시 SQLite와 고정된 시각(`app.clock.freeze_at`)을 써서, 3분 타임아웃·24시간 만료·심야 판정을 실제로 기다리지 않고 확인합니다.

## 실제 연동으로 바꾸기

`app/integrations.py`의 `OpenBankingGateway`, `PushGateway`, `SmsGateway`, `ArsGateway`와 같은 메서드를 가진 클래스를 만들고 `create_app(gateways=Gateways(...))`로 넘기면 됩니다. ARS 업체의 키 입력 웹훅은 `POST /api/v1/ars/callback`(`request_id`, `digit`)으로 받습니다.
