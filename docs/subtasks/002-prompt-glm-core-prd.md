# Subtask 002: Prompt and GLM Core PRD

## Owner

Worker agent: Prompt, GLM client, typed response DTOs.

## Context

The product uses GLM as the MVP LLM provider. The app is BYOK: each user stores their own API Key in Keychain. The current `DirectGLMClient` is a stub and `LocalPromptProvider` only returns placeholder text.

## Scope

Allowed write scope:

- `Sources/Services/CoreProtocols.swift`
- new files under `Sources/Services/` for prompt/LLM DTOs
- new files under `Sources/Domain/` for prompt response models if necessary
- `project.yml` only if new source groups require it

Do not edit:

- UI files
- persistence repositories except protocol-compatible additions
- `Vendor/GRDB.swift`

## Requirements

1. Define typed request/response DTOs for GLM chat completions using `URLSession`.
2. Implement `DirectGLMClient.complete(_:)` so it sends one request to GLM and returns raw response `Data` or throws a meaningful error.
3. Keep provider-specific JSON isolated behind `DirectGLMClient`.
4. Improve `LocalPromptProvider` with real MVP prompt templates for:
   - organize cards
   - recommend lenses
   - generate questions
   - generate quests
   - verify quest
   - extract principle
5. Add a mock LLM client that returns deterministic sample JSON for UI/use case development.
6. Do not hardcode a real API Key.
7. Keep the interface compatible with a future `ProxyLLMClient`.

## Architecture Constraints

- Prompt text must not live in SwiftUI views.
- GLM endpoint/model values should be configurable via initializer defaults or small config type.
- Do not add third-party networking dependencies.
- Avoid making `LLMClient` generic if that causes wide call-site churn in the current scaffold. Typed decoding can be layered above raw `Data` in a later use case worker.

## Acceptance Criteria

- `DirectGLMClient` rejects empty API Key before network.
- GLM request uses bearer auth or the GLM-compatible documented auth header expected by their OpenAI-compatible endpoint.
- Mock client can be used without network.
- Build succeeds.

## Final Response Required

List:

- files changed
- request/response assumptions for GLM
- commands run and whether they passed
- risks left for Codex review
