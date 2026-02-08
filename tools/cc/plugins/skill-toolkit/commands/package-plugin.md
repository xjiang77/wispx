---
description: Package one or more skills into a distributable Claude Code plugin
argument-hint: "<skills to package or plugin name>"
---

# Package Plugin

Bundle one or more skills into a distributable Claude Code plugin with proper metadata, commands, versioning, and GitHub sharing support.

## Workflow

### 1. Gather Skills

Ask the user which skills to include:
- Directory paths to existing skills
- GitHub URLs
- Locally installed skill names
- Or create new skills on the fly (defers to **skill-creator**)

### 2. Configure Plugin

Collect plugin metadata:
- **Name** (required): kebab-case plugin name
- **Version** (default: 1.0.0): Semantic version
- **Description** (required): What the plugin does
- **Author** (required): Author name
- **License** (recommended): License type (e.g., MIT)

### 3. Build Plugin Structure

Use the **skill-packager** skill to:
1. Create the plugin directory structure
2. Generate `.claude-plugin/plugin.json`
3. Configure `.mcp.json` (with MCP servers if needed)
4. Copy skills into `skills/` directory
5. Generate slash commands in `commands/`
6. Write README.md

### 4. Validate

Run validation checks:
- All required files exist
- Cross-references resolve
- JSON files are valid
- No oversized files
- Naming conventions followed

### 5. Prepare for Sharing

Initialize a git repository for distribution:
- `git init && git add . && git commit -m "Initial release"`
- Push to GitHub for others to clone and install

## Output

A complete plugin directory ready for distribution, with all required metadata, skills, commands, and documentation.
