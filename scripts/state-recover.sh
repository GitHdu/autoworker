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
for sf in subtask_*.md; do
  [[ "$sf" == *template* ]] && continue
  [ -f "$sf" ] || continue

  # Single-pass scan with initialized variables (avoids empty-string comparison error)
  check_result=$(awk '
    BEGIN { is_active=0; incomplete=0; has_pass=0 }
    /^status: active/ { is_active = 1 }
    /^- \[ \]/ { incomplete++ }
    /gate result.*pass/i { has_pass = 1 }
    END { print is_active, incomplete, has_pass }
  ' "$sf" 2>/dev/null)
  read is_active incomplete has_pass <<< "$check_result"

  if [ "${is_active:-0}" -eq 1 ] && [ "${incomplete:-0}" -gt 0 ] && [ "${has_pass:-0}" -eq 0 ]; then
    echo "🔗 [autoworker] CHAIN RECOVERY NEEDED: Active subtask ($sf) has $incomplete incomplete steps."
    echo "   → Invoke autoworker:dispatch IMMEDIATELY to resume the execution chain."
    echo "   → Do NOT investigate. Do NOT ask user. Just resume."
    echo ""
  fi
done
