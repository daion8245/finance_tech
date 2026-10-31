"""FastAPI 앱 팩토리. 실행은 app.asgi 모듈을 쓰세요 (uvicorn app.asgi:app)."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Iterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import APIRouter, Depends, FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, select

from . import clock
from .config import Settings
from .db import Base, make_engine, make_session_factory
from .domain.fds import FdsEngine
from .events import EventHub
from .integrations import Gateways
from .models import Guardian
from .schemas import (
    AckBody,
    ApprovalRequestBody,
    ArsCallback,
    CallbackDecision,
    LimitBody,
    MemberRequest,
    ModeBody,
    PaymentBody,
    SleepGuardBody,
    SosFreezeRequest,
    TransferDraft,
    UnfreezeBody,
)
from .seed import reset_schema, schema_outdated, seed
from .service import DomainError, FamilyService

log = logging.getLogger("fingerbell")


def create_app(settings: Settings | None = None, gateways: Gateways | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    engine = make_engine(settings.database_url)
    sessions = make_session_factory(engine)
    fds = FdsEngine()
    hub = EventHub()
    gateways = gateways or Gateways()

    def ensure_seeded() -> None:
        if schema_outdated(engine):
            log.warning("DB 구조가 바뀌어 시연 데이터를 새로 만듭니다")
            reset_schema(engine)
        Base.metadata.create_all(engine)
        with sessions() as s:
            if s.scalars(select(Guardian).limit(1)).first() is None:
                seed(s)

    def run_tick() -> None:
        with sessions() as s:
            svc = FamilyService(s, settings, fds, gateways, hub)
            if svc.tick():
                svc.commit()
            else:
                s.rollback()

    async def ticker() -> None:
        while True:
            await asyncio.sleep(settings.tick_seconds)
            try:
                await asyncio.to_thread(run_tick)
            except Exception:  # 점검 하나가 실패해도 다음 점검은 계속합니다
                log.exception("tick failed")

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        hub.bind_loop(asyncio.get_running_loop())
        ensure_seeded()
        task = asyncio.create_task(ticker())
        try:
            yield
        finally:
            task.cancel()

    app = FastAPI(
        title="FingerBell API",
        description="핑거벨 안심 뱅킹 백엔드: SOS 계좌 동결 · AI FDS · 보호자 콜백 승인 · 상황별 안심 모드",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.engine = engine
    app.state.sessions = sessions
    app.state.fds = fds
    app.state.hub = hub
    app.state.run_tick = run_tick

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(DomainError)
    async def domain_error(_: Request, exc: DomainError):
        return JSONResponse({"error": {"code": exc.code, "message": exc.message, **exc.extra}}, status_code=exc.status)

    @app.exception_handler(RequestValidationError)
    async def invalid(_: Request, exc: RequestValidationError):
        return JSONResponse(
            {"error": {"code": "invalid", "message": "요청 형식이 올바르지 않아요.", "details": jsonable_encoder(exc.errors())}},
            status_code=422,
        )

    def service(request: Request) -> Iterator[FamilyService]:
        origin = request.headers.get("x-fingerbell-client")
        with sessions() as s:
            yield FamilyService(s, settings, fds, gateways, hub, origin=origin[:40] if origin else None)

    def done(svc: FamilyService, result):
        svc.commit()
        return result

    def check_guardian(svc: FamilyService, guardian_id: str) -> None:
        if svc.guardian().id != guardian_id:
            raise DomainError("forbidden", "보호자만 할 수 있어요.", 403)

    api = APIRouter(prefix="/api/v1")

    @api.get("/health")
    def health():
        return {"status": "ok", "time": clock.now().isoformat(), "realtime_clients": hub.client_count}

    @api.get("/state")
    def state(svc: FamilyService = Depends(service)):
        return svc.snapshot()

    # ---------------- 핵심 기능 1: 원터치 SOS 계좌 동결
    @api.post("/security/sos-freeze")
    @api.post("/emergency/freeze", include_in_schema=False)
    def sos_freeze(body: SosFreezeRequest, svc: FamilyService = Depends(service)):
        return done(svc, svc.freeze(body.user_id, body.trigger_type, body.sensor_intensity))

    @api.post("/security/unfreeze-request")
    def unfreeze_request(body: MemberRequest, svc: FamilyService = Depends(service)):
        return done(svc, svc.request_unfreeze(body.member_id))

    @api.post("/security/unfreeze")
    def unfreeze(body: UnfreezeBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        return done(svc, svc.unfreeze(body.member_id))

    # ---------------- 핵심 기능 2: AI FDS + 보호자 콜백 승인
    @api.post("/transaction/assess")
    def assess(body: TransferDraft, svc: FamilyService = Depends(service)):
        return svc.assess_transfer(body.member_id, body.to_draft())

    @api.post("/transaction/transfer")
    def transfer(body: TransferDraft, svc: FamilyService = Depends(service)):
        return done(svc, svc.submit_transfer(body.member_id, body.to_draft()))

    @api.post("/transaction/request-approval")
    def request_approval(body: ApprovalRequestBody, svc: FamilyService = Depends(service)):
        draft = {
            "new_account": {"bank": body.recipient_bank, "number": body.recipient_account, "name": body.recipient_name},
            "amount": body.amount,
        }
        result = svc.submit_transfer(body.sender_id, draft, force_approval=True)
        risk = result["risk"]
        return done(
            svc,
            {
                "transaction_id": result["request"]["id"],
                "status": "PENDING_APPROVAL",
                "timeout_seconds": settings.approval_timeout_seconds,
                "risk_score": risk["score"],
                "risk_reasons": [s["label"] for s in risk["signals"]],
            },
        )

    @api.post("/guardian/callback-decision")
    def callback_decision(body: CallbackDecision, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        result = svc.decide(body.transaction_id, body.decision == "APPROVE", "guardian", body.reason)
        return done(svc, {"transaction_id": body.transaction_id, **result, "status": result["status"].upper()})

    @api.post("/guardian/ack")
    def ack(body: AckBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        return done(svc, svc.acknowledge(body.request_ids))

    @api.post("/ars/callback")
    def ars_callback(body: ArsCallback, svc: FamilyService = Depends(service)):
        result = svc.ars_answer(body.request_id, body.digit)
        return done(svc, {**result, "status": result["status"].upper()})

    # ---------------- 핵심 기능 3: 상황별 안심 모드 · 한도
    @api.post("/payments/pay")
    def pay(body: PaymentBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.pay(body.member_id, body.merchant_id))

    @api.post("/payments/request-approval")
    def pay_request(body: PaymentBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.request_payment(body.member_id, body.merchant_id))

    @api.post("/modes")
    def set_mode(body: ModeBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_mode(body.member_id, body.mode, body.actor.lower()))

    @api.post("/guardian/limits")
    def set_limit(body: LimitBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_daily_limit(body.member_id, body.daily_limit))

    @api.post("/guardian/sleep-guard")
    def sleep_guard(body: SleepGuardBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_sleep_guard(body.member_id, body.enabled))

    # ---------------- 기타
    @api.post("/members/{member_id}/notices/{notice_id}/dismiss")
    def dismiss(member_id: str, notice_id: str, svc: FamilyService = Depends(service)):
        return done(svc, svc.dismiss_notice(member_id, notice_id))

    @api.get("/integrations/logs")
    def logs(limit: int = 30, svc: FamilyService = Depends(service)):
        return {"logs": svc.integration_logs(limit)}

    @api.post("/demo/reset")
    def demo_reset():
        reset_schema(engine)
        fds.reset()
        with sessions() as s:
            seed(s)
        hub.publish([{"type": "reset", "message": "시연 데이터를 처음 상태로 되돌렸어요"}])
        return {"status": "done"}

    @api.websocket("/ws")
    async def realtime(ws: WebSocket):
        await hub.connect(ws)
        try:
            await ws.send_json({"type": "hello", "message": ""})
            while True:
                # 앱이 보내는 ping을 받아 연결이 살아 있는지 확인만 합니다
                await ws.receive_text()
        except WebSocketDisconnect:
            pass
        finally:
            hub.disconnect(ws)

    app.include_router(api)

    if settings.web_dir:
        web = Path(settings.web_dir)
        if (web / "index.html").is_file():
            app.mount("/", StaticFiles(directory=web, html=True), name="web")
        else:
            log.warning("FINGERBELL_WEB_DIR에 index.html이 없어 웹 앱을 제공하지 않습니다: %s", web)

    # 테스트와 첫 실행에서 테이블이 바로 필요할 수 있으므로 미리 만들어 둡니다
    if not inspect(engine).get_table_names():
        ensure_seeded()

    return app

