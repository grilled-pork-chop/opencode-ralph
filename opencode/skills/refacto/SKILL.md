---
name: refacto
description: "Clean up code after implementation: remove dead code, unused imports, AI slop comments, and enforce consistency with existing architecture. Use after a feature is complete or when asked to clean up code. Triggers on: clean up this code, refacto, remove dead code, clean the code, polish the implementation."
---

# Refacto

Clean up code that was just written. No new features, no behaviour changes — only removal and alignment.

---

## What This Skill Does

Given a list of files (or a branch), apply the following passes in order:

1. **Dead code** — remove unused functions, variables, constants, and branches
2. **Unused imports** — remove imports that are not referenced in the file
3. **Types** — add missing type annotations where the language supports them; do not change existing types
4. **Comments and docstrings** — remove AI slop (see below); keep only comments that explain non-obvious WHY
5. **Architecture alignment** — align naming, structure, and patterns with the surrounding codebase

After each pass: run typecheck. If it fails, fix it before moving to the next pass.

---

## AI Slop: What to Remove

AI-generated code tends to accumulate noise. Remove all of the following:

### Obvious comments
```python
# Initialize the list
items = []

# Return the result
return result
```

### Restating the function signature
```python
def get_user_by_id(user_id: int) -> User:
    """Gets a user by their ID."""  # ← delete this
```

### Section dividers and narration
```python
# --- Setup ---
# --- Main logic ---
# Now we process the data
# Finally, return
```

### Redundant variable names
```python
user_data_list = []          # ← just `users`
result_value = compute()     # ← just `result`
final_output_string = ""     # ← just `output`
```

### Over-engineered one-liners
```python
def add(a, b):
    """
    Adds two numbers together.
    
    Args:
        a: The first number
        b: The second number
    
    Returns:
        The sum of a and b
    """
    return a + b
```

---

## What NOT to Touch

- Logic and behaviour — if it works, leave it
- Comments explaining a non-obvious invariant, constraint, or workaround
- Architecture decisions made elsewhere in the codebase (don't introduce new patterns)
- Tests — only fix types or imports in test files, never restructure tests
- Configuration files

---

## How to Apply

### When given specific files
Run the five passes on each file. Commit when all files are clean and typecheck passes.

### When cleaning a branch
```bash
git diff main...HEAD --name-only
```
Run the five passes on every file in the output. Commit once, message: `refacto: post-feature cleanup`.

### When used as part of a Ralph US
1. Get the list of changed files from `git diff main...HEAD --name-only`
2. Apply the five passes
3. Run typecheck — fix any failures
4. Run tests if the project has them — fix any failures caused by the cleanup
5. Commit: `refacto: post-feature cleanup`
6. Update `.ralph/prd.json` to set `passes: true` for the cleanup story

---

## Commit Message

Always use:
```
refacto: post-feature cleanup
```

No body needed. The diff is self-explanatory.

---

## Checklist

Before marking done:

- [ ] No unused imports in any changed file
- [ ] No unused variables or dead functions
- [ ] No comments that describe what the code does (only why)
- [ ] No multi-line docstrings for trivial functions
- [ ] No bloated variable names (`_data`, `_value`, `_result`, `_output` suffixes on simple variables)
- [ ] Typecheck passes
- [ ] Tests pass (if project has them)
- [ ] One commit: `refacto: post-feature cleanup`
