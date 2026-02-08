---
name: skill-reviewer
description: Review individual skills for quality, best practices, effectiveness, and maintainability. Use when users want to evaluate an existing skill, get feedback on a skill draft, or check a skill against community standards before sharing.
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Skill Reviewer

A skill for reviewing and providing structured feedback on agent skills. Think of this as a "code review" but for SKILL.md files and their associated resources.

## When to Use This Skill

- User asks "review this skill" or "is this skill any good?"
- User wants feedback on a skill they've written before publishing
- User wants to compare their skill against best practices
- User wants to understand why a skill isn't performing well
- User is preparing a skill for inclusion in a shared repository

## Review Dimensions

Every skill review evaluates across these dimensions:

### 1. Structure & Format

- **Frontmatter**: Does it have proper YAML frontmatter with `name` and `description`?
- **Description quality**: Is the description specific enough for discovery? Does it list concrete triggers and use cases?
- **Section organization**: Does it follow a logical flow (when to use -> how it works -> steps -> examples)?
- **Length**: Is it appropriately sized? (Too short = vague; too long = Claude may lose focus)

### 2. Instruction Clarity

- **Specificity**: Are instructions concrete and actionable, or vague and hand-wavy?
- **Ambiguity**: Are there places where Claude could reasonably interpret the instruction differently?
- **Edge cases**: Does the skill handle common edge cases (missing input, unexpected formats, errors)?
- **Decision points**: When there are choices to make, does the skill give clear criteria for choosing?

### 3. Effectiveness

- **Task coverage**: Does the skill actually cover the full scope of what it claims to do?
- **Output quality signals**: Does it define what "good" output looks like?
- **Failure modes**: Does it anticipate and handle common failure modes?
- **Iteration support**: Does it support iterative refinement, or is it one-shot?

### 4. Best Practices Compliance

- **Tool usage**: Does it use tools appropriately (not over-relying on bash when dedicated tools exist)?
- **User interaction**: Does it ask for input at the right moments, not too much, not too little?
- **File handling**: Does it handle file I/O correctly (paths, formats, permissions)?
- **Security**: Does it avoid unsafe patterns (executing untrusted code, exposing secrets, etc.)?

### 5. Maintainability

- **Modularity**: Is the skill self-contained, or does it have hidden dependencies?
- **Versioning**: Would changes to external tools or APIs break this skill?
- **Documentation**: Are complex decisions or patterns explained inline?
- **Testability**: Can this skill be evaluated with clear test cases?

### 6. Cross-Platform Compatibility

- **Agent-specific features**: Does it use features only available in certain agents?
- **Path assumptions**: Does it hardcode paths that differ across environments?
- **Tool availability**: Does it assume tools that may not be present everywhere?

## Review Process

### Step 1: Locate the Skill

Ask the user to point you to the skill. Accept any of:
- A file path to a SKILL.md
- A directory containing a skill
- A GitHub URL
- Skill content pasted directly

### Step 2: Read Everything

Read the complete skill thoroughly:
1. The SKILL.md file (main instructions)
2. Any referenced files (agents/, scripts/, references/, assets/)
3. Any examples or test cases if they exist

### Step 3: Analyze Against Dimensions

For each of the 6 review dimensions, evaluate the skill and note:
- **Strengths**: What it does well
- **Issues**: Problems that should be fixed (with severity: critical / major / minor / nit)
- **Suggestions**: Improvements that aren't strictly necessary but would help

### Step 4: Generate the Review Report

Produce a structured review with:

```markdown
## Skill Review: [skill-name]

### Summary
[2-3 sentence overall assessment]

### Score: [X/10]

### Strengths
- [What the skill does well]

### Issues
#### Critical
- [Must-fix problems]

#### Major
- [Should-fix problems]

#### Minor
- [Nice-to-fix problems]

### Recommendations
1. [Prioritized list of improvements]

### Detailed Analysis
[Section-by-section breakdown across the 6 dimensions]
```

### Step 5: Offer to Help Fix

After presenting the review:
- Offer to fix critical and major issues directly
- Suggest using the **skill-creator** skill for deeper iterative improvement
- If the user wants to publish, suggest running **skill-auditor** for compliance checks

## Review Checklist (Quick Mode)

For a fast review, run through this checklist:

- [ ] Has YAML frontmatter with name and description
- [ ] Description is specific (lists concrete triggers, not just vague capabilities)
- [ ] Instructions are actionable (not "do something good" but "do X then Y then Z")
- [ ] Handles missing/invalid input gracefully
- [ ] Does not hardcode environment-specific paths
- [ ] Does not execute untrusted user input without safeguards
- [ ] Defines what success looks like (output quality criteria)
- [ ] Appropriate length (aim for 100-500 lines for most skills)
- [ ] No orphaned references (all mentioned files/skills actually exist)
- [ ] Examples or test cases exist or can be easily derived

## Severity Definitions

| Severity | Definition | Action |
|----------|-----------|--------|
| Critical | Skill will fail or produce harmful/incorrect results | Must fix before use |
| Major | Skill will produce suboptimal results in common cases | Should fix before publishing |
| Minor | Skill works but could be improved | Fix when convenient |
| Nit | Style or preference issue | Optional |

## Common Anti-Patterns to Flag

1. **The Wall of Text**: SKILL.md is 1000+ lines with no clear structure -> suggest breaking into sub-files
2. **The Vague Directive**: "Make it good" / "Use best practices" -> suggest specific criteria
3. **The Assumption Train**: Assumes tools/files/permissions exist without checking -> suggest guards
4. **The One-Shot Wonder**: No support for iteration or refinement -> suggest adding feedback loops
5. **The Kitchen Sink**: Tries to do everything -> suggest splitting into focused skills
6. **The Copy-Paste Trap**: Duplicates instructions from another skill -> suggest referencing instead
7. **The Hardcoded Path**: Uses `/Users/john/...` or `C:\Users\...` -> suggest environment-agnostic paths
8. **The Silent Failure**: Doesn't handle errors or tell the user when something goes wrong -> suggest error handling
