---
name: skill-packager
description: Package one or more skills into a distributable Claude Code plugin with proper metadata, commands, versioning, and sharing support. Use when users want to bundle skills into a plugin, prepare a plugin for distribution, or share a plugin via GitHub.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Skill Packager

A skill for packaging individual skills into distributable Claude Code plugins. This skill handles the full packaging lifecycle: structuring the plugin, generating metadata, creating commands, managing versions, and preparing for sharing via GitHub.

## When to Use This Skill

- User wants to bundle one or more skills into a Claude Code plugin
- User wants to create a distributable plugin from scratch
- User has a working skill and wants to share it as a plugin
- User wants to share a plugin via GitHub
- User wants to add versioning, commands, or MCP configuration to existing skills

## Plugin Anatomy

A Claude Code plugin has this structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED: Plugin identity & metadata
├── .mcp.json                # REQUIRED: MCP server connections (can be empty)
├── README.md                # Recommended: Human-readable documentation
├── LICENSE                  # Recommended: License file
├── commands/                # Optional: Slash command definitions
│   └── command-name.md      # Each command is a markdown file with YAML frontmatter
└── skills/                  # Optional: Bundled skills
    ├── skill-one/
    │   └── SKILL.md
    └── skill-two/
        ├── SKILL.md
        ├── scripts/
        └── references/
```

## Packaging Process

### Step 1: Gather Skills

Ask the user which skills to include. Accept:
- Directory paths containing skills
- GitHub URLs to skill repositories
- Skill names if they're already installed locally
- A request to create new skills (defer to **skill-creator**)

For each skill, verify it has a valid SKILL.md with frontmatter.

### Step 2: Choose Plugin Metadata

Collect from the user:

| Field | Required | Example |
|-------|----------|---------|
| Plugin name | Yes | `my-awesome-plugin` |
| Version | Yes (default: 1.0.0) | `1.0.0` |
| Description | Yes | `A toolkit for...` |
| Author name | Yes | `Jane Doe` |
| License | Recommended | `MIT` |

### Step 3: Generate plugin.json

Create the `.claude-plugin/plugin.json` file:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "What this plugin does in one sentence.",
  "author": {
    "name": "Author Name"
  }
}
```

### Step 4: Configure MCP Servers

Determine if the plugin needs external service connections:

- If skills reference external APIs or services, configure `.mcp.json`
- If skills are self-contained, use an empty configuration: `{"mcpServers": {}}`

### Step 5: Create Commands

For each major workflow, create a slash command in `commands/`:

```markdown
---
description: Short description of what this command does
argument-hint: "<what the user should provide>"
---

# Command Name

[Detailed workflow instructions for this command]

## Workflow

### 1. [First Step]
[Instructions]

### 2. [Second Step]
[Instructions]

## Output Format
[What the command produces]
```

**Guidelines for commands:**
- One command per major use case (don't create a command for every minor variation)
- Command names should be verb-noun: `create-skill`, `review-code`, `find-issue`
- Keep command files focused (300-500 lines max)
- Reference skills for detailed guidance: "See the **skill-name** skill for detailed instructions"

### Step 6: Write README.md

Generate a README with:
- Plugin description
- Skills included (table format)
- Commands available (table format)
- Installation instructions (git clone + `claude plugin add`)
- Configuration notes
- License information

### Step 7: Validate

Before finalizing, validate the plugin:

1. **Structure check**: All required files exist (`.claude-plugin/plugin.json`, `.mcp.json`)
2. **Reference check**: All cross-references resolve (commands reference existing skills, etc.)
3. **Metadata check**: plugin.json is valid JSON with required fields
4. **MCP check**: .mcp.json is valid JSON
5. **Size check**: No unreasonably large files (warn if any file > 100KB)
6. **Naming check**: Plugin name follows kebab-case convention
7. **Skill validation**: Run `${CLAUDE_PLUGIN_ROOT}/skills/skill-creator/scripts/quick_validate.py` on each skill

### Step 8: Prepare for Sharing

Initialize a git repository and prepare for GitHub sharing:

```bash
cd plugin-dir
git init
git add .
git commit -m "Initial plugin release v1.0.0"
```

To share with others:
1. Create a GitHub repository
2. Push the plugin: `git remote add origin <url> && git push -u origin main`
3. Others install via: `git clone <url> && claude plugin add ./plugin-name`

## Version Management

When updating a published plugin:

1. Update `version` in `plugin.json` (follow semver)
2. Tag the release in git: `git tag v1.1.0`
3. Re-run validation
4. Push the updated version: `git push && git push --tags`

**Semver guidelines for skills:**
- **Patch** (1.0.x): Typo fixes, minor wording improvements
- **Minor** (1.x.0): New skills or commands added, non-breaking changes
- **Major** (x.0.0): Breaking changes to existing skills or commands, removed features

## Integration with Other Skills

| Need | Use |
|------|-----|
| Create a new skill for the plugin | **skill-creator** |
| Review skills before packaging | **skill-reviewer** |
| Audit the plugin collection | **skill-auditor** |
| Find existing skills to include | **find-skills** |
