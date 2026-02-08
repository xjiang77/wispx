# Task Tracking

Use tasks to track progress on multi-step workflows.

## Task Lifecycle

Each eval run becomes a task with stage progression:

```
pending → planning → implementing → reviewing → verifying → completed
          (prep)     (executor)     (grader)    (validate)
```

## Creating Tasks

When running evals, create a task per eval run:

```python
TaskCreate(
    subject="Eval 0, run 1 (with_skill)",
    description="Execute skill eval 0 with skill and grade expectations",
    activeForm="Preparing eval 0"
)
```

## Updating Stages

Progress through stages as work completes:

```python
TaskUpdate(task, status="planning")     # Prepare files, stage inputs
TaskUpdate(task, status="implementing") # Spawn executor subagent
TaskUpdate(task, status="reviewing")    # Spawn grader subagent
TaskUpdate(task, status="verifying")    # Validate outputs exist
TaskUpdate(task, status="completed")    # Done
```

## Comparison Tasks

For blind comparisons (after all runs complete):

```python
TaskCreate(
    subject="Compare skill-v1 vs skill-v2"
)
# planning = gather outputs
# implementing = spawn blind comparators
# reviewing = tally votes, handle ties
# verifying = if tied, run more comparisons or use efficiency
# completed = declare winner
```
