---
name: dispatch
description: |
  Read subtask.md checkbox state and route to next skill. The ONLY routing point in the execution loop.
  Called after autoworker:checkpoint, autoworker:gate-check, autoworker:subtask-update, autoworker:subtask-plan, or when resuming after context loss.
  When lost, call autoworker:dispatch.
---

# autoworker:dispatch — Execution Chain Router (Sole Routing Point)

Reads subtask.md checkbox state and routes to the next skill based on fixed priority.

**When to call**: Automatically called after autoworker:checkpoint, autoworker:gate-check, autoworker:subtask-update, autoworker:subtask-plan complete, or manually called after context loss.

## Execution Flow

### 1. Locate Subtask

```
Glob `subtask_*.md` (exclude subtask_template.md) →
  0 found → 🚨 STOP: No subtask document exists
            → Check: Did user provide a NEW task?
            → YES: Report error "Missing subtask-init step" 
                   → Instruct to invoke autoworker:subtask-init first
                   → DO NOT proceed with routing
            → NO: Normal conversation (no task to dispatch)
  1 found → use directly (backward compatible)
  multiple → grep `status:` to filter:
    - Files without status field treated as active (backward compatible)
    - Exactly 1 active → use it
    - 0 active → list all files + status, prompt user to choose
    - >1 active → report anomaly
→ Read → extract:
- Plan section Phase checkbox states
- Verification plan section L1-L4 checkbox states
- Whether a `Gate result:` line exists and its value
```

**🚨 CRITICAL CHECK**: If no subtask files found AND user has given a task:
- This is a WORKFLOW VIOLATION
- Do NOT attempt to proceed
- Report: "⚠️ Workflow error: No subtask document found. Please invoke `autoworker:subtask-init` first to create the subtask document before execution."

### 2. Status Summary

Tally and output current state:

```
dispatch (subtask: <filename>):
- Phases: X/N complete
- Tests: L1 done/pending, L2 done/pending/skip, L3 done/pending/skip, L4 done/pending
- Gate: <empty/PASS/FAIL>
```

### 2.5. Verification Plan Integrity Check

**When all Phases are complete**, before routing to test or gate-check, validate that the verification plan has actual test items:

```
Check "Verification Plan" section → L4 subsection:
  - Has checkbox items (`- [ ]` or `- [x]`) → OK, continue routing
  - Empty (only heading, no items) → 🚨 STOP
    → Report: "⚠️ Verification plan L4 section is empty — 
       invoking autoworker:subtask-plan to complete it"
    → Immediately invoke autoworker:subtask-plan
    → DO NOT route to autoworker:test or autoworker:gate-check
```

**Why**: If subtask-plan wrote empty verification sections, dispatch would see "no untested layers" and skip directly to gate-check — bypassing the entire test cycle. This check prevents that silent bypass.

**This is a forced chain branch**: When L4 is empty, dispatch MUST invoke `autoworker:subtask-plan` (not just report). After subtask-plan fills in the verification plan, it will chain back to dispatch, which re-reads file state and continues routing normally.

### 3. Fixed Priority Routing

Evaluate in this order, **execute the first match, do not continue evaluating**:

0. **Verification plan L4 empty?** (Step 2.5 STOP) → invoke `autoworker:subtask-plan`
1. **Has incomplete Phase?** → invoke `autoworker:code`
2. **All Phases complete, has untested layer?** (must pass Step 2.5 first) → invoke `autoworker:test <level>` (pass the first incomplete level)
3. **All tests complete, no Gate result?** (must pass Step 2.5 first) → invoke `autoworker:gate-check`
4. **Gate result = PASS?** → invoke `autoworker:sync-docs` first, then output completion report (**terminal point, do not invoke any further skill after sync-docs**)
5. **Gate result = FAIL?** → invoke `autoworker:subtask-update`

### 4. Output Routing Decision

Append routing decision after the status summary:

```
→ Invoking autoworker:code to implement Phase Y
```
or
```
→ Invoking autoworker:test L2
```
or
```
→ Invoking autoworker:gate-check
```
or
```
→ Invoking autoworker:sync-docs to sync tracking documents before completion report.
```
or
```
Task complete! Outputting completion report.
→ To archive, invoke: autoworker:sync-docs archive
```
or
```
→ Invoking autoworker:subtask-update (Gate FAIL)
```

### 5. Execute Route

**After outputting the routing decision, immediately invoke the corresponding skill. Do not wait for user instructions, do nothing else.**

Only exception: Gate PASS — first invoke `autoworker:sync-docs` (no argument) to sync tracking documents, then output completion report with archive prompt. Do not invoke any other skill after sync-docs.

## Key Constraints

- **Only read checkboxes, do not infer or remember**: State comes entirely from the file, not from conversation context
- **Layers marked "skip" in the verification plan count as complete**: If the plan says "skip L2, reason: ..." and has no L2 items → treated as complete
- **Accepts no arguments**: Entirely driven by file state
- **Gate result reading method**: grep for `Gate result:` line (case-insensitive, trim whitespace), read PASS or FAIL. If format deviates slightly (extra spaces, capitalization), normalize it before routing. Matching pattern: line contains `gate result` (case-insensitive) AND contains `pass` or `fail`.
- **PASS is the only terminal point**: Only when Gate PASS does dispatch terminate the loop. On PASS, invoke `autoworker:sync-docs` before the completion report.

## Important Notes

- **dispatch is stateless**: Every invocation re-reads the file, ensuring consistency after context loss
- **Makes no modifications**: Does not edit files, write code, or run tests — only reads and routes
- **Loop-safe**: dispatch never calls itself — only calls autoworker:code, autoworker:test, autoworker:gate-check, or autoworker:subtask-update
