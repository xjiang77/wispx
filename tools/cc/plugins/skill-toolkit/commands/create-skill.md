---
description: Scaffold and build a new skill interactively with evals and iterative improvement
argument-hint: "<skill name or description>"
---

# Create Skill

Create a new agent skill from scratch, with support for iterative improvement through evaluations and benchmarks.

## Workflow

### 1. Understand What the User Wants

Ask the user what kind of skill they want to create. Accept any of:
- A skill name ("markdown-formatter")
- A description ("a skill that helps write better commit messages")
- A vague idea ("something for reviewing pull requests")
- A reference to an existing tool or workflow to replicate

### 2. Scaffold the Skill

Use the **skill-creator** skill for the full creation workflow. It provides:

- Interactive skill design and drafting
- Template generation with proper frontmatter and structure
- Eval creation and execution for testing skill quality
- Iterative improvement through blind comparisons
- Benchmark mode for measuring performance across versions

### 3. Create the Skill

Follow the skill-creator's process:
1. Draft the SKILL.md with clear instructions
2. Create test prompts (eval cases)
3. Run the skill against test prompts
4. Evaluate results (automated or manual)
5. Iterate based on feedback

### 4. Review Before Finalizing

Once the skill is drafted, offer to run it through the **skill-reviewer** for quality checks before the user starts using it.

## Quick Start

For users who want a fast start without the full eval workflow:

1. Initialize the skill structure using `python ${CLAUDE_PLUGIN_ROOT}/skills/skill-creator/scripts/init_skill.py <skill-name>`
2. Fill in the SKILL.md template
3. Test manually
4. Iterate

## Output

A complete skill directory with:
- SKILL.md (main instructions)
- Any supporting files (scripts/, references/, agents/)
- Optional: eval cases and results
