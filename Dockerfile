FROM node:24.14.1-bullseye-slim

# ── Configuration ─────────────────────────────────────────────────────────────
ARG OPENCODE_VERSION=1.4.6

ENV OP_HOME=/root

ENV OP_CONFIG=${OP_HOME}/.config/opencode \
    OP_CACHE=${OP_HOME}/.cache/opencode/cache

ENV NODE_ENV=production \
    OPENCODE_MODELS_URL=file://${OP_CACHE} \
    NODE_PATH=${OP_CACHE}/node_modules \
    VLLM_API_URL=http://ai-server.internal:8000/v1 \
    VLLM_MODEL_NAME=codestral-22b \
    TARGET_LABEL=ai-ralph \
    RALPH_HOME=/usr/local/share/ralph

# ── System tools ─────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── OpenCode CLI ──────────────────────────────────────────────────────────────
RUN npm install -g opencode-ai@${OPENCODE_VERSION} \
    && opencode --version

# ── Filesystem Setup ─────────────────────────────────────────────────────────
RUN mkdir -p ${OP_CONFIG} \
    ${OP_CACHE}

# Bake OpenCode config
COPY opencode/ ${OP_CONFIG}/

# Copy metadata and configuration
COPY vendor/ ${OP_CACHE}/

# ── Ralph CLI ────────────────────────────────────────────────────────────────
RUN mkdir -p /usr/local/share/ralph
COPY ralph-scripts/prompt.md /usr/local/share/ralph/prompt.md
COPY ralph-scripts/ralph.sh /usr/local/bin/ralph
RUN chmod +x /usr/local/bin/ralph

# ── Execution ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]