# Build from the repo root:
#   docker build -f backend/Dockerfile -t haskelling .

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM haskell:9.8.4 AS builder

WORKDIR /app

# System libs required to compile Haskell deps (libpq-dev, zlib)
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev \
      pkg-config \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Dependency layer — this expensive step is cached as long as haskelling.cabal
# doesn't change.
COPY backend/haskelling.cabal ./
RUN cabal update && cabal build --only-dependencies exe:haskelling

# Build the application
COPY backend/ ./
RUN cabal build exe:haskelling \
 && mkdir -p /out \
 && cp "$(find dist-newstyle -type f -name haskelling \
           -path '*/x/haskelling/build/haskelling/haskelling')" \
       /out/haskelling

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libffi7 \
      libgmp10 \
      libpq5 \
      zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -r -u 1001 -s /sbin/nologin haskelling

WORKDIR /app
COPY --from=builder /out/haskelling /app/haskelling

# Bake the curriculum into the image so the server can seed on startup
COPY CURRICULUM.json /app/CURRICULUM.json

USER haskelling

ENV PORT=8080
ENV CURRICULUM_PATH=/app/CURRICULUM.json
EXPOSE 8080

ENTRYPOINT ["/app/haskelling"]
