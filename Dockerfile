FROM node:24.14.1-bullseye-slim

# ── Configuration ─────────────────────────────────────────────────────────────
ARG OPENCODE_VERSION=1.4.6

ENV NODE_ENV=production \
    OPENCODE_TELEMETRY=false \
    MODEL_DEV_API_JSON=/etc/opencode/api.json \
    VLLM_API_URL=http://ai-server.internal:8000/v1 \
    VLLM_MODEL_NAME=codestral-22b \
    TARGET_LABEL=ai-fix

# ── System tools ─────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── OpenCode CLI ──────────────────────────────────────────────────────────────
RUN npm install -g opencode-ai@${OPENCODE_VERSION} \
    && opencode --version

# ── Filesystem Setup ─────────────────────────────────────────────────────────
RUN mkdir -p /etc/opencode

# Copy metadata and configuration
COPY vendor/api.json          /etc/opencode/api.json

# ── Pre-install charfeng1/opencode-ralph-loop plugin ─────────────────────────
# OpenCode looks for npm plugins in ~/.cache/opencode/node_modules/ at startup.
COPY vendor/node_modules /root/.cache/opencode/node_modules
RUN echo "Bundled $(cat /root/.cache/opencode/node_modules/opencode-ralph-loop/package.json | jq -r '.name + "@" + .version')"

# ── Pre-copy plugin skills and commands ───────────────────────────────────────
# charfeng1 auto-copies these to ~/.config/opencode/ on first run.
# Doing it here at build time keeps the first CI invocation clean.
RUN PLUGIN_DIR=/root/.cache/opencode/node_modules/opencode-ralph-loop \
    && mkdir -p /root/.config/opencode/skills /root/.config/opencode/commands \
    && if [ -d "${PLUGIN_DIR}/skills" ]; then \
    cp -r "${PLUGIN_DIR}/skills/." /root/.config/opencode/skills/ \
    && echo "Installed ralph-loop skills"; \
    fi \
    && if [ -d "${PLUGIN_DIR}/commands" ]; then \
    cp -r "${PLUGIN_DIR}/commands/." /root/.config/opencode/commands/ \
    && echo "Installed ralph-loop commands"; \
    fi

# ── Execution ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--help"]