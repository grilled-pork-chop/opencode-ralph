# Opencode-Ralph

Ralph is an autonomous AI agent loop built on [OpenCode](https://opencode.ai). It
runs inside a Docker image and executes PRD user stories one at a time — each
iteration is a **fresh OpenCode instance with clean context**. Continuity between
iterations comes only from git history, `.ralph/progress.txt`, and `.ralph/prd.json`.

```
issue description
      ↓
   /prd  →  .ralph/prd.md
      ↓
/ralph-converter  →  .ralph/prd.json
      ↓
   ralph (loop)  →  commits on feature branch
      ↓
    /mr  →  .ralph/mr.md  →  MR
```

Each iteration Ralph reads `.ralph/prd.json`, picks the highest-priority story
where `passes: false`, implements that single story, runs quality checks
(typecheck, tests), and — if they pass — commits, marks the story `passes: true`,
and appends learnings to `.ralph/progress.txt`. It repeats until all stories pass
or `max_iterations` is reached.

## Workflow (inside the Docker image)

```bash
# 1. Generate a PRD from a feature description
opencode run "/prd Add a dynamic greeting feature to app.sh"   # → .ralph/prd.md

# 2. Convert the PRD to the JSON format Ralph understands
opencode run "/ralph-converter"                                # → .ralph/prd.json

# 3. Run the loop (default 100 iterations; .ralph/prd.json must exist)
ralph [max_iterations]

# 4. Generate an MR description from the completed run
opencode run "/mr"                                             # → .ralph/mr.md
```

Paths can be overridden explicitly: `RALPH_DATA_DIR=/workspace ralph 15`.

## Docker

The image bakes in the OpenCode CLI with project config (`agents`, `skills`,
`commands`), the `ralph` binary at `/usr/local/bin/ralph`, and the prompt template
at `/usr/local/share/ralph/prompt.md`.

```bash
docker build -t ralph .

docker run --rm \
  -v $(pwd):/workspace \
  -e VLLM_API_URL=http://your-server:8000/v1 \
  -e VLLM_API_KEY=your-key \
  ralph ralph 100
```

| Variable          | Default                     | Purpose                                         |
| ----------------- | --------------------------- | ----------------------------------------------- |
| `RALPH_HOME`      | `/usr/local/share/ralph`    | Directory containing `prompt.md`                |
| `RALPH_DATA_DIR`  | `$PWD`                      | Project root                                    |
| `RALPH_DIR`       | `$RALPH_DATA_DIR/.ralph`    | Where `prd.json`, `progress.txt`, archives live |
| `VLLM_API_URL`    | `http://localhost:8000/v1`  | vLLM endpoint                                   |
| `VLLM_MODEL_NAME` | `codestral-22b`             | Model to use                                    |
| `VLLM_API_KEY`    | `local-secret`              | API key for the vLLM endpoint                   |

## GitLab CI

`.gitlab-ci.yml` runs Ralph on issues labelled `ai-ralph`: it fetches open issues
with the target label (or a single issue via `ISSUE_IID`), creates a branch per
issue, runs the full `/prd` → `/ralph-converter` → `ralph` → `/mr` chain, and on
completion commits and opens an MR. Runs without completing are logged in the
job artifacts.

Set these as **protected/masked CI/CD variables** (never in the YAML):

| Variable            | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `PROJECT_BOT_TOKEN` | GitLab project access token with `api` + `write_repository` scopes |
| `VLLM_API_URL`      | vLLM endpoint (override the YAML default for production)           |
| `VLLM_API_KEY`      | API key for vLLM                                                   |

Trigger it from **CI/CD → Pipelines → Run pipeline** (set `ISSUE_IID` to target a
single issue), via the pipeline trigger API, or on a schedule. The pipeline
variables (`ISSUE_IID`, `TARGET_LABEL`, `RALPH_MAX_ITERATIONS`, `MAIN_BRANCH`,
`VLLM_MODEL_NAME`) are documented inline in the YAML and editable in the Run
pipeline UI.

## Key files

| File                                   | Purpose                                            |
| -------------------------------------- | -------------------------------------------------- |
| `ralph-scripts/ralph.sh`               | The bash loop that spawns fresh OpenCode instances |
| `ralph-scripts/prompt.md`              | Instructions given to each OpenCode instance       |
| `opencode/agents/`                     | `@prd`, `@ralph-converter`, `@mr` agents           |
| `opencode/commands/`                   | `/prd`, `/ralph-converter`, `/mr` commands         |
| `opencode/skills/`                     | Logic for PRD generation, conversion, MR, refacto  |
| `entrypoint.sh`                        | Writes `opencode.json` from env vars               |

## Concepts

- **Fresh context every iteration.** A new OpenCode instance has no memory of prior
  work — the only continuity is git history, `.ralph/progress.txt`, and
  `.ralph/prd.json`.
- **One story per context window.** Each story must be completable in a single
  context window (e.g. "add a DB column and migration", not "build the dashboard").
  Oversized stories run out of context and produce broken code.
- **Feedback loops are mandatory.** Typecheck and tests must catch regressions —
  broken code compounds across iterations, so CI has to stay green.
- **Stop condition.** When all stories are `passes: true`, Ralph emits
  `<promise>COMPLETE</promise>` and exits 0.
- **Archives.** Starting a new feature (different `branchName` in `prd.json`)
  auto-archives the previous run to `.ralph/archive/YYYY-MM-DD-feature-name/`.

## Debugging

```bash
cat .ralph/prd.json | jq '.userStories[] | {id, title, passes}'   # story status
cat .ralph/progress.txt                                            # learnings
git log --oneline -10                                              # what changed
```

## CI (this repo)

`.github/workflows/lint.yml` lints the shell scripts (shellcheck) and the
`Dockerfile` (hadolint) on every push and pull request to `main`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [OpenCode documentation](https://opencode.ai/docs)

## License

MIT — see [LICENSE](LICENSE).
