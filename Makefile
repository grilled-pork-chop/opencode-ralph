.DEFAULT_GOAL := help

# ── Configuration ─────────────────────────────────────────────────────────────
IMAGE_NAME     ?= opencode-ralph
TAG            := 1.4.3
VENDOR_DIR     := vendor
CONTAINER_NAME := opencode-ralph-run

# ── Download ──────────────────────────────────────────────────────────────────
.PHONY: download
download: download-api download-npm  ## Download the dependencies
	@echo "✓ All dependencies vendored in $(VENDOR_DIR)/"

.PHONY: download-api
download-api:
	@echo "→ Downloading models.dev api.json ..."
	@mkdir -p $(VENDOR_DIR)
	@curl -fsSL "https://models.dev/api.json" -o $(VENDOR_DIR)/api.json
	@echo "✓ $(VENDOR_DIR)/api.json ($(shell wc -c < $(VENDOR_DIR)/api.json) bytes)"

.PHONY: download-npm
download-npm:
	@echo "→ Installing opencode-ralph-loop into $(VENDOR_DIR)/node_modules ..."
	@mkdir -p $(VENDOR_DIR)/node_modules
	@npm install --prefix $(VENDOR_DIR) opencode-ralph-loop --no-save --silent
	@echo "✓ $(shell cat $(VENDOR_DIR)/node_modules/opencode-ralph-loop/package.json | jq -r '.name + "@" + .version')"


# ── Build ─────────────────────────────────────────────────────────────────────
.PHONY: build
build: ## Build the Docker image
	docker build -t $(IMAGE_NAME):$(TAG) .

# ── Dev / Test ────────────────────────────────────────────────────────────────
.PHONY: test
test: build ## Run basic smoke tests on the container
	@echo "Running smoke tests..."
	@# Test: Check if opencode version displayed
	docker run --rm $(IMAGE_NAME):$(TAG) --version
	@echo "✅ All tests passed!"

.PHONY: debug
debug: ## Drop into a shell inside the container
	docker run -it --rm --entrypoint /bin/bash $(IMAGE_NAME):$(TAG)

# ── Clean ─────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(VENDOR_DIR)
	@echo "✓ Cleaned"

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help