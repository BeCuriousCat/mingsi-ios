# MingSi Delegation Experience Export

MingSi keeps full delegation evidence in this repo, but exports only structured framework lessons.

## Local Files

- Raw/task evidence stays in `docs/subtasks/`, `docs/subtasks/logs/`, and `docs/agent-delegation-log.md`.
- Structured framework lessons are written to `.codex/delegation-experience/outbox/mingsi-ios/*.jsonl`.
- The generated entry point is `scripts/record_delegation_experience.sh`.

## When To Export

Export one small event when a delegation issue teaches a reusable framework lesson:

- launch or before-`START` failures
- handoff parsing mistakes
- progress overwrite or relaunch-safety problems
- status/wait behavior problems
- resource guard or cleanup problems
- flow-log versus conclusion-log consumption problems

Do not export:

- raw model logs
- API keys, tokens, or user input dumps
- MingSi-only product semantics
- full source diffs
- screenshot files

## Example

```bash
scripts/record_delegation_experience.sh \
  --task 057-project-detail-visual-qa-fixture-variants \
  --category launch-exit-mismatch \
  --symptom 'print-mode launch reported no-handoff while status later found worker HANDOFF/DONE' \
  --root-cause 'print launch-exit path did not reuse the same conclusion parser as status' \
  --impact 'manager may classify delivered worker output as non-delivery' \
  --candidate-fix 'make print-mode launch exit reuse the final handoff token parser used by status/wait' \
  --source-file docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md \
  --generalizable true
```

## Cost Control

The export record is intentionally short. MingSi does not copy raw logs into the framework. The framework later runs deterministic collection and digest scripts, so routine experience transfer does not require an LLM to reread the project history.

## Hook And Nightly Automation

Any MingSi-side hook should call `scripts/record_delegation_experience.sh` with explicit fields. Hooks should not attach raw Claude logs or source diffs.

The framework-side nightly job is:

```bash
/Users/chenzewei/Documents/codex/projects/codex-claude-delegation-framework/bin/nightly_collect.sh
```

That script reads configured project sources from the framework's `experience-sources.json`, collects new outbox events with dedupe, and writes deterministic digest / upgrade-candidate files.
