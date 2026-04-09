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
