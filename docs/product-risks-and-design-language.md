# Product Risks and Design Language

## Real-Use Risks

The product has a strong concept, but real users may still fail to use it consistently. The MVP should anticipate these issues early.

### 1. The Daily Loop May Feel Too Heavy

Risk:

- The user is already busy.
- A 10-15 minute reflection can still feel expensive after a long workday.
- Too many required steps can make the user abandon the loop.

Product response:

- Support three modes:
  - Quick: capture -> organize -> one main quest.
  - Standard: capture -> cards -> lens -> quest.
  - Deep: full reflection with questions and calibration.
- Let the user save an incomplete loop without shame.
- Always make Resume Today obvious.

### 2. AI May Sound Generic

Risk:

- If questions feel like generic self-help, the user will stop trusting the product.

Product response:

- Questions must reference confirmed cards.
- Prompts must require evidence, assumptions, and alternatives.
- User should be able to mark "not useful" on AI questions or quests.
- Weekly review should identify which lenses were useful.

### 3. The User May Avoid Hard Questions

Risk:

- The product may become a comfortable summary tool instead of a thinking trainer.

Product response:

- Add one optional "hard question" after each session.
- Use gentle but direct copy.
- Track repeated avoidance patterns through verification reasons.

### 4. Privacy Anxiety May Reduce Use

Risk:

- Work content may be sensitive.
- User may hesitate to write enough detail.

Product response:

- Encourage abstract naming.
- Collapse raw input in history.
- Show what will be sent to the model.
- Support sensitive-card exclusion.
- Keep local-first storage where practical.

### 5. Metrics May Feel Fake

Risk:

- Ability scores can feel arbitrary.
- Users may reject them if they look like objective intelligence scores.

Product response:

- Present metrics as personal trends.
- Always link scores to evidence.
- Prefer before/after examples over large dashboard charts.

### 6. History Can Become Clutter

Risk:

- Daily entries may accumulate without becoming useful.

Product response:

- History should default to verified outcomes and confirmed cards.
- Raw input stays collapsed.
- Growth and Projects deep-link to relevant historical evidence.
- Search and filters must support project, lens, card type, and quest status.

### 7. Novelty May Fade

Risk:

- The first week may feel exciting, then the loop becomes repetitive.

Product response:

- Rotate the recommended thinking lens.
- Weekly calibration should change the next training focus.
- Surface visible before/after examples monthly.
- Keep the daily loop lightweight.

## Product Shape Optimizations

The product should not be a rigid funnel. It should be a guided workspace.

Recommended shape:

```text
Today = active loop
History = evidence layer
Projects = context layer
Growth = calibration layer
Settings = control layer
```

Today should adapt to the user's state:

- If yesterday has an unverified quest, start with verification.
- If today has no input, start with capture.
- If cards exist but are unconfirmed, resume card review.
- If questions are answered but quest is missing, resume quest generation.
- If the loop is complete, show tomorrow's main quest.

This makes the product feel responsive without requiring the user to follow tabs in order.

## Design Language

Recommended design language:

```text
Calm Native Intelligence
```

Attributes:

- Calm: low visual noise, no productivity anxiety.
- Native: feels like a first-class iOS app.
- Intelligent: uses structure, evidence, and precise prompts rather than flashy AI effects.
- Personal: serious enough for work reflection, warm enough for daily private use.

The design should communicate:

- Clarity.
- Thoughtfulness.
- Focus.
- Trust.
- Progress through evidence.

It should avoid:

- Chatbot-first UI.
- Generic SaaS dashboards.
- Heavy gamification.
- Wellness-journal softness.
- Corporate admin-panel density.
- Template card grids.

## Native iOS and SwiftUI Rationale

Programming language does not automatically create good taste. Good taste comes from product judgment, component design, typography, spacing, motion, and restraint.

However, native Swift/SwiftUI improves the odds of achieving the desired interaction quality because it gives direct access to iOS-native patterns:

- SwiftUI transitions and `matchedGeometryEffect` for smooth card expansion and state changes.
- Native gestures, sheets, navigation, menus, and context actions.
- Native keyboard and dictation behavior.
- Haptics for important confirmations.
- Dynamic Type and accessibility support.
- SQLite/GRDB local persistence for on-device records.
- AppIntents, Shortcuts, Widgets, and notifications as future extensions.

Recommended implementation:

- Use SwiftUI as the primary UI layer.
- Use small UIKit bridges only where SwiftUI is not sufficient, such as advanced text editing if needed.
- Avoid WebView as the primary app shell for the MVP.
- Keep PromptCore, LLMCore, storage, and future server adapters separate so the product can later support web or Android without rewriting the thinking system.

## Interaction Opportunities for Native iOS

MVP can stay simple, but the architecture should support:

- Raw input transforming into cards.
- Card expansion into detail.
- Lens focus transition.
- Quest acceptance confirmation.
- Subtle haptic on accepting the main quest.
- Reduce Motion support.
- Widget showing tomorrow's main quest.
- Notification asking for next-day verification.
- Shortcut for quick capture.

These are natural on iOS and would feel less polished if implemented as a generic web-style shell.

## Design and Engineering Boundary

To keep the app extensible:

- The UI should be native and high-taste.
- The data model should stay semantic and platform-neutral.
- Prompt and model capabilities should be exposed through stable provider protocols.
- Prompt and eval logic should not depend on iOS-specific UI.

This gives the MVP a premium iOS experience while preserving long-term product portability.
