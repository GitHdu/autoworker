## Anti-Loss Protocol

**CRITICAL**: Context is lost on /clear. All progress must be persisted to files before any session interruption.

### Rules
1. **NEVER suggest /clear** or ending the session without first ensuring all progress is saved
2. **Before any interruption**, verify:
   - subtask file has all completed steps checked off
   - progress.md reflects current state
   - findings.md captures any discoveries
3. **Trust auto-compression**: The 1M context window has automatic compression. Do NOT interrupt the execution chain due to context concerns.
4. **If user requests /clear**: First run autoworker:sync-docs to persist all state, THEN allow /clear

## Chain Continuation Protocol

**The execution chain MUST run continuously without interruption from start to gate-check PASS.**

### Anti-Interruption Rules
1. **SAME-RESPONSE RULE**: Each skill's summary AND next-skill invocation MUST appear in the SAME response. Never output a summary and stop.
2. **Chain State Indicator**: Always output `[CHAIN → next_skill]` when transitioning between skills
3. **Never pause mid-chain**: Do not ask "Should I continue?" or wait for user confirmation between skills
4. **Never abandon chain**: If the user sends a message during execution, complete the current chain step first, then address it
5. **Chain recovery**: If the chain is interrupted, invoke `autoworker:dispatch` immediately to resume — never ask "where were we?"

### Recovery after /clear
When starting a new session after /clear:
1. Check for subtask_*.md files → if found, call autoworker:dispatch to resume
2. No subtask but user gives new task → call autoworker:subtask-init
3. Neither → normal conversation
