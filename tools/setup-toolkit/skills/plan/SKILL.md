---
name: plan
description: Architecture and implementation planning for complex tasks. Use when the user asks to plan, design, or architect a feature, or when a task involves 5+ files, multiple systems, or architectural decisions. Also use when the user says "plan this", "how should we implement", or "design the approach".
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
---

# Plan

架构/实现规划：理解需求 → 探索代码 → 设计方案 → 分解任务 → 用户确认。

## When to Use

- Task touches 5+ files
- Multiple valid approaches exist
- Architectural decisions needed
- User explicitly asks for a plan
- Requirements are unclear and need exploration first

## Workflow

### 1. Understand Requirements

Clarify the goal before exploring code:
- What is the desired outcome?
- What are the constraints (performance, compatibility, deadline)?
- What is NOT in scope?

If requirements are unclear, ask focused questions (max 3) before proceeding.

### 2. Explore the Codebase

Use Glob and Grep to understand the relevant parts:

- Find related files and modules
- Understand existing patterns and conventions
- Identify dependencies and interfaces
- Note any tests that exist for the area

Document what you find as you go — don't try to hold it all in memory.

### 3. Design the Approach

Based on exploration, design the implementation:

- **Architecture**: How does the new code fit into the existing structure?
- **Data flow**: How does data move through the system?
- **Interface changes**: What APIs or contracts change?
- **Migration**: Is there existing data/state that needs migration?

If multiple approaches are viable, present the top 2 with trade-offs and a recommendation.

### 4. Break Down into Tasks

Create a task list with clear dependencies:

For each task:
- What file(s) to modify
- What the change does
- What it depends on (blockedBy)
- Estimated complexity (small / medium / large)

Use TaskCreate to track tasks. Set up dependency chains with addBlockedBy.

### 5. Present the Plan

Output format:

```markdown
## Plan: [feature name]

### Goal
[一句话描述]

### Approach
[选择的方案及理由]

### Tasks
1. [task] — [files] — [size]
2. [task] — [files] — [size]
...

### Risks
- [potential issues and mitigations]

### Out of Scope
- [things we're NOT doing]
```

### 6. Get Confirmation

Present the plan and wait for user approval before implementing.

If the user says "looks good" or "go ahead", start executing the tasks in order.

## Anti-patterns

- 不要对简单任务使用 plan（< 3 个文件的改动直接做）
- 不要过度设计（plan for what's needed now, not hypothetical future）
- 不要把 plan 写成小说（keep it scannable, use bullets）
- 不要在 plan 阶段修改代码（plan mode = read-only exploration）
