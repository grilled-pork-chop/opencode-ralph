#!/bin/bash
# Ralph - Autonomous AI agent loop
# Usage: ralph [max_iterations]
#
# RALPH_HOME        — directory containing prompt.md (default: dir of this script)
# RALPH_DATA_DIR    — project root (default: $PWD)
# RALPH_DIR         — where prd.json, progress.txt, archive live (default: $RALPH_DATA_DIR/.ralph)

set -e

MAX_ITERATIONS=${1:-100}

RALPH_HOME=${RALPH_HOME:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}
RALPH_DATA_DIR=${RALPH_DATA_DIR:-$PWD}
RALPH_DIR=${RALPH_DIR:-$RALPH_DATA_DIR/.ralph}
PRD_FILE="$RALPH_DIR/prd.json"
PROGRESS_FILE="$RALPH_DIR/progress.txt"
ARCHIVE_DIR="$RALPH_DIR/archive"
LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
PROMPT_FILE="$RALPH_HOME/prompt.md"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt.md not found at $PROMPT_FILE"
  echo "Set RALPH_HOME to the directory containing prompt.md"
  exit 1
fi

if [ ! -f "$PRD_FILE" ]; then
  echo "ERROR: prd.json not found at $PRD_FILE"
  echo "Run: /ralph to generate it from .ralph/prd.md, or set RALPH_DATA_DIR"
  exit 1
fi

mkdir -p "$RALPH_DIR"

# Archive previous run if branch changed
if [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
[ -n "$CURRENT_BRANCH" ] && echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph"
echo "  RALPH_HOME     : $RALPH_HOME"
echo "  RALPH_DATA_DIR : $RALPH_DATA_DIR"
echo "  RALPH_DIR      : $RALPH_DIR"
echo "  Max iterations : $MAX_ITERATIONS"

for ((i = 1; i <= MAX_ITERATIONS; i++)); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  OUTPUT=$(opencode run "$(cat "$PROMPT_FILE")" 2>&1 | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks! (signal)"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Fallback: check prd.json directly — model may forget to emit the signal
  INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "-1")
  if [ "$INCOMPLETE" = "0" ]; then
    echo ""
    echo "Ralph completed all tasks! (verified via prd.json)"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
