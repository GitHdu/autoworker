#!/bin/bash
# state-persist.sh — Stop hook for autoworker plugin
# Fires every time Claude stops.
#
# Core problem: /clear loses discussion conclusions that are only in context
# (not written to files). Disk files (subtask, progress) survive /clear fine.
# This hook reminds Claude to persist discussion results before session ends.

# Signal 1: Plan file exists but nearly empty (discussed but not written)
for pf in .claude/plans/*.md; do
  [ -f "$pf" ] || continue
  content=$(grep -cv '^$' "$pf" 2>/dev/null || echo "0")
  if [ "$content" -lt 5 ]; then
    echo ""
    echo "⚠️ [autoworker] Plan file exists but nearly empty: $pf"
    echo "   If you discussed a plan, write conclusions to this file before /clear."
  fi
done

# Signal 2: Active subtask with no entries for today
# Signal 3: Workflow violation (plan exists but no active subtask)
# Signal 4: Chain interruption detection
# NOTE: Signals 2-4 are FALLBACK checks. Claude's Grep/Read tools are faster and preferred.
today=$(date '+%Y-%m-%d')
has_active_subtask=false

for sf in subtask_*.md; do
  [[ "$sf" == *template* ]] && continue
  [ -f "$sf" ] || continue

  # Single-pass scan: collect all signals in one awk run
  check_result=$(awk -v today="$today" '
    BEGIN { is_active=0; incomplete=0; has_pass=0; has_today=0 }
    /^status: active/ { is_active = 1 }
    /^- \[ \]/ { incomplete++ }
    /gate result.*pass/i { has_pass = 1 }
    $0 ~ today { has_today = 1 }
    END { print is_active, incomplete, has_pass, has_today }
  ' "$sf" 2>/dev/null)
  read is_active incomplete has_pass has_today <<< "$check_result"

  # Signal 2: no entries for today
  if [ "${has_today:-0}" -eq 0 ]; then
    echo ""
    echo "⚠️ [autoworker] Subtask ($sf) has no entries for today."
    echo "   If you made progress, update it before /clear."
  fi

  # Signal 4: chain interruption
  if [ "${is_active:-0}" -eq 1 ]; then
    has_active_subtask=true
    if [ "${incomplete:-0}" -gt 0 ] && [ "${has_pass:-0}" -eq 0 ]; then
      echo ""
      echo "🔗 [autoworker] CHAIN INCOMPLETE: Active subtask ($sf) has $incomplete incomplete steps and no Gate PASS."
      echo "   The execution chain should continue. Invoke autoworker:dispatch to resume."
      echo "   Do NOT start a new task. Do NOT ask user what to do. Resume the chain."
    fi
  fi
done

# 🚨 Signal 3: Task given but no subtask created (WORKFLOW VIOLATION DETECTION)
if [ -f "task_plan.md" ] || ls .claude/plans/*.md 2>/dev/null | head -1 | grep -q .; then
  if [ "$has_active_subtask" = false ]; then
  
    echo ""
    echo "🚨 [autoworker] WORKFLOW VIOLATION DETECTED:"
    echo "   Plan file exists but NO active subtask found."
    echo "   If user gave you a task, you MUST invoke autoworker:subtask-init FIRST."
    echo "   Do NOT read code, do NOT investigate, do NOT write code."
    echo "   → Invoke: autoworker:subtask-init"
  fi
fi

# Generic reminder (always output — short and effective)
echo ""
echo "💡 [autoworker] If there are discussion conclusions not yet in files (plan decisions, scope changes, findings), persist them NOW."
