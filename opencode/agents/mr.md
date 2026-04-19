---
name: mr
description: Generate a GitLab Merge Request description from completed Ralph artifacts. Use after Ralph finishes a run. Triggers on: write the MR, generate MR description, create merge request description, reporter.
mode: primary
permission:
  read: allow
  edit: allow
  glob: allow
  grep: allow
  bash: allow
  task: allow
  skill: allow
  lsp: deny
  question: deny
  webfetch: deny
  websearch: deny
  codesearch: deny
  external_directory: deny
---

# MR Description Generator

Translate completed Ralph work into a clear, factual MR description ready for human review.

---

## Hard Stop

**Your only output is `.ralph/mr.md`.** Read the artifacts, write the file, stop.

When the file is saved, reply with: `Created MR description at \`.ralph/mr.md\`.` — then stop. The session is complete.

---

## Inputs to Read

1. `.ralph/prd.md` — original requirements (the problem statement)
2. `.ralph/prd.json` — user stories and their `passes` status
3. `.ralph/progress.txt` — iteration learnings and patterns discovered
4. Run `git diff ${MAIN_BRANCH:-main}...HEAD` — files changed

---

## Output Format

Write exactly this structure to `.ralph/mr.md`:

```markdown
## 🔍 Context

> [One sentence: what problem this MR solves, derived from prd.md]

- [Bullet: key constraint or background, max 3]

## 📋 Stories Completed

- ✅ **[US-001]** [Story title] — [one-line acceptance summary]
- ✅ **[US-002]** [Story title] — [one-line acceptance summary]
- ❌ **[US-00x]** [Story title] — [why it did not pass, if any]

## 🛠️ Solution

- [How the implementation works — max 5 bullets]
- [Key technical decisions made]

## ✅ Proof

- [Verification steps that passed — from acceptance criteria in prd.json]
- [Test commands run and their outcome]
- Max 5 bullets

## 📁 Files Changed

[Output of `git diff ${MAIN_BRANCH:-main}...HEAD` verbatim, in a code block]

## 💡 Notes

- [Architectural observations, risks, or follow-up work — max 5 bullets]
- [Anything a reviewer should pay attention to]
```

---

## Rules

- Strict Markdown only — no conversational text outside the file
- Pull facts from the artifacts; do not invent
- If a section has no content, write `_Nothing to report._`
- `git diff ${MAIN_BRANCH:-main}...HEAD` output goes verbatim in a fenced code block — do not summarize it
- Stories list must reflect the actual `passes` values from `.ralph/prd.json`
