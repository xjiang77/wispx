---
name: find-skills
description: Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - WebSearch
---

# Find Skills

This skill helps you discover and install skills from the open agent skills ecosystem.

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)

## Discovery Sources

Search these sources in order of reliability:

### 1. Local Skills

Check for already-installed skills first:

```bash
# Project-level skills
ls .claude/skills/ 2>/dev/null

# User-level global skills
ls ~/.claude/skills/ 2>/dev/null
```

### 2. GitHub Search

Search GitHub for skills using the `gh` CLI:

```bash
# Search repositories by topic
gh search repos "claude skill [query]" --sort stars

# Search for SKILL.md files with matching content
gh search code "name: [query]" --filename SKILL.md

# Browse a specific repo's skills directory
gh api repos/<owner>/<repo>/contents/skills
```

Before recommending any repository, verify it exists and check its quality:

```bash
# Verify repo exists and check stars/activity
gh repo view <owner>/<repo> --json name,description,stargazersCount,updatedAt
```

### 3. Community Collections

Well-known skill collections to search (verify existence before recommending):

```bash
# Check if a known collection exists and is active
gh repo view anthropics/skills 2>/dev/null
gh repo view vercel-labs/skills 2>/dev/null
```

### 4. Skills CLI (Optional)

If the user has the Skills CLI installed, it can be used as an additional source:

```bash
# Check if available
npx skills --version 2>/dev/null

# Only use if the above succeeds
npx skills find [query]
```

Do not assume the Skills CLI is available. Always check first.

## How to Help Users Find Skills

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment, data analysis)
2. The specific task (e.g., writing tests, creating presentations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Search for Skills

Try multiple search strategies:

```bash
# Check local first
ls .claude/skills/ ~/.claude/skills/ 2>/dev/null

# GitHub search
gh search repos "claude skill [query]" --sort stars
gh search code "name: [query]" --filename SKILL.md
```

### Step 3: Present Options to the User

When you find relevant skills, present them with:

1. The skill name and what it does
2. The install command
3. A link to the source repository
4. Quality indicators (stars, last updated)

### Step 4: Offer to Install

If the user wants to proceed:

```bash
# Clone and install
git clone <repo-url> /tmp/skill-install
cp -r /tmp/skill-install/<skill-dir> ~/.claude/skills/
rm -rf /tmp/skill-install
```

Or for a full plugin:
```bash
git clone <repo-url> ~/.claude/plugins/<plugin-name>
```

## Common Skill Categories

When searching, consider these common categories:

| Category | Example Queries |
|----------|----------------|
| Web Development | react, nextjs, typescript, css, tailwind |
| Testing | testing, jest, playwright, e2e |
| DevOps | deploy, docker, kubernetes, ci-cd |
| Documentation | docs, readme, changelog, api-docs |
| Code Quality | review, lint, refactor, best-practices |
| Design | ui, ux, design-system, accessibility |
| Productivity | workflow, automation, git |
| Data & Analysis | data, analysis, visualization, csv |
| Content Creation | writing, blog, presentation, email |
| Security | security, audit, vulnerability |

## Tips for Effective Searches

1. **Use specific keywords**: "react testing" is better than just "testing"
2. **Try alternative terms**: If "deploy" doesn't work, try "deployment" or "ci-cd"
3. **Check popular sources first**: Many skills come from well-known repositories
4. **Consider cross-platform skills**: Some skills work across multiple agents (Claude Code, Cursor, Codex, etc.)
5. **Check skill freshness**: Prefer recently updated skills over stale ones

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using general capabilities
3. Suggest the user could create their own skill using the `/create-skill` command

## Evaluating Skill Quality

Before recommending a skill, consider:

- **Stars / popularity**: More stars generally means more battle-tested
- **Last updated**: Prefer skills updated within the last 6 months
- **Documentation quality**: A well-documented SKILL.md is a good sign
- **Author reputation**: Known organizations (Anthropic, Vercel) are generally reliable
- **Compatibility**: Ensure the skill works with Claude Code
