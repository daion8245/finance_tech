"""uvicorn 진입점: uvicorn app.asgi:app --host 0.0.0.0 --port 8000"""

from .main import create_app

app = create_app()
