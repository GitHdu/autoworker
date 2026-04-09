---
name: code
description: |
  Implement ONE pending Phase from subtask plan. Only write code, do not mark checkboxes or run tests.
  Called by autoworker:dispatch. Ends by calling autoworker:checkpoint.
---

# autoworker:code — Implement One Phase

Called by autoworker:dispatch. Does one thing: implement the first incomplete Phase from the subtask plan.

## Execution Flow

### 1. Read Subtask

```
Glob `subtask_*.md` (exclude subtask_template.md) →
  0 found → stop, prompt to create subtask
  1 found → use directly (backward compatible)
  multiple → grep `status:` to filter:
    - Files without status field treated as active (backward compatible)
    - Exactly 1 active → use it
    - 0 active → list all files + status, prompt user to choose
    - >1 active → report anomaly
→ Read → extract:
- Plan section Phase list (with checkboxes)
- Find the first incomplete Phase (`- [ ]` prefixed Steps)
```

If subtask doesn't exist or plan is empty → **stop, prompt to complete autoworker:subtask-plan first**.
If all Phases are complete → **stop, prompt that autoworker:dispatch should route to autoworker:test**.

### 2. Implement Code

Read all Steps in the Phase, implement one by one:

1. Read Step description and target file
2. Read target file (if modifying)
3. Edit/Write to implement the code change
4. After completing the Step, continue to next Step

**Executing commands**: Steps may involve not just writing code but also executing commands (starting training, running scripts, etc.). Long-running commands use `run_in_background=true` — execute autonomously, do not ask the user to run manually. After starting background tasks like training, continue to the next step without waiting for completion.

**Forbidden**:
- Writing code from memory without reading subtask
- Skipping Steps (unless subtask explicitly marks as skippable)
- Checking off boxes yourself (autoworker:checkpoint's responsibility)
- Running tests yourself (autoworker:test's responsibility)
- Making changes beyond the current Phase's scope
- Asking user to manually execute commands that can be done autonomously

### 3. Output Summary

```
Phase X code implementation complete:
- Step X.1: <brief change description>
- Step X.2: <brief change description>
→ Invoking autoworker:checkpoint phase=X
```

### 4. Chain: Immediately Invoke autoworker:checkpoint phase=\<N\>

**After outputting the summary, immediately invoke `autoworker:checkpoint phase=<N>` IN THE SAME RESPONSE (where N is the Phase number just completed). Do not wait for user instructions, do nothing else.**

**The `phase=<N>` argument is mandatory** — it tells checkpoint exactly which Phase to check off, eliminating guesswork from conversation context.

**🚨 SAME-RESPONSE RULE**: The summary AND the `autoworker:checkpoint` invocation MUST be in the same response. Output the summary, then output `[CHAIN → checkpoint phase=<N>]`, then invoke `autoworker:checkpoint phase=<N>`. NEVER output the summary alone and stop.

## Key Constraints

- **Only one Phase**: Complete it and hand off to checkpoint — don't determine how many Phases remain
- **Only write code**: Don't check boxes, don't run tests, don't make routing decisions
- **Self-debug when hitting issues**: 2 consecutive failures with same approach → enter diagnostic mode (make assumptions explicit → minimum observable unit → build diagnostic tool)
- **Don't return to user mid-way**: Unless hitting a genuine blocker requiring human decision
- **Chain fallback on blocker**: Even when hitting a genuine blocker, invoke `autoworker:checkpoint phase=<N>` FIRST to record partial progress (completed Steps so far). In the checkpoint record, explicitly log the blocker reason and what decision/input is needed. If dispatch routes back and the same blocker persists on re-entry, DO NOT keep re-running — return a clear blocker report to the user with: (1) what was completed, (2) what is blocked, (3) what decision/input is needed. Only skip checkpoint entirely if it cannot be invoked (extreme edge case).

## Important Notes

- **Phase granularity**: A Phase typically contains 2-5 Steps, each Step is a specific file change
- **Files in current Phase**: If a Step says "modify file X", must Read the file before Edit
- **Chaining is mandatory**: Must invoke autoworker:checkpoint with `phase=<N>` argument after completion, cannot skip or manually substitute
