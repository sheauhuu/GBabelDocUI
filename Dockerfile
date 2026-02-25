# ============ Build stage ============
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies (only needed for compiling C extensions)
RUN apt-get update && \
    apt-get install --no-install-recommends -y build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY pyproject.toml .
RUN uv pip install --system --no-cache -r pyproject.toml

COPY . .

# Break cache for babeldoc upgrade
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

RUN uv pip install --system --no-cache . && \
    uv pip install --system --no-cache --compile-bytecode -U babeldoc "pymupdf<1.25.3"

# ============ Runtime stage ============
FROM python:3.13-slim-bookworm

WORKDIR /app

# Install only runtime libraries (no build-essential)
RUN apt-get update && \
    apt-get install --no-install-recommends -y libgl1 libglib2.0-0 libxext6 libsm6 libxrender1 && \
    rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY --from=builder /app /app

# Warmup babeldoc assets (only once, in final image)
RUN babeldoc --version && babeldoc --warmup
RUN pdf2zh --version

EXPOSE 7860

ENV PYTHONUNBUFFERED=1
ENV MAX_CONCURRENT_TRANSLATIONS=1

CMD ["pdf2zh", "--gui"]
