# Task Contract

A delegation task contract should be short enough for the manager to write quickly and strict enough for the worker to execute without new product decisions.

## Required Fields

```text
id:
title:
purpose:
allowed_files:
forbidden_files:
worker_can_commit: true | false
required_tests:
required_builds:
acceptance_criteria:
stall_policy:
```

## Optional Fields

```text
context_files:
known_risks:
ui_screens_to_verify:
budget_class: ordinary | large
expected_changed_lines:
```

## Design Rule

The task contract is the human-authored source. PRD, progress, prompt, log paths, and wrapper launch commands should be generated or templated from it whenever possible.

This prevents the manager from spending more tokens writing process boilerplate than implementing the feature directly.

