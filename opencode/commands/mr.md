---
description: Generate .ralph/mr.md MR description from current .ralph/ artifacts. Usage: /mr
agent: mr
---

Use the mr agent to generate `.ralph/mr.md` from `.ralph/prd.md`, `.ralph/prd.json`, `.ralph/progress.txt`, and `git diff ${MAIN_BRANCH:-main}...HEAD`.
