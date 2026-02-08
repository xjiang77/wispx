---
name: commit
description: Create structured git commits with conventional commit format. Use when the user asks to commit, save changes, or says "commit this". Generates conventional commit messages with Chinese descriptions, reviews diff before committing.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Commit

结构化 git commit workflow，生成 conventional commit message。

## Workflow

### 1. Gather Context

Run these in parallel to understand the current state:

```bash
git status
git diff --staged
git diff
git log --oneline -5
```

### 2. Analyze Changes

From the diff output, determine:

- **Type**: feat / fix / docs / refactor / test / chore / perf / ci
- **Scope**: affected module or area (optional, use if clear)
- **Summary**: 一句话中文描述变更的 WHY，不是 WHAT
- **Breaking**: whether this is a breaking change

### 3. Stage Files

Stage relevant files explicitly by name. Do NOT use `git add -A` or `git add .` — pick specific files based on the diff analysis.

If unstaged changes exist that are unrelated to the current task, leave them unstaged and mention it.

### 4. Draft Message

Format:

```
type(scope): 中文简要描述

[Optional body: 详细说明 WHY，而不是 WHAT]

Co-Authored-By: Claude <noreply@anthropic.com>
```

Rules:
- Title line ≤ 72 characters
- Use present tense imperative in English prefix: feat, fix, docs...
- Body in Chinese, explain the reasoning
- Always include Co-Authored-By

### 5. Commit

Use HEREDOC for the message to ensure correct formatting:

```bash
git commit -m "$(cat <<'EOF'
type(scope): 描述

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 6. Verify

Run `git log --oneline -1` to confirm the commit succeeded. Show the result.

## Examples

**Example 1:**
Changes: Added JWT authentication middleware
```
feat(auth): 添加 JWT 认证中间件

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Example 2:**
Changes: Fixed off-by-one error in pagination
```
fix(api): 修复分页的 off-by-one 错误

页码从 1 开始但 offset 计算用了 0-based index，
导致第一页少返回一条记录。

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Example 3:**
Changes: Renamed internal helper function
```
refactor: 重命名内部 helper 函数以提高可读性

Co-Authored-By: Claude <noreply@anthropic.com>
```
