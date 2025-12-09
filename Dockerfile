# Multi-stage Dockerfile for SimpleChat
FROM python:3.11-slim AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc git ffmpeg libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 libmagic1 \
 && rm -rf /var/lib/apt/lists/*

# Copy dependencies file from the single_app folder
COPY application/single_app/requirements.txt /app/requirements.txt

RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r /app/requirements.txt

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production \
    PORT=8000

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 libmagic1 \
 && rm -rf /var/lib/apt/lists/*

# Create folder for session files
RUN mkdir -p /app/flask_session && chown 1000:1000 /app/flask_session

# Copy installed packages from build stage
COPY --from=build /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=build /usr/local/bin /usr/local/bin

# Copy the application source
COPY . /app

EXPOSE ${PORT}

# Set PYTHONPATH so imports from application/single_app work
ENV PYTHONPATH=/app/application/single_app:$PYTHONPATH

# Run via Gunicorn using the Flask app located in application.single_app.app:app
CMD ["gunicorn", "--workers", "3", "--threads", "4", "--bind", "0.0.0.0:8000", "--chdir", "/app/application/single_app", "app:app"]
