# AI Stream Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MingSi's AI organizing state feel like real streaming work by proving incremental card visibility and replacing the spinner with a restrained continuous rose-orbit loading mark.

**Architecture:** Keep the existing native SwiftUI Today flow. `DirectGLMClient` and `TodayAIService` already expose SSE tokens; the implementation focuses on AppStore/UI visibility and a small reusable SwiftUI loader, not WebView or JavaScript embedding.

**Tech Stack:** Swift, SwiftUI `TimelineView` + `Canvas`, XCTest, existing MingSi design system.

---

### Task 1: Prove Incremental Streaming Visibility

**Files:**
- Modify: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write the failing test**

Add an async streaming client that yields the first token, suspends until released, then yields the rest. Add a test under the Capture -> Organizing section:

```swift
func testCapture_streamingCardsAreVisibleBeforeStreamCompletes() async throws {
    let client = SuspendedStreamingLLMClient(
        firstToken: "<MINGSI_STREAM version=\"1\"><CARD><TYPE>task</TYPE><TITLE>准备会议目标</TITLE>",
        remainingTokens: [
            "<BODY>会前列出必须确认的问题。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>可验证行动</REASON></CARD></MINGSI_STREAM>"
        ]
    )
    store = AppStore(
        todayAIService: TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ),
        refreshesAIServiceFromKeychain: false
    )

    try await advanceTo(.capture)
    store.selectTodayMode(.standard)
    store.updateTodayCapture("明天会议前要准备目标。")
    store.submitTodayStep()

    try await waitUntil(
        !store.streamingCards.isEmpty,
        timeout: 2,
        file: #filePath,
        line: #line,
        failureMessage: "Expected a receiving streaming draft before stream completion"
    ) {
        !store.streamingCards.isEmpty
    }
    XCTAssertEqual(store.thinkingCards.count, 0)
    XCTAssertEqual(store.streamingCards.first?.title, "准备会议目标")
    XCTAssertEqual(store.streamingCards.first?.status, .receiving)

    client.releaseRemaining()

    try await waitForGeneratedCards()
    XCTAssertEqual(store.thinkingCards.first?.title, "准备会议目标")
    XCTAssertEqual(store.streamingCards.first?.status, .closed)
}
```

Add helper:

```swift
private final class SuspendedStreamingLLMClient: LLMClient, StreamingLLMClient {
    private let firstToken: String
    private let remainingTokens: [String]
    private var continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation?

    init(firstToken: String, remainingTokens: [String]) {
        self.firstToken = firstToken
        self.remainingTokens = remainingTokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            continuation.yield(.token(firstToken))
        }
    }

    func releaseRemaining() {
        guard let continuation else { return }
        for token in remainingTokens {
            continuation.yield(.token(token))
        }
        continuation.yield(.completed)
        continuation.finish()
        self.continuation = nil
    }
}
```

- [ ] **Step 2: Run test to verify behavior**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCapture_streamingCardsAreVisibleBeforeStreamCompletes
```

Expected if current app already supports true incremental visibility: PASS. Expected if SwiftUI/AppStore only exposes cards after completion: FAIL before implementation.

### Task 2: Smooth Burst Streams If Needed

**Files:**
- Modify: `Sources/App/AppStore.swift`
- Modify: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write failing burst test if Task 1 shows the local pipeline works**

Add a test that sends two complete cards in one token and asserts visible drafts are staged over at least two updates only if product requires staged presentation for burst chunks. If this is not required, skip implementation and document that real SSE chunk granularity controls visual card cadence.

- [ ] **Step 2: Implement only if required**

If needed, add a small MainActor staging helper in `generateCardsWithAIOrFallback` that publishes closed cards one card at a time with a short delay. Do not change `TodayAIService` parsing authority.

### Task 3: Replace Spinner With Continuous Rose Loader

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`

- [ ] **Step 1: Add native SwiftUI loader**

Add `RoseOrbitLoadingMark` near `AIGenerationProgressView`. Use `TimelineView(.animation)` and `Canvas` to draw:

- one faint continuous rose-orbit path
- one moving highlighted path segment or small head dot
- at most 12 very subtle tail samples, not 42+ visible particles
- fixed 42x42 default size
- `DS.accent` color
- hidden when `accessibilityReduceMotion` is true, falling back to a simple static orbit mark

- [ ] **Step 2: Use loader in AI progress card**

Replace the `ProgressView()` inside `AIGenerationProgressView` with:

```swift
RoseOrbitLoadingMark()
    .frame(width: 42, height: 42)
    .accessibilityHidden(true)
```

Keep the existing text, linear progress, and step list.

- [ ] **Step 3: Verify focused tests**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCapture_streamingCardsAreVisibleBeforeStreamCompletes
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks
git diff --check
```
