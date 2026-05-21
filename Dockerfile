# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Builder
# - Sesuaikan C_ENGINE_SOURCE / C_ENGINE_OUTPUT kalau nama file C atau .so berubah.
# ==============================================================================
FROM python:3.10-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY backend/engine/worthit_engine.c ./worthit_engine.c

# CUSTOMIZE IF NEEDED:
# - Source C saat ini: backend/engine/worthit_engine.c
# - Output binary yang dicari c_bridge.py: backend/engine/worthit_engine.so
RUN gcc -shared -fPIC -O2 -o worthit_engine.so worthit_engine.c -lm


# ==============================================================================
# Stage 2: Runner
# - Sesuaikan CMD kalau modul FastAPI bukan main:app.
# ==============================================================================
FROM python:3.10-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY backend/requirements.txt ./requirements.txt

RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY backend/ ./
COPY --from=builder /build/worthit_engine.so ./engine/worthit_engine.so

EXPOSE 8000

# CUSTOMIZE IF NEEDED:
# - FastAPI app saat ini: backend/main.py -> app, jadi target Uvicorn: main:app
# - Render/Koyeb biasanya menyediakan env PORT; fallback lokal tetap 8000.
# - WEB_CONCURRENCY bisa di-set di platform deploy, default 2 workers.
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-2}"]
