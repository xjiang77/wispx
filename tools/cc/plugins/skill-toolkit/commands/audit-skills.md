---
description: Audit a collection of skills for security, consistency, and ecosystem health
argument-hint: "<path to skills directory or plugin>"
---

# Audit Skills

Run a comprehensive audit on a collection of skills, checking for security issues, inconsistencies, compatibility problems, and ecosystem health.

## Workflow

### 1. Identify the Target

Ask the user what to audit:
- A directory containing skills
- A plugin directory
- A GitHub repository
- A specific list of skill paths

### 2. Inventory

Scan the target and build a complete inventory of all skills with metadata (name, size, last commit date via `git log --format=%ai -1`, file count, dependencies).

### 3. Select Audit Types

Ask which audits to run (default: all):
- **Security**: Scan for dangerous patterns, secret exposure, unsafe execution
- **Consistency**: Check naming, structure, tone, and convention uniformity
- **Compatibility**: Verify cross-platform portability and tool availability
- **Ecosystem Health**: Detect redundancy, gaps, staleness, and dependency issues

### 4. Execute

Use the **skill-auditor** skill to run all selected audits. For large collections, parallelize the work using sub-agents.

### 5. Report

Produce a comprehensive audit report with:
- Executive summary (total skills, findings by severity)
- Detailed findings per audit type
- Prioritized remediation recommendations

### 6. Remediate

Offer to:
- Auto-fix simple issues (formatting, naming)
- Deep-review flagged skills with **skill-reviewer**
- Create missing skills with **skill-creator**
- Find replacement skills with **find-skills**

## Quick Mode

For a fast audit, run the minimal checklist: exists, described, safe, consistent, referenced, fresh. Output a simple pass/warn/fail table.
