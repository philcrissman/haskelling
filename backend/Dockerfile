# Build from the repo root:
#   docker build -f backend/Dockerfile -t haskelling .

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM haskell:9.12 AS builder

WORKDIR /app

# System libs required to compile Haskell deps (libpq-dev, zlib)
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev \
      pkg-config \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Dependency layer — cached as long as haskelling.cabal doesn't change.
# cabal 3.14 builds the local library as part of dep resolution, so we
# create placeholder source files. The local build will fail (TH, missing
# imports) but all external packages make it into the cabal store first.
COPY backend/haskelling.cabal ./
RUN mkdir -p src app \
 && for m in API Database Judge0 Schema Seed Server; do \
      printf "module %s where\n" "$m" > "src/${m}.hs"; \
    done \
 && printf "module Main where\nmain :: IO ()\nmain = return ()\n" > app/Main.hs \
 && cabal update \
 && cabal build exe:haskelling 2>&1 || true

# Build the application
COPY backend/ ./
RUN cabal build exe:haskelling \
 && mkdir -p /out \
 && cp "$(find dist-newstyle -type f -name haskelling \
           -path '*/x/haskelling/build/haskelling/haskelling')" \
       /out/haskelling

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libffi8 \
      libgmp10 \
      libpq5 \
      zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -r -u 1001 -s /sbin/nologin haskelling

WORKDIR /app
COPY --from=builder /out/haskelling /app/haskelling

# Bake the curriculum into the image so the server can seed on startup
COPY curriculum/ /app/curriculum/

USER haskelling

ENV PORT=8080
ENV CURRICULUM_DIR=/app/curriculum
EXPOSE 8080

ENTRYPOINT ["/app/haskelling"]
