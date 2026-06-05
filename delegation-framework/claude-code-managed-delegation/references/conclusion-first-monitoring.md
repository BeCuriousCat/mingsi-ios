# Conclusion-First Monitoring

The manager consumes the conclusion layer by default.

## Conclusion Layer

Read these routinely:

- task progress file
- handoff summary
- worker changed-file list
- test/build command summary
- concerns and suggestions

The wrapper `status` command must surface the active `HANDOFF` summary and final status token when they exist. A progress file can be long; printing only the beginning can make a completed worker look stalled and force unnecessary raw-log inspection.

After manager acceptance, the manager-side progress file with `Status: CODEX_ACCEPTED` should take precedence over an older worker progress copy for routine status display.

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

## Relaunch Safety

Relaunches must preserve the worker-side conclusion file by default.

If the manager updates a prompt after a stalled or incomplete handoff, the wrapper may sync the new prompt and PRD into the worker worktree, but it must not overwrite a worker progress file that already contains `START`, `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF`.

Only reset worker progress when the manager explicitly intends to discard that attempt, for example with an override such as:

```bash
CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=1
```

This keeps the conclusion layer authoritative and prevents a relaunch from erasing the very progress evidence the manager is supposed to consume.

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
