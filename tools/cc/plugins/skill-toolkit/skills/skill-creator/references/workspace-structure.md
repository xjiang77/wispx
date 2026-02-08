# Workspace Structure

Workspaces are created as sibling directories to the skill being worked on.

```
parent-directory/
├── skill-name/                      # The skill
│   ├── SKILL.md
│   ├── evals/
│   │   ├── evals.json
│   │   └── files/
│   └── scripts/
│
└── skill-name-workspace/            # Workspace (sibling directory)
    │
    │── [Eval mode]
    ├── eval-0/
    │   ├── with_skill/
    │   │   ├── inputs/              # Staged input files
    │   │   ├── outputs/             # Skill outputs
    │   │   │   ├── transcript.md
    │   │   │   ├── user_notes.md    # Executor uncertainties
    │   │   │   ├── metrics.json
    │   │   │   └── [output files]
    │   │   ├── grading.json         # Assertions + claims + user_notes_summary
    │   │   └── timing.json          # Wall clock timing
    │   └── without_skill/
    │       └── ...
    ├── comparison.json              # Blind comparison (A/B testing)
    ├── summary.json                 # Aggregate metrics
    │
    │── [Improve mode]
    ├── history.json                 # Score progression across versions
    ├── v0/
    │   ├── META.yaml                # Version metadata
    │   ├── skill/                   # Copy of skill at this version
    │   └── runs/
    │       ├── run-1/
    │       │   ├── transcript.md
    │       │   ├── user_notes.md
    │       │   ├── outputs/
    │       │   └── grading.json
    │       ├── run-2/
    │       └── run-3/
    ├── v1/
    │   ├── META.yaml
    │   ├── skill/
    │   ├── improvements/
    │   │   └── suggestions.md       # From analyzer
    │   └── runs/
    └── grading/
        └── v1-vs-v0/
            ├── assignment.json      # Which version is A vs B
            ├── comparison-1.json    # Blind comparison results
            ├── comparison-2.json
            ├── comparison-3.json
            └── analysis.json        # Post-hoc analysis
    │
    │── [Benchmark mode]
    └── benchmarks/
        └── 2026-01-15T10-30-00/      # Timestamp-named directory
            ├── benchmark.json        # Structured results (see schema)
            ├── benchmark.md          # Human-readable summary
            └── runs/
                ├── eval-1/
                │   ├── with_skill/
                │   │   ├── run-1/
                │   │   │   ├── transcript.md
                │   │   │   ├── user_notes.md
                │   │   │   ├── outputs/
                │   │   │   └── grading.json
                │   │   ├── run-2/
                │   │   └── run-3/
                │   └── without_skill/
                │       ├── run-1/
                │       ├── run-2/
                │       └── run-3/
                └── eval-2/
                    └── ...
```

## Key Files

- `transcript.md` - Execution log from executor
- `user_notes.md` - Uncertainties and workarounds flagged by executor
- `metrics.json` - Tool calls, output size, step count
- `grading.json` - Assertion pass/fail, notes, user_notes summary
- `timing.json` - Wall clock duration
- `comparison-N.json` - Blind rubric-based comparison
- `analysis.json` - Post-hoc analysis with improvement suggestions
- `history.json` - Version progression with pass rates and winners
- `benchmark.json` - Structured benchmark results with runs, run_summary, notes
- `benchmark.md` - Human-readable benchmark summary
