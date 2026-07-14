# MingSi Current Goal

Date: 2026-07-11

## Current Product Stage

MingSi has completed the implementation and local regression of the three-stage Today flow:

1. 讲清今天
2. 找出判断
3. 行动验证

The product is now in closed-loop usability validation, not feature-completion expansion. The internal ten-state `DailyLoopState` remains an implementation detail and must not leak back into the user-visible hierarchy.

## Pending User-Experience Action

Status: pending external confirmation.

Run a 3-7 day trial with real users before making another large Today hierarchy change. Record:

- three-stage completion rate;
- abandonment stage and reason;
- whether the coaching question repaired a real thinking gap;
- whether the validation action was completed the next day;
- which questions felt repetitive, generic, or incorrectly targeted.

Do not treat local UI preference as proof of coaching quality. The next Today change should be driven by repeated user evidence or a correctness/accessibility defect.

## Known Work That Can Continue Before Trial Feedback

### 1. Model Provider Profiles

Current implementation has one GLM-labelled configuration slot:

- one Keychain API Key;
- one configurable Base URL;
- one configurable model name;
- one OpenAI-compatible Chat Completions transport;
- Bearer authorization only.

This already allows compatible gateways and some OpenAI-compatible models when their response shape matches the current client. It is not a real multi-provider system.

Required next state:

- named provider profiles;
- explicit protocol kind per profile;
- OpenAI-compatible Chat Completions adapter;
- OpenAI Responses adapter when required by the selected model;
- Anthropic Messages adapter for native Claude API use;
- active-profile switching and per-profile connection tests;
- provider and model names recorded accurately in `PromptRun` audit.

`Claude Code` is a coding-agent CLI, not an inference endpoint. MingSi should support Claude models through the Anthropic API or a compatible gateway, not by treating Claude Code as a Base URL.

### 2. Credential Vault And Previous Credentials

Current behavior replaces the single Keychain value when a new API Key is saved. It does not retain history.

Do not add an automatic plaintext-style API Key history. Use an opt-in credential vault instead:

- secrets remain in Keychain only;
- database/export/logs store only profile id, provider, masked label, fingerprint, creation date, and last-used date;
- a profile may retain multiple named credentials only after explicit user confirmation;
- previous credentials are never retried automatically;
- deletion removes the Keychain item and its non-secret metadata;
- migration preserves the existing `glm_api_key`, Base URL, and model name as a default legacy profile.

### 3. Provider Compatibility And Connection Proof

The current connection test proves that one minimal request returned successfully. It does not prove that all MingSi prompts, streaming, JSON parsing, retry behavior, or token limits work with that provider.

Add provider-profile acceptance checks for:

- normal JSON completion;
- SSE streaming;
- structured-output compatibility or fallback;
- authentication and endpoint error classification;
- model/context limits;
- one representative Today prompt parse.

### 4. Coaching Quality Feedback Capture

The trial needs lightweight local feedback attached to the exact coach turn:

- useful;
- wrong target;
- repetitive;
- too abstract;
- gave away the answer;
- optional note.

This feedback should reference the prompt run and deterministic coach observation without storing API secrets or raw provider responses as product evidence.

### 5. Remaining Product Hardening

- continue dark-mode and accessibility checks on dense Settings, History, Project, and Growth states;
- add longitudinal Growth comparisons only when evidence attribution remains inspectable;
- extract model configuration and AI client creation out of `AppStore` before adding several provider adapters;
- keep User Center expansion behind actual account/sync/privacy requirements rather than adding an empty profile surface.

## Next Milestone

The next implementation milestone is **Provider Profile Foundation v1**.

Acceptance criteria:

- the existing GLM Keychain configuration migrates without losing access;
- users can create, edit, switch, test, and delete named provider profiles;
- OpenAI-compatible profiles work without GLM-specific UI or audit labels;
- credentials remain Keychain-only;
- previous credentials are retained only through explicit opt-in named entries;
- the architecture can add native OpenAI Responses and Anthropic Messages adapters without changing Today state-machine code;
- existing Today, PromptRun audit, fallback, and repair tests remain green.

After Provider Profile Foundation v1, implement native OpenAI and Anthropic adapters as separate verified slices. Coaching-quality calibration resumes when real-user trial evidence is available.

## Constraints

- Do not log, export, or persist raw API Keys outside Keychain.
- Do not call a provider "supported" based only on a configurable URL.
- Do not silently fall back from one saved credential to an older credential.
- Do not let provider-specific code enter SwiftUI or the Today state machine.
- Do not expand User Center until identity, sync, or collaboration becomes a real requirement.
