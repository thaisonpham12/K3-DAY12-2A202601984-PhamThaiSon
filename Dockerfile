# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Build dependencies
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .

# Install dependencies to /install prefix
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime image
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy the rest of the source code
COPY . .

# Create a non-root user for security
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Expose port (default 8000)
EXPOSE 8000

# Health check calling /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

# Start uvicorn, reading port from PORT env (default to 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
