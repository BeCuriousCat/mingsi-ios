# Subtask 008: Project Evidence Layer PRD

## Goal

Replace decorative Project UI with an evidence-backed project model.

Project means a user-confirmed long-running topic, workflow, goal, blocker, or behavior standard. It is not a folder or raw keyword cluster.

## Write Scope

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/MockLLMClient.swift`
- `Sources/Services/TodayAIResponseParser.swift` or a new parser file
- `Sources/Features/FeatureTabs.swift`

Avoid touching Today loop UI except for a minimal project-link suggestion entry point if needed.

## Requirements

- Add `Project`, `ProjectCandidate`, `ProjectLink`, `ProjectMergeCandidate`, and `ProjectInsight` domain models.
- Add persistence tables, migrations, and repository methods.
- Add PromptID/support for:
  - suggest project links
  - generate project insights
  - suggest project merge candidates
- Project links require source type and source id.
- Project candidates require source refs and user confirmation before becoming Projects.
- Project insights require source refs; `thinking_change` requires before and after evidence.
- ProjectsView must render real projects only.
- If no project exists, show an empty evidence state, not hardcoded project rows.
- Project detail must show:
  - overview
  - timeline
  - progress signals
  - thinking change before/after
  - open questions
  - principles
- Candidate review must support create, rename-and-create, dismiss, and reject.

## Acceptance Criteria

- A project can be created with a privacy-safe name, goal, and bottleneck.
- AI project candidates do not appear as real projects until confirmed.
- A confirmed card/quest/verification/principle can be linked to a project.
- Project progress signals deep-link to source history records.
- Project thinking change is hidden unless before/after evidence exists.
- Project UI has no static fake rows.
- Build succeeds.
