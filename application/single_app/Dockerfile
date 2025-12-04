# Builder stage: install dependencies in a virtualenv
FROM cgr.dev/chainguard/python:latest-dev AS builder

WORKDIR /app


# Become root to install packages; Chainguard defaults to nonroot
USER root


# NOTE: package names may vary; key deps are gfortran, gcc, musl-dev, openblas-dev, lapack-dev, build-base
RUN apk add --no-cache \
    build-base \
    gfortran \
    musl-dev \
    openblas-dev \
    lapack-dev


# Create a Python virtual environment
RUN python -m venv /app/venv

# Copy requirements and install them into the virtualenv
COPY application/single_app/requirements.txt .
ENV PATH="/app/venv/bin:$PATH"


# (Optional) pre-install numpy before scipy to ensure ABI alignment
RUN pip install --no-cache-dir "numpy==2.1.1"

RUN pip install --no-cache-dir -r requirements.txt

FROM cgr.dev/chainguard/python:latest

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

# Copy application code and set ownership
COPY --chown=nonroot:nonroot application/single_app ./

# Copy the virtualenv from the builder stage
COPY --from=builder --chown=nonroot:nonroot /app/venv /app/venv

# Expose port
EXPOSE 5000

USER nonroot:nonroot

ENTRYPOINT [ "python", "/app/app.py" ]
