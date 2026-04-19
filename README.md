# Opencode-Ralph

Ralph is an autonomous AI agent loop built on [OpenCode](https://opencode.ai). It runs inside a Docker image and executes PRD user stories one at a time — each iteration is a fresh OpenCode instance with clean context. Memory persists via git history, `.ralph/progress.txt`, and `.ralph/prd.json`.

## How It Works

```
issue description
      ↓
   @prd  →  .ralph/prd.md
      ↓
@ralph-converter  →  .ralph/prd.json
      ↓
   ralph (loop)  →  commits on feature branch
      ↓
  @reporter  →  .ralph/mr.md  →  MR
```

Each iteration Ralph:
1. Reads `.ralph/prd.json` from the project directory
2. Picks the highest priority story where `passes: false`
3. Implements that single story
4. Runs quality checks (typecheck, tests)
5. Commits if checks pass, marks story `passes: true`, appends to `.ralph/progress.txt`
6. Repeats until all stories pass or max iterations reached

## Standard Workflow (inside the Docker image)

### Step 1 — Generate a PRD

Use the `@prd` agent to create a requirements document from a feature description:

```
@prd Add a dynamic greeting feature to app.sh
```

The agent saves the output to `.ralph/prd.md`.

### Step 2 — Convert PRD to `prd.json`

Use the `@ralph-converter` agent to convert the markdown PRD to the JSON format Ralph understands:

```
@ralph-converter
```

This reads `.ralph/prd.md` and writes `.ralph/prd.json` with user stories ready for autonomous execution.

### Step 3 — Run Ralph

```bash
ralph [max_iterations]
```

Default is 10 iterations. `.ralph/prd.json` must exist in the project directory.

```bash
# Override paths explicitly
RALPH_DATA_DIR=/workspace ralph 15
RALPH_DIR=/workspace/.ralph ralph 15
```

## Docker Image

The image bakes in:
- OpenCode CLI with project config (`agents`, `skills`, `commands`)
- `ralph` binary at `/usr/local/bin/ralph` (globally available)
- Ralph prompt template at `/usr/local/share/ralph/prompt.md`

Environment variables:

| Variable          | Default                             | Purpose                                                |
| ----------------- | ----------------------------------- | ------------------------------------------------------ |
| `RALPH_HOME`      | `/usr/local/share/ralph`            | Directory containing `prompt.md`                       |
| `RALPH_DATA_DIR`  | `$PWD`                              | Project root                                           |
| `RALPH_DIR`       | `$RALPH_DATA_DIR/.ralph`            | Where `prd.json`, `progress.txt`, archives live        |
| `VLLM_API_URL`    | `http://ai-server.internal:8000/v1` | vLLM endpoint                                          |
| `VLLM_MODEL_NAME` | `codestral-22b`                     | Model to use                                           |
| `VLLM_API_KEY`    | `local-secret`                      | API key for the vLLM endpoint                          |

Build the image:

```bash
docker build -t ralph .
```

Run against a local project:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -e VLLM_API_URL=http://your-server:8000/v1 \
  -e VLLM_API_KEY=your-key \
  ralph ralph 10
```

## GitLab CI

The `.gitlab-ci.yml` runs Ralph nightly on issues labelled `ai-ralph`:

1. Fetches open issues with the target label
2. Creates a branch per issue (`ai/ralph-<iid>-<title>`)
3. Runs the full chain: `@prd` → `@ralph-converter` → `ralph` → `@reporter`
4. On `<promise>COMPLETE</promise>` → commits, opens an MR
5. On max iterations reached without COMPLETE → logs INCOMPLETE in artifacts

## Key Files

| File                                 | Purpose                                                      |
| ------------------------------------ | ------------------------------------------------------------ |
| `ralph-scripts/ralph.sh`             | The bash loop that spawns fresh OpenCode instances           |
| `ralph-scripts/prompt.md`            | Instructions given to each OpenCode instance                 |
| `opencode/agents/prd.md`             | Agent for generating PRDs (`@prd`)                           |
| `opencode/agents/ralph-converter.md` | Agent for converting PRDs to `.ralph/prd.json` (`@ralph-converter`) |
| `opencode/agents/reporter.md`        | Agent for generating MR descriptions (`@reporter`)           |
| `opencode/commands/prd.md`           | Command for generating PRDs (`/prd`)                         |
| `opencode/commands/ralph.md`         | Command for converting PRDs (`/ralph`)                       |
| `opencode/skills/ralph/SKILL.md`     | Skill with ralph conversion logic                            |
| `opencode/skills/prd/SKILL.md`       | Skill with PRD generation logic                              |
| `entrypoint.sh`                      | Docker entrypoint — writes `opencode.json` from env vars     |

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new OpenCode instance** with no memory of previous work. The only continuity between iterations is:
- Git history (commits from previous iterations)
- `.ralph/progress.txt` (learnings and codebase patterns)
- `.ralph/prd.json` (which stories are done)

### Story Size

Each story must be completable in one context window. If a story is too big, the LLM runs out of context and produces broken code.

Right-sized:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green — broken code compounds across iterations

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and exits 0.

## Debugging

```bash
# See which stories are done
cat .ralph/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat .ralph/progress.txt

# Check git history
git log --oneline -10
```

## Archives

When you start a new feature (different `branchName` in `.ralph/prd.json`), Ralph automatically archives the previous run to `.ralph/archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [OpenCode documentation](https://opencode.ai/docs)
