---
name: tdd
description: Test-Driven Development with RED-GREEN-REFACTOR cycle. Use when the user wants to develop with TDD, write tests first, or says "TDD this", "test-driven", or "write failing test first". Enforces the discipline of writing a failing test before any implementation.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# TDD

RED-GREEN-REFACTOR cycle 驱动开发。

## Core Cycle

```
RED → GREEN → REFACTOR → (repeat)
```

1. **RED**: Write a failing test that describes the desired behavior
2. **GREEN**: Write the MINIMUM code to make it pass
3. **REFACTOR**: Clean up while keeping tests green

## Workflow

### 1. Understand the Requirement

Before writing any test, clarify:
- What behavior is being added or changed?
- What are the inputs and expected outputs?
- What are the edge cases?

### 2. RED — Write a Failing Test

Write ONE test that captures the next piece of desired behavior.

Rules:
- Test should be specific and focused (test one thing)
- Name should describe the behavior: `test_returns_empty_list_when_no_items`
- Use the existing test framework and patterns in the project

```bash
# Run the test — it MUST fail
[test command]
```

Show the failure output. If the test passes, something is wrong — the test isn't testing new behavior.

### 3. GREEN — Minimal Implementation

Write the MINIMUM code to make the failing test pass.

Rules:
- Do not write more code than needed for the current test
- Do not anticipate future requirements
- It's OK to hardcode values if that makes the test pass
- The goal is the shortest path to green

```bash
# Run the test — it MUST pass now
[test command]
```

Show the passing output. Also run the full test suite to ensure nothing broke.

### 4. REFACTOR — Clean Up

Now that tests are green, improve the code:
- Remove duplication
- Improve naming
- Simplify logic
- Extract common patterns

Rules:
- Do NOT change behavior (tests must stay green)
- Do NOT add new functionality
- Run tests after every change

```bash
# Tests must still pass
[test command]
```

### 5. Next Cycle

Pick the next piece of behavior and go back to RED.

Guide the user through multiple cycles until the feature is complete.

## Detecting the Test Framework

Before starting, detect the project's test setup:

```bash
# Check for common test configs
ls package.json pytest.ini setup.cfg pyproject.toml Cargo.toml go.mod 2>/dev/null
```

| Framework | Run Command | File Pattern |
|-----------|-------------|--------------|
| Jest | `npx jest` | `*.test.ts`, `*.spec.ts` |
| Vitest | `npx vitest run` | `*.test.ts`, `*.spec.ts` |
| Pytest | `pytest` | `test_*.py`, `*_test.py` |
| Go test | `go test ./...` | `*_test.go` |
| Cargo test | `cargo test` | inline `#[test]` |

## Tips

- 每个 cycle 不超过 5 分钟的工作量
- 如果你发现需要写很多代码才能让测试通过，说明测试粒度太大——拆分
- Refactor 阶段是可选的，不是每个 cycle 都需要
- 保持测试快速（< 1s per test）
- 当用户说 "just implement it" 时，尊重他们的意愿，跳出 TDD 模式
