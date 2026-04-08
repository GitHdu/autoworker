# Subtask 强制执行机制

> **核心问题**：Claude 经常跳过 subtask-init 直接写代码，导致执行链断裂、质量门控失效。
>
> **解决方案**：多层防护 + 违规检测 + 自动纠正协议。

---

## 强制执行层级

### 第 1 层：认知约束（SKILL.md 顶部警告）

**位置**：`skills/autoworker/SKILL.md` Path B 开头

**机制**：
- 显式决策树（DECISION TREE）
- 禁止行为清单（FORBIDDEN ACTIONS）
- 硬性规则声明（HARD RULE）

**效果**：在 Claude 开始行动前建立明确的执行约束。

```
🚨 MANDATORY FIRST ACTION CHECK

DECISION TREE (execute in order, cannot skip):

1. Does user message contain a NEW task with specific requirements?
   - YES → IMMEDIATELY invoke autoworker:subtask-init
     ⚠️ STOP: Do NOT read existing code first
     ⚠️ STOP: Do NOT check project structure first
     ⚠️ STOP: Do NOT "understand the current state" first
```

---

### 第 2 层：技能级守卫（subtask-init SKILL.md）

**位置**：`skills/subtask-init/SKILL.md`

**机制**：
- 技能描述中标记 `🚨 MANDATORY`
- 执行前禁止行为清单
- 违规纠正协议（VIOLATION PROTOCOL）

**效果**：即使 Claude 忘记主 SKILL.md 的约束，subtask-init 技能本身也会提醒。

```
## 🚨 MANDATORY EXECUTION GUARD

BEFORE invoking this skill, you MUST NOT:
- ❌ Read any code files to "understand the codebase"
- ❌ Use Glob/Grep to explore project structure
- ❌ Check existing implementations
```

---

### 第 3 层：路由验证（dispatch SKILL.md）

**位置**：`skills/dispatch/SKILL.md` - Locate Subtask 步骤

**机制**：
- 检测到没有 subtask 文件时，报告工作流违规
- 拒绝继续路由
- 明确指示正确的第一步

**效果**：即使 Claude 跳过了 subtask-init 直接调用 dispatch，也会被拦截。

```
0 found → 🚨 STOP: No subtask document exists
          → Check: Did user provide a NEW task?
          → YES: Report error "Missing subtask-init step" 
                 → Instruct to invoke autoworker:subtask-init first
                 → DO NOT proceed with routing
```

---

### 第 4 层：Hook 检测（state-persist.sh）

**位置**：`scripts/state-persist.sh` - Signal 3

**机制**：
- 每次 Claude 停止时触发
- 检查是否存在计划文件但没有活跃子任务
- 如果检测到违规，输出明确的纠正指令

**效果**：即使 Claude 已经开始错误流程，Stop Hook 会在会话结束前提醒。

```bash
# Signal 3: Task given but no subtask created (WORKFLOW VIOLATION DETECTION)
if [ -f "task_plan.md" ] || [ -f ".claude/plans/"*.md ]; then
  has_active_subtask=false
  # ... 检查是否有活跃子任务
  
  if [ "$has_active_subtask" = false ]; then
    echo "🚨 [autoworker] WORKFLOW VIOLATION DETECTED:"
    echo "   Plan file exists but NO active subtask found."
    echo "   → Invoke: autoworker:subtask-init"
  fi
fi
```

---

### 第 5 层：自我纠正协议（Recovery 部分）

**位置**：`skills/autoworker/SKILL.md` - Recovery After /clear

**机制**：
- 验证检查清单（VALIDATION CHECK）
- 紧急纠正流程（EMERGENCY CORRECTION）
- 明确的停止和回退指令

**效果**：Claude 可以在意识到错误后自我纠正。

```
🚨 VALIDATION CHECK (Self-Correction Protocol):

After any action in step 1, verify:
- ✅ Did I invoke autoworker:subtask-init as my FIRST action for a new task?
- ✅ Did I avoid reading/investigating code before subtask-init?
- ✅ Did I prioritize user intent over existing file state?

If ANY answer is NO → STOP immediately → invoke autoworker:subtask-init now.
```

---

## 违规场景与防护

### 场景 1：直接编码（最常见）

**违规流程**：
```
用户：/autoworker 添加重试机制
Claude: ❌ 读代码 → ❌ 理解需求 → ❌ 写代码
```

**防护生效点**：
1. ✅ 第 1 层：SKILL.md 顶部的 FORBIDDEN ACTIONS 清单
2. ✅ 第 4 层：Stop Hook 检测到 task_plan 存在但无活跃子任务
3. ✅ 第 5 层：自我纠正协议要求立即停止

**正确流程**：
```
用户：/autoworker 添加重试机制
Claude: ✅ 立即调用 autoworker:subtask-init
       → 创建 subtask_001_retry.md
       → 运行假设验证
       → 链式调用 → subtask-plan → dispatch
```

---

### 场景 2：旧子任务干扰

**违规流程**：
```
项目中有 subtask_001.md (status: completed)
用户：/autoworker 添加日志系统
Claude: ❌ 发现 subtask_001 → ❌ 调用 dispatch → ❌ 没有新任务
```

**防护机制**：
- 决策树明确：用户有新任务 → 立即 subtask-init
- 用户意图 > 文件状态

**正确流程**：
```
1. 判断用户意图：有新任务？ → YES
2. 立即调用 subtask-init（不管旧文件）
3. subtask-init 自动暂停旧子任务
4. 创建 subtask_002_logging.md
```

---

### 场景 3：调查癖

**违规流程**：
```
用户：/autoworker 实现权限系统
Claude: ❌ "先看看项目结构" → ❌ Glob 文件 → ❌ 读 CLAUDE.md
       → ❌ "现在理解了" → ❌ 开始写代码
```

**防护生效点**：
1. ✅ 第 1 层：明确禁止 "checking project structure"
2. ✅ 第 2 层：subtask-init 守卫禁止 Glob/Grep
3. ✅ 第 4 层：Stop Hook 检测到违规

**关键认知**：
> 调查是 subtask-init 中"假设验证"的一部分，不是前置条件。

---

## 实施效果

### 之前（无强制机制）

```
触发 /autoworker
  ↓
Claude 自行决定下一步（经常选错）
  ↓
~60% 概率跳过 subtask-init
  ↓
执行链断裂，质量门控失效
```

### 之后（5 层防护）

```
触发 /autoworker
  ↓
第 1 层：决策树强制检查
  ↓
如果选错 → 第 2 层：技能守卫拦截
  ↓
如果绕过 → 第 3 层：路由验证拒绝
  ↓
如果继续 → 第 4 层：Hook 检测警告
  ↓
如果忽略 → 第 5 层：自我纠正协议
  ↓
subtask 必须创建，执行链完整
```

---

## 使用指南

### 对于用户

**当你看到这些警告时**：

1. **`🚨 MANDATORY FIRST ACTION CHECK`**
   - Claude 正在正确执行流程
   - 不需要干预

2. **`🚨 WORKFLOW VIOLATION DETECTED`**
   - Claude 可能跳过了 subtask-init
   - 提醒它："请先调用 autoworker:subtask-init"

3. **`⚠️ Workflow error: No subtask document found`**
   - dispatch 检测到没有 subtask 文件
   - Claude 会告诉你需要创建

### 对于 Claude

**强制检查清单**（每次 `/autoworker` 后）：

```
□ 用户给了新任务？
  ├─ YES → 立即调用 autoworker:subtask-init
  │        └─ 禁止：读代码、调查、写代码
  └─ NO  → 检查现有 subtask
  
□ 已经创建了 subtask.md？
  ├─ YES → 继续执行链
  └─ NO  → 为什么还没创建？
           └─ 立即调用 autoworker:subtask-init
```

---

## 技术细节

### 文件修改清单

| 文件 | 修改内容 | 防护层 |
|------|---------|--------|
| `skills/autoworker/SKILL.md` | 添加 MANDATORY FIRST ACTION CHECK | 第 1 层 |
| `skills/autoworker/SKILL.md` | 添加 VALIDATION CHECK + EMERGENCY CORRECTION | 第 5 层 |
| `skills/autoworker/SKILL.md` | Hard rules 添加 SUBTASK.MD MANDATORY | 第 1 层 |
| `skills/subtask-init/SKILL.md` | 添加 MANDATORY EXECUTION GUARD | 第 2 层 |
| `skills/dispatch/SKILL.md` | 添加 CRITICAL CHECK | 第 3 层 |
| `scripts/state-persist.sh` | 添加 Signal 3 违规检测 | 第 4 层 |

### 检测逻辑

```bash
# Stop Hook 的违规检测逻辑
if (存在 plan 文件) AND (不存在 status:active 的 subtask):
    输出警告 = "WORKFLOW VIOLATION DETECTED"
    建议行动 = "Invoke autoworker:subtask-init"
```

---

## 常见问题

### Q: 为什么需要 5 层防护？

A: 因为 Claude 会在不同阶段遗忘约束：
- 开始任务时 → 需要第 1 层
- 调用技能时 → 需要第 2 层
- 路由时 → 需要第 3 层
- 停止时 → 需要第 4 层
- 意识到错误时 → 需要第 5 层

### Q: 会影响正常流程吗？

A: 不会。所有防护只在违规时触发，正常流程不受影响。

### Q: 如果我真的需要先调查代码？

A: 调查应该作为 subtask-init 中"假设验证"的一部分进行，不是前置步骤。

### Q: 旧项目没有 plan 文件怎么办？

A: 简单任务可以直接 subtask-init，复杂任务会先进入 Plan Mode 生成 plan。

---

## 总结

**核心原则**：
1. 用户意图 > 文件状态
2. subtask-init 必须是新任务的第一步
3. 多层防护确保即使遗忘也能被拦截
4. 自我纠正协议允许错误后恢复

**成功标准**：
- ✅ 每次 `/autoworker` 都生成 subtask.md
- ✅ 没有 subtask 就没有代码实现
- ✅ 违规被自动检测和纠正
