---
name: checkpoint
description: |
  Record progress to subtask: Phase completion (from autoworker:code) or test results (from autoworker:test).
  Accepts explicit argument from upstream: phase=<N> or level=L<N>. Falls back to context inference.
  Ends by calling autoworker:dispatch.
argument-hint: "[phase=<N>|level=L<N>]"
---

# autoworker:checkpoint — Record Progress (Phase Check-off / Test Results)

Called after every autoworker:code or autoworker:test completion. Performs different record-keeping based on upstream type, then always calls autoworker:dispatch.

## Execution Flow

### 1. Locate Subtask

```
Glob `subtask_*.md` (exclude subtask_template.md) →
  0 found → stop, prompt to create subtask
  1 found → use directly (backward compatible)
  multiple → grep `status:` to filter:
    - Files without status field treated as active (backward compatible)
    - Exactly 1 active → use it
    - 0 active → list all files + status, prompt user to choose
    - >1 active → report anomaly
→ Read → locate "## Plan", "## Verification Plan", and "## Test Results" sections
```

### 2. Determine Upstream Type

**Priority 1 — Explicit argument** (preferred, eliminates guesswork):

- `phase=<N>` → upstream is autoworker:code, Phase N completed
- `level=L<N>` → upstream is autoworker:test, test layer LN completed

**Priority 2 — Conversation context inference** (fallback when no argument):

- Conversation contains Phase implementation content → upstream is autoworker:code
- Conversation contains test execution output → upstream is autoworker:test

**If neither argument nor context is clear** → report error, do not guess. Ask upstream skill to re-invoke with explicit argument.

### 3a. Upstream is autoworker:code → Phase Check-off

1. Extract the just-completed Phase number and Step list from conversation context
2. Edit subtask's "Plan" section: check off all Steps for that Phase `[x]`
3. Append completion record in "Progress Log" section:

```markdown
**Phase X complete**
<brief change description>
```

### 3b. Upstream is autoworker:test → Test Results Write

1. Extract test level and per-item results from conversation context
2. Edit subtask's "Test Results" section, format:

```markdown
### L<N>
- `<command>`: <output summary> PASS/FAIL
```

3. Check off passed items `[x]` in the "Verification Plan" section

### 4. Judgment Criteria

**Hard standard for "pass"**:
- Function completes expected task and returns **meaningful results**
- Returning empty array/empty string without error ≠ pass
- "No exception thrown" ≠ pass

### 5. Output Summary

```
Checkpoint recorded:
- Type: Phase completion / Test record
- Content: Phase X checked off / L<N> results written
→ Invoking autoworker:dispatch
```

### 6. Chain: Immediately Invoke autoworker:dispatch

**After outputting the summary, immediately invoke `autoworker:dispatch` IN THE SAME RESPONSE. Do not wait for user instructions, do nothing else.**

**🚨 SAME-RESPONSE RULE**: The summary AND the `autoworker:dispatch` invocation MUST be in the same response. Output the summary, then output `[CHAIN → dispatch]`, then invoke `autoworker:dispatch`. NEVER output the summary alone and stop.

## Important Notes

- **Do not return to user mid-way**: After recording, go directly to autoworker:dispatch — don't report or ask
- **Do not skip verification plan items**: The verification plan is a carefully considered product — don't ad-hoc decide "this one doesn't need testing"
- **Chaining is mandatory**: Must invoke autoworker:dispatch after completion, cannot skip or manually substitute
