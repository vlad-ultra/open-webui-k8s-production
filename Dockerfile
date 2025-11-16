FROM ghcr.io/open-webui/open-webui:latest

# Optional: install extra tools you may want inside the container (kept minimal)
# RUN apt-get update && apt-get install -y --no-install-recommends curl jq sqlite3 && rm -rf /var/lib/apt/lists/*

# Do NOT bake secrets into the image. All API keys must come from Kubernetes Secrets/env.


