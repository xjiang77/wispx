---
name: code-review
description: Perform systematic code review with structured findings. Use when the user asks to review code, review a PR, check code quality, or says "review this". Covers security, performance, readability, architecture, and correctness.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Code Review

系统化 code review，输出结构化 findings。

## Review Dimensions

| Dimension | Focus |
|-----------|-------|
| **Correctness** | 逻辑错误、边界条件、错误处理 |
| **Security** | OWASP Top 10、注入、权限 |
| **Performance** | N+1 查询、不必要的分配、算法复杂度 |
| **Readability** | 命名、结构、复杂度 |
| **Architecture** | 职责划分、耦合度、抽象层次 |
| **Testing** | 覆盖率、边界测试、mock 合理性 |

## Workflow

### 1. Identify Scope

Determine what to review:

- If reviewing a PR: `git diff main...HEAD` or `gh pr diff <number>`
- If reviewing specific files: read the files directly
- If reviewing a directory: scan all source files

### 2. Read the Code

Read ALL changed files thoroughly. Do not skim. For each file:
- Understand the purpose and context
- Note the patterns used
- Identify entry points and data flow

### 3. Analyze Each Dimension

For each dimension, check systematically:

**Correctness**
- Does the logic match the intent?
- Are edge cases handled (null, empty, overflow)?
- Are error paths correct?

**Security**
- User input sanitized before use?
- SQL queries parameterized?
- Secrets not hardcoded?
- File paths validated?
- XSS vectors in output?

**Performance**
- Any O(n²) where O(n) is possible?
- Unnecessary database queries in loops?
- Large allocations in hot paths?
- Missing indexes for queries?

**Readability**
- Variable/function names convey intent?
- Functions < 50 lines?
- Nesting depth ≤ 3?
- Complex logic has explanatory comments?

**Architecture**
- Single responsibility principle?
- Dependencies flow inward?
- No circular dependencies?
- Appropriate abstraction level?

**Testing**
- Happy path tested?
- Error paths tested?
- Edge cases tested?
- Mocks are minimal and realistic?

### 4. Generate Report

Output format:

```markdown
## Code Review: [scope]

### Summary
[2-3 句总结]

### Findings

#### Critical
- **[file:line]** [description] — [fix suggestion]

#### Major
- **[file:line]** [description] — [fix suggestion]

#### Minor
- **[file:line]** [description]

#### Nits
- **[file:line]** [description]

### Positive Notes
- [值得肯定的地方]

### Verdict
[APPROVE / REQUEST_CHANGES / COMMENT]
```

### 5. Offer to Fix

After presenting findings, offer to fix critical and major issues directly.

## Severity Guide

| Severity | Definition |
|----------|-----------|
| Critical | 会导致 crash、数据丢失、安全漏洞 |
| Major | 影响正确性或性能，需要修复 |
| Minor | 代码质量问题，建议改进 |
| Nit | 风格偏好，可选 |
