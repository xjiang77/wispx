---
description: Search for and install skills from the open agent skills ecosystem
argument-hint: "<what you're looking for>"
---

# Find Skill

Discover and install agent skills from the open ecosystem.

## Workflow

### 1. Understand the Need

Ask the user what capability they're looking for. This could be:
- A specific task ("PR review", "changelog generation")
- A domain ("React", "DevOps", "data analysis")
- A vague need ("I wish I could automate X")

### 2. Search

Use the **find-skills** skill to search across multiple sources:
- Local installed skills (`.claude/skills/`, `~/.claude/skills/`)
- GitHub repositories (`gh search repos`, `gh search code`)
- Community collections (verify existence before recommending)

### 3. Present Results

Show the user what was found with:
- Skill name and description
- Install command
- Link to source
- Quality indicators (stars, last updated)

### 4. Install

If the user wants a skill, install it:
```bash
# Clone and copy
git clone <repo-url> /tmp/skill-install
cp -r /tmp/skill-install/<skill-dir> ~/.claude/skills/
rm -rf /tmp/skill-install
```

## Tips

- Use specific search terms for better results
- Try alternative keywords if the first search doesn't match
- Check local skills before searching GitHub
- Consider cross-platform compatibility when recommending skills
