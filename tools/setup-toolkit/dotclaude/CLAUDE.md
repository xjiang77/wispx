## Core Rules

1. **Action Over Planning**: Do NOT enter plan mode for simple/medium tasks. If the user provides a plan or clear instruction, execute it immediately — do NOT re-plan. Only use plan mode for genuinely complex architectural decisions or 5+ steps across multiple systems. When in doubt, act.

2. **Prove It Works**: Never say "verified" or "already implemented" without running the actual command and showing its output. Reading a file is NOT verification. Run the code, paste the terminal output. If a command fails, fix and retry — don't claim partial success.

3. **Pick and Act**: When fixing something, pick the most reasonable approach and do it. Do NOT present multiple options and ask the user to choose unless the decision is truly ambiguous and high-stakes.

4. **No False Completions**: If you haven't run the verification command, the task is NOT complete. Period.

5. **One Task Per Session**: Focus on completing one goal fully before starting another. Don't spread effort across multiple unfinished tasks.

## Code Style

- Don't add comments, docstrings, or type annotations to code you didn't change.
- Don't add error handling for scenarios that can't happen.

## Writing

- 中英文混合：technical terms in English, explanations in Chinese.
