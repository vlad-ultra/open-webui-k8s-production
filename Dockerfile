FROM ghcr.io/open-webui/open-webui:latest

# Optional: install extra tools you may want inside the container (kept minimal)
# RUN apt-get update && apt-get install -y --no-install-recommends curl jq sqlite3 && rm -rf /var/lib/apt/lists/*

# Option A (current request): bake API key into image via build-arg (stored in image env)
# WARNING: This embeds the key into the image layers. Use only for private, per-env images.
ARG OPENROUTER_API_KEY=""
ENV OPENAI_API_KEY="${OPENROUTER_API_KEY}" \
    OPENAI__API_KEY="${OPENROUTER_API_KEY}"

# Note: Prefer injecting secrets at runtime via Kubernetes Secrets for security.


