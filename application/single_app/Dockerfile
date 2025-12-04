
# -------- Builder: create venv and install deps (glibc-based) --------
FROM python:3.11-slim AS builder
WORKDIR /app

# Minimal system tools (kept tiny; we do NOT add heavy build-essential)
# Prebuilt wheels for SciPy on glibc mean no Fortran toolchain is needed.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-venv \
 && rm -rf /var/lib/apt/lists/*

# Create virtualenv
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Copy requirements and install. Install numpy first (ABI) then the rest.
COPY application/single_app/requirements.txt .
RUN pip install --no-cache-dir "numpy==2.1.1" \
 && pip install --no-cache-dir -r requirements.txt

# -------- Runtime: copy app + venv and run --------
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

# Add a non-root user for runtime
RUN useradd -m -u 1000 appuser

# ✅ Create writable session directory (this is the correct place)
RUN mkdir -p /tmp/flask_session && chown appuser:appuser /tmp/flask_session

# Copy only what we need
COPY --chown=appuser:appuser application/single_app ./ 
COPY --from=builder --chown=appuser:appuser /app/venv /app/venv

EXPOSE 5000
USER appuser

# Keep your current Python entrypoint; upgrade to gunicorn later if desired
ENTRYPOINT [ "python", "/app/app.py" ]
