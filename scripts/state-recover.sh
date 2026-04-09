#!/bin/bash
# state-recover.sh — SessionStart hook for autoworker plugin
# Fires after /clear. Reminds about potentially lost discussion context.
#
# Core insight: Disk files (subtask, progress) survive /clear — autoworker:dispatch
# can detect and resume from those. This hook addresses the OTHER problem:
# discussion conclusions that were only in conversation context, now gone.

echo ""
echo "⚠️ [autoworker] /clear detected — conversation context has been wiped."
echo ""
echo "   Things that survive /clear (on disk):"
echo "   - subtask_*.md, progress.md, findings.md, task_plan.md, plan files"
echo "   → Call autoworker:dispatch to detect and resume from these."
echo ""
echo "   Things that may have been LOST (were only in conversation):"
echo "   - Discussion conclusions not yet written to plan/subtask"
echo "   - Scope decisions, assumption analysis, design choices"
echo "   - User preferences or corrections from this session"
echo ""
echo "   If you recall discussing something not yet in files,"
echo "   ask the user to re-state it — do NOT guess from memory."
echo ""

# 🔗 Chain recovery check
subtask_files=$(ls subtask_*.md 2>/dev/null | grep -v template)
if [ -n "$subtask_files" ]; then
  for sf in $subtask_files; do
    if grep -q "status: active" "$sf" 2>/dev/null; then
      incomplete=$(grep -c '^\- \[ \]' "$sf" 2>/dev/null || echo "0")
      has_gate_pass=$(grep -ci 'gate result.*pass' "$sf" 2>/dev/null || echo "0")
      if [ "$incomplete" -gt 0 ] && [ "$has_gate_pass" -eq 0 ]; then
        echo "🔗 [autoworker] CHAIN RECOVERY NEEDED: Active subtask ($sf) has $incomplete incomplete steps."
        echo "   → Invoke autoworker:dispatch IMMEDIATELY to resume the execution chain."
        echo "   → Do NOT investigate. Do NOT ask user. Just resume."
        echo ""
      fi
    fi
  done
fi
