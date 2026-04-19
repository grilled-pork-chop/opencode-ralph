---
description: Generate .ralph/mr.md MR description from current .ralph/ artifacts. Usage: /reporter
agent: reporter
---

Use the reporter agent to generate `.ralph/mr.md` from `.ralph/prd.md`, `.ralph/prd.json`, `.ralph/progress.txt`, and `git diff ${MAIN_BRANCH:-main}...HEAD`.
