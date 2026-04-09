---
name: autoworker
description: "Start the autoworker execution workflow for any non-trivial task."
---

## 🔒 MANDATORY PROTOCOL (Execute BEFORE reading the skill)

You MUST complete this protocol before ANY other action:

### Step 1: Classify (DO NOT SKIP)

Determine user intent from the message ABOVE this command:
- **NEW_TASK**: User describes something to implement/fix/build
- **RESUME**: User says "continue", or no specific new task
- **CONVERSATION**: User asks a question, no implementation needed

### Step 2: Output Lock Statement (MANDATORY)

You MUST output this EXACT format as your FIRST response content:

```
🔒 AUTOWORKER LOCK: [NEW_TASK | RESUME | CONVERSATION]
→ Action: [subtask-init | dispatch | normal]
```

### Step 3: Execute Based on Lock

- **NEW_TASK** → Invoke `autoworker:subtask-init` IMMEDIATELY. No reading code. No investigating. No exploring.
- **RESUME** → Glob `subtask_*.md`, then invoke `autoworker:dispatch`
- **CONVERSATION** → Invoke the autoworker skill for reference, respond normally

⚠️ If your Lock says NEW_TASK but your next action is NOT `autoworker:subtask-init`, you are VIOLATING the protocol. STOP and correct.

### Step 4: Load Skill

After completing Steps 1-3, invoke the `autoworker:autoworker` skill and follow it exactly.

### Step 5: Chain Continuation (CRITICAL)

**Once the execution chain starts, it MUST run continuously to completion (gate-check PASS).**

- Each skill's summary AND next-skill invocation MUST be in the **SAME response**
- Always output `[CHAIN → next_skill]` before invoking the next skill
- NEVER pause after a summary to wait for user response
- NEVER ask "Should I continue?" mid-chain
- If the chain is interrupted, resume immediately by invoking `autoworker:dispatch`
- The chain only terminates when gate-check returns PASS

This rule overrides any default behavior that might cause the chain to pause between skills.
