---
name: skill-auditor
description: Audit a collection of skills for security, consistency, cross-platform compatibility, and ecosystem health. Use when users want to audit their entire skill library, prepare skills for sharing, check for security issues, or ensure consistency across a team's skill collection.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Skill Auditor

A skill for performing comprehensive audits on collections of skills. While **skill-reviewer** focuses on individual skill quality, **skill-auditor** looks at the big picture: security, consistency across a collection, compatibility, and ecosystem health.

## When to Use This Skill

- User wants to audit all skills in a directory or plugin
- User is preparing a skill collection for sharing via GitHub
- User wants a security review of their skills
- User wants to ensure consistency across a team's skill set
- User suspects skills have drifted out of sync or have stale dependencies
- User wants to identify redundant or conflicting skills

## Audit Types

### 1. Security Audit

Scan skills for security concerns:

**Critical security patterns to flag:**
- Skills that execute shell commands from user input without sanitization
- Skills that read/write to paths outside expected directories
- Skills that expose secrets, API keys, or tokens in output
- Skills that download and execute remote code
- Skills that modify system files or configurations
- Skills that access sensitive user data without clear justification

**Process:**
1. Read every SKILL.md and all referenced scripts
2. Grep for dangerous patterns:
   - Python: `eval(`, `exec(`, `subprocess`, `os.system`
   - JavaScript/TypeScript: `eval(`, `child_process.exec`, `new Function(`, `require('child_process')`
   - Shell: `curl | bash`, `rm -rf`
3. Check for path traversal: `../`, absolute paths to system directories
4. Check for secret exposure: hardcoded keys, tokens, passwords
5. Flag any network access (downloads, API calls) that aren't clearly documented
6. Produce a security report with risk ratings (critical/high/medium/low)

### 2. Consistency Audit

Check that all skills in a collection follow the same conventions:

**Check for:**
- Frontmatter format consistency (same fields, same style)
- Description quality consistency (are some vague while others are specific?)
- Naming conventions (kebab-case vs camelCase vs snake_case)
- Directory structure consistency (do all skills use the same subdirectory patterns?)
- Tone and voice consistency (formal vs casual, first person vs second person)
- Tool usage patterns (do skills reference tools the same way?)
- Error handling consistency (do all skills handle errors, or only some?)

**Process:**
1. Scan all skills in the target directory
2. Extract metadata and structural patterns from each
3. Build a comparison matrix
4. Flag inconsistencies with suggestions for normalization

### 3. Compatibility Audit

Verify skills work across target platforms:

**Check for:**
- Tool availability assumptions (does the skill assume `gh` CLI? `npx`? specific MCP servers?)
- Environment assumptions (OS-specific paths, shell-specific syntax)
- File format dependencies (does it require specific Python packages? Node.js?)
- Claude Code compatibility (does it use `allowed-tools` frontmatter? proper `${CLAUDE_PLUGIN_ROOT}` paths?)

**Process:**
1. Read each skill and catalog all tool/command/path references
2. Map references to platform availability
3. Flag platform-specific assumptions
4. Suggest abstractions or fallbacks for portability

### 4. Ecosystem Health Audit

Assess the overall health of a skill collection:

**Check for:**
- **Redundancy**: Multiple skills doing the same thing
- **Gaps**: Common tasks with no skill coverage
- **Staleness**: Skills referencing deprecated tools or outdated patterns
- **Orphans**: Skills referenced by others that don't exist
- **Circular dependencies**: Skills that reference each other in loops
- **Size distribution**: Are some skills unreasonably large or small?

**Process:**
1. Inventory all skills with metadata
2. Build a dependency graph
3. Detect clusters of overlapping functionality
4. Identify gaps by comparing against common skill categories
5. Flag stale skills based on git commit age (`git log --format=%ai -1 -- <file>`) and content analysis

## Audit Process

### Step 1: Identify the Target

Ask the user what to audit:
- A directory containing multiple skills
- A plugin directory
- A GitHub repository
- A specific list of skills

### Step 2: Inventory

Scan the target and build an inventory:
```
skill-name | version | files | size | last-commit-date | dependencies
```

### Step 3: Select Audit Types

Ask the user which audits to run, or run all by default:
- [ ] Security audit
- [ ] Consistency audit
- [ ] Compatibility audit
- [ ] Ecosystem health audit

### Step 4: Execute Audits

Run selected audits in parallel where possible. For each skill:
1. Read all files thoroughly
2. Apply audit-specific checks
3. Record findings with severity and location

### Step 5: Generate Report

Produce a comprehensive audit report:

```markdown
## Skill Collection Audit Report

### Executive Summary
- Total skills audited: N
- Critical findings: N
- Warnings: N
- Passed checks: N

### Security Findings
[Grouped by severity]

### Consistency Findings
[Comparison matrix + specific issues]

### Compatibility Findings
[Platform compatibility matrix]

### Ecosystem Health
[Redundancy, gaps, staleness, dependency graph]

### Prioritized Recommendations
1. [Fix critical security issues]
2. [Resolve inconsistencies]
3. [Address compatibility gaps]
4. [Clean up ecosystem debt]
```

### Step 6: Offer Remediation

After presenting findings:
- Offer to auto-fix simple issues (formatting, naming conventions)
- Suggest using **skill-reviewer** for deep dives on specific flagged skills
- Suggest using **skill-creator** to build missing skills for identified gaps
- For security issues, explain the risk clearly and suggest specific fixes

## Quick Audit Mode

For a fast audit, run this minimal checklist across all skills:

1. **Exists**: Does each skill have a valid SKILL.md with frontmatter?
2. **Described**: Is the description non-empty and specific?
3. **Safe**: No obvious security anti-patterns?
4. **Consistent**: Same naming and structure conventions?
5. **Referenced**: No broken internal references?
6. **Fresh**: Updated within the last 12 months?

Output a simple pass/warn/fail table.

## Integration with Other Skills

| Need | Use |
|------|-----|
| Deep review of a specific skill | **skill-reviewer** |
| Fix or improve a flagged skill | **skill-creator** |
| Package audited skills for distribution | **skill-packager** |
| Find replacement skills for deprecated ones | **find-skills** |
