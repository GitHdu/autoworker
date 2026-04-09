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
subtask_files=$(ls subtask_*.md 2>/dev/null | grep -v template)
if [ -n "$subtask_files" ]; then
  today=$(date '+%Y-%m-%d')
  for sf in $subtask_files; do
    has_today=$(grep -c "$today" "$sf" 2>/dev/null || echo "0")
    if [ "$has_today" -eq 0 ]; then
      echo ""
      echo "⚠️ [autoworker] Subtask ($sf) has no entries for today."
      echo "   If you made progress, update it before /clear."
    fi
  done
fi

# 🚨 Signal 3: Task given but no subtask created (WORKFLOW VIOLATION DETECTION)
# Check if there are recent conversation indicators of a task but no active subtask
if [ -f "task_plan.md" ] || [ -f ".claude/plans/"*.md 2>/dev/null ]; then
  has_active_subtask=false
  for sf in $subtask_files; do
    if grep -q "status: active" "$sf" 2>/dev/null; then
      has_active_subtask=true
      break
    fi
  done
  
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

# 🚨 Signal 4: Chain interruption detection
# If the execution chain was running but appears to have stopped mid-way,
# remind Claude to resume via autoworker:dispatch
if [ -n "$subtask_files" ]; then
  for sf in $subtask_files; do
    if grep -q "status: active" "$sf" 2>/dev/null; then
      # Active subtask exists — chain should be running
      # Check if there are incomplete phases (unchecked steps)
      incomplete=$(grep -c '^- \[ \]' "$sf" 2>/dev/null || echo "0")
      has_gate_pass=$(grep -ci 'gate result.*pass' "$sf" 2>/dev/null || echo "0")
      if [ "$incomplete" -gt 0 ] && [ "$has_gate_pass" -eq 0 ]; then
        echo ""
        echo "🔗 [autoworker] CHAIN INCOMPLETE: Active subtask ($sf) has $incomplete incomplete steps and no Gate PASS."
        echo "   The execution chain should continue. Invoke autoworker:dispatch to resume."
        echo "   Do NOT start a new task. Do NOT ask user what to do. Resume the chain."
      fi
    fi
  done
fi
