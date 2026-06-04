# Conclusion-First Monitoring

The manager consumes the conclusion layer by default.

## Conclusion Layer

Read these routinely:

- task progress file
- handoff summary
- worker changed-file list
- test/build command summary
- concerns and suggestions

## Flow Layer

Open these only after a problem:

- raw Claude stream JSONL
- hook event JSONL
- tool-call trace dumps

Common reasons to inspect flow logs:

- no `START` after launch
- repeated stalled checks
- progress claims contradict repository state
- `HANDOFF` lacks verification evidence
- manager acceptance fails and the cause is unclear

## Stop Policy

Do not rescue partial worker output as the default path.

Default manager wait cadence:

```text
check 1: after 3 minutes
check 2: after 6 more minutes
check 3: after 9 more minutes
```

If those checks show no `HANDOFF` and no useful conclusion-progress movement, the manager may intervene. Intervention means classifying the stall first, not immediately editing the worker's partial code.

If conclusion progress moved during those checks, the worker is not considered silent. The manager should read the progress file first and usually allow one more check when the worker is running a named build or test loop.

If the worker stalls before `HANDOFF`, classify the failure first:

- launch failure
- missing context
- permission/tooling problem
- test/build environment problem
- task too broad
- incorrect implementation direction

Then choose one:

- relaunch with a tighter task contract
- split the task
- keep the task with Codex
- reject the worker result

## Flow Log Consumption

Flow logs are not the manager's daily reading queue. They are retained evidence.

Open raw/event logs only when at least one is true:

- the worker never wrote `START`
- scheduled checks show no conclusion progress
- the progress file contradicts repository state
- `HANDOFF` omits changed files or verification evidence
- Codex acceptance fails and the cause is unclear
