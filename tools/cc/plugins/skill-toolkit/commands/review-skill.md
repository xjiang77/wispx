---
description: Run a quality review on an existing skill with structured feedback
argument-hint: "<path to skill or skill name>"
---

# Review Skill

Perform a structured quality review on an existing skill, evaluating it across multiple dimensions.

## Workflow

### 1. Locate the Skill

Ask the user which skill to review. Accept:
- A file path to a SKILL.md
- A directory containing a skill
- A GitHub URL
- A skill name (if locally installed)

### 2. Deep Read

Read the entire skill thoroughly:
- The SKILL.md file
- All referenced sub-files (agents/, scripts/, references/)
- Any test cases or examples

### 3. Evaluate

Use the **skill-reviewer** skill to evaluate across 6 dimensions:
1. Structure & Format
2. Instruction Clarity
3. Effectiveness
4. Best Practices Compliance
5. Maintainability
6. Cross-Platform Compatibility

### 4. Report

Produce a structured review report with:
- Overall score (X/10)
- Strengths and issues (by severity)
- Prioritized recommendations
- Detailed dimension-by-dimension analysis

### 5. Remediate

Offer to:
- Fix critical and major issues directly
- Use **skill-creator** for deeper iterative improvement
- Run **skill-auditor** if this is part of a larger collection

## Quick Mode

Add `--quick` to run the fast checklist instead of the full review. This produces a simple pass/warn/fail table against the essential checklist items.
