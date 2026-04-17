#!/bin/bash
set -e

# Ensure the config directory exists
mkdir -p /root/.config/opencode

# Create the dynamic config file using Environment Variables
cat <<EOF > /root/.config/opencode/opencode.json
{
  "permission": {
    "read": "allow",
    "edit": "allow",
    "glob": "allow",
    "grep": "allow",
    "bash": "allow",
    "task": "allow",
    "skill": "allow",
    "lsp": "deny",
    "question": "deny",
    "webfetch": "deny",
    "websearch": "deny",
    "codesearch": "deny",
    "external_directory": "deny"
  },
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local LLM",
      "options": {
        "baseURL": "${VLLM_API_URL:-http://localhost:8000/v1}",
        "apiKey": "${VLLM_API_KEY:-local-secret}"
      },
      "models": {
        "${VLLM_MODEL_NAME:-llama3}": {
          "name": "${VLLM_MODEL_NAME:-llama3}"
        }
      }
    }
  },
  "model": "local/${VLLM_MODEL_NAME:-llama3}"
}
EOF

echo "--- AI AGENT CONFIGURED ---"
echo "Target Model: ${VLLM_MODEL_NAME}"
echo "vLLM Endpoint: ${VLLM_API_URL}"

# Pass the command to the OpenCode CLI
exec opencode "$@"