# Today Card and Lens Upgrade Design

Date: 2026-06-07

## Goal

Upgrade the Today core flow so its cards inherit the strongest qualities from the current reference UI:

- quiet paper-like surfaces;
- clear left-side semantic marks;
- restrained borders instead of heavy fills;
- compact state symbols;
- large enough whitespace for thinking, without turning the app into a decorative poster.

At the same time, upgrade the lens system so lenses are method assets, not just UI labels. A lens must explain when to use it, why it is recommended, and what kind of first question it should ask.

## Approved Scope

This slice focuses on the Today core flow:

- `ThinkingCardRow`
- `lensCard`
- `QuestionCardView`
- `QuestCardView`
- `LensCatalogItem`
- `LensLibrary`
- focused lens catalog and recommendation tests

This slice does not redesign History, Projects, Growth, Settings, persistence migrations, prompt templates, LLM networking, or the Today state machine.

## Reference Lessons

The reference card images in `yunying/images/02-thinking-cards.png` and `yunying/images/03-lens-selection.png` work because they are visually strict:

- The card shape is a thin thinking slip, not a floating dashboard tile.
- The semantic spine carries meaning without coloring the whole card.
- The selected lens uses a focus border and small marker instead of a large decorative background.
- Confirmation state is compact and symbolic.
- Buttons do not dominate the reading surface.
- The page uses warm paper, off-black text, and one accent at a time.

The current SwiftUI Today screens already contain useful foundations: `DS`, semantic card colors, left spines, lens metadata, and stable automation identifiers. The upgrade should refine these foundations rather than replace them.

## Visual Direction

The dominant structure is a working surface: dense enough for daily use, quiet enough for reflection.

Rules:

- Keep low-radius cards, approximately the existing `DS.cornerRadius`.
- Prefer borders, dividers, semantic spines, and typography over shadows.
- Use `DS.cardBackground`, `DS.surface`, and `Color(.systemBackground)` carefully so light and dark mode keep enough contrast.
- Use semantic accents as small spines, dots, icon fills, or tags.
- Do not introduce purple-blue gradients, glass effects, neon glow, or large decorative backgrounds.
- Do not place cards inside larger cards.

## Component Design

### ThinkingCardRow

The thinking card should read like an editable thought slip.

Required layout:

- A left semantic spine using `ThinkingCardType.color`.
- A compact header row with type label, optional priority/sensitivity marks, and confirmation state.
- A strong title line.
- Body text with relaxed line spacing and no visual competition from controls.
- A low-noise action row where confirm is the primary action and edit/exclude/delete are secondary.

Behavior must not change:

- Editing still updates type, title, body, priority, and sensitivity.
- Confirm, exclude, and delete actions keep existing AppStore semantics.
- Existing accessibility identifiers for Today automation remain intact.

### LensCard

The lens card should feel like choosing a thinking method.

Required layout:

- A stable method index or compact method marker.
- Lens title and short label.
- One-line subtitle.
- Method line, shown as the first question the lens tends to ask.
- Optional recommendation reason when the lens is recommended.
- Selected state shown through focus border, semantic spine, and compact check marker.

The card should use catalog data only. SwiftUI must not add new lens-specific switch statements for copy.

### QuestionCardView

The question card should feel like the lens has narrowed attention.

Required layout:

- A compact label such as `透镜追问`.
- The question as the main text.
- `whyItMatters` as supporting evidence, not as a second headline.
- A calm answer field with stable height and readable text.

Behavior must not change:

- Existing answer binding behavior remains.
- Existing accessibility identifier for the answer field remains.

### QuestCardView

The quest card should feel like a mission brief, not a gamified badge.

Required layout:

- Quest type label.
- Strong title.
- Structured rows for why it matters, completion criteria, expected resistance, and reflection question.
- Main quest receives a slightly stronger accent treatment; side or observation quests stay quieter.

Behavior must not change:

- Existing edit behavior remains.
- Existing accessibility identifier for quest edit remains.

## Lens System Upgrade

`LensCatalogItem` will become a fuller method asset while preserving existing identity rules.

Identity invariants:

- `ThinkingLens.rawValue` remains the durable local id.
- `LensCatalogItem.promptId` remains the model-facing id.
- Existing prompt guidance remains catalog-owned.
- Existing persisted history records remain compatible.

New catalog fields:

- `recommendedReason`: short user-facing reason used when the lens is suggested.
- `questionSeeds`: first-question style prompts owned by the lens.
- `accentRole`: a semantic display role that lets UI choose accents without switching on lens cases.
- `methodIndex`: a stable display order marker for Today lens cards.

These fields are first-party built-in metadata. They do not add custom lens editing, remote lens loading, or lens pack persistence in this slice.

## Lens Recommendation

Add a lightweight recommendation boundary to `LensLibrary`.

Recommended API shape:

```swift
func recommendedItem(
    for cards: [ThinkingCard],
    mode: SessionMode
) -> LensCatalogItem?
```

Initial rule set:

- Prefer `evidenceCheck` when cards include high-priority facts, risks, or problems that need validation.
- Prefer `opposingView` when problem/risk cards dominate or the session mode is deep.
- Prefer `leverageAnalysis` when task/decision cards dominate and the user needs an action.
- Prefer `firstPrinciples` when cards show unclear assumptions or no dominant semantic type.
- Fall back to the first built-in lens if evidence is sparse.

The recommendation is a display and guidance affordance only. It does not auto-select a lens or change prompt behavior unless the user selects it.

## Data Flow

The flow remains:

```text
ThinkingLens raw local id
-> LensCatalogItem metadata
-> Today lens UI
-> user selected lens
-> existing prompt payload uses promptId and promptGuidance
```

The new recommendation flow is:

```text
confirmed ThinkingCard list + SessionMode
-> LensLibrary recommendation
-> Today lens UI marks one card as recommended
-> user selects a lens manually
```

## Error Handling

- If recommendation cannot resolve a lens, Today renders the normal lens list with no recommendation marker.
- If a lens catalog lookup fails, existing safe fallbacks should remain local to the catalog boundary.
- If new optional display metadata is empty, UI falls back to existing title, subtitle, method line, and tint.

## Testing

Add focused tests near existing lens catalog tests:

- Built-in lens raw values remain unchanged.
- Prompt ids remain unchanged.
- Every built-in lens has non-empty title, subtitle, method line, prompt guidance, recommended reason, question seeds, accent role, and method index.
- Recommendation returns `evidenceCheck` for validation-heavy cards.
- Recommendation returns `leverageAnalysis` for task/action-heavy cards.
- Recommendation returns `opposingView` for risk/problem-heavy deep sessions.
- Recommendation returns `firstPrinciples` when there is no dominant semantic type.

UI rendering should be verified with:

- `git diff --check`
- focused XCTest for lens catalog/recommendation behavior
- Today-related AppStore tests if touched by compile dependencies
- iPhone simulator build when available
- rendered screenshot check for Today review cards and Select Lens if simulator access is working

## Acceptance Criteria

- Today cards visually move toward the reference UI: quieter paper slips, semantic spines, compact status, lower button noise.
- Lens selection visually reads as a method chooser with recommendation support.
- Lens catalog is upgraded into a richer method-asset boundary.
- Recommendation is available without auto-selecting or changing user choice semantics.
- Existing state machine, persistence identities, prompt ids, prompt guidance, and automation identifiers remain stable.
- Tests prove the lens system invariants and recommendation behavior.
