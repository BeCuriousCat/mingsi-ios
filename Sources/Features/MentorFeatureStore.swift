import Foundation
import Combine

protocol MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data
}

// The application can pass its shared gateway without constructing a feature-specific client.
extension CentralLLMDecisionCenter: MentorTransport {}

struct MentorFeatureState: Equatable {
    enum Phase: Equatable { case idle, editing, reading, selectingLesson, lessonExhausted, submitting, showingResponse, paused, ended, failed(String) }
    var phase: Phase = .idle
    var session: MentorSession?
    var isViewingHistory = false
    var deletionError: String?
    var isDeletingSession = false
    var isDeletingUnderstanding = false
    var understandingDeletionError: String?
    var timeline: [MentorTimelineItem] = []
    var borrowedCaptureSources: [UUID: [MentorSourceReference]] = [:]
    var lesson: MentorSavedLesson?
    var lessonError: String?
    var readingPositionError: String?
    var pendingReadingPositionSaves = 0
    var lessonFeedbackError: String?
    var lessonFeedbackNotice: String?
    var isSavingLessonFeedback = false
    var benefitFeedback: MentorBenefitFeedback?
    var benefitFeedbackNote = ""
    var benefitFeedbackError: String?
    var isSavingBenefitFeedback = false
    var response: MentorValidatedTurn?
    var responseItemID: UUID?
    var acknowledgedResponseItemID: UUID?
    var presentationError: String?
    var understandings: [MentorUnderstanding] = []
    var understanding: MentorUnderstanding?
    var understandingInputText = ""
    var hasUnsavedUnderstanding = false
    var understandingError: String?
    var understandingGenerationError: String?
    var isGeneratingUnderstanding = false
    var generatedUnderstandingID: UUID?
    var pendingUnderstandingOperations = 0
    var isConfirmingUnderstanding = false
    var latestUnfinishedSession: MentorSessionSummary?
    var recentSessions: [MentorSessionSummary] = []
    var hasMoreRecentSessions = false
    /// Read-only projection of an old single-nudge chain. A damaged chain is
    /// still inspectable, but must offer an explicit round-level recovery
    /// instead of pretending that the whole lineage can be continued.
    var legacyChain: LegacyNudgeChain?
    var historyError: String?
    var isLoadingHistory = false
    var canRetryResponseSave = false
    var requestFinalizationError: String?
    var canRetryRequestFinalization = false
    /// True after the foreground request has exceeded the user-facing waiting
    /// threshold. It is separate from the transport timeout and session phase.
    var requestWaitingNotice = false
    var streamingPreview = ""
    var requestFailureMessage: String?
    var retryableRequest: MentorRetryableRequest?
    var retryError: String?
    var actionError: String?
    var correctionError: String?
    var materialSelection: MentorMaterialSelectionState?
    var inputText = ""
    var draftRevision = 0
    var hasUnsavedDraft = false
    var isSavingDraft = false
    var draftSaveError: String?
    var isTransitioningSession = false
}

/// Uses the system clock in production; tests can advance the watchdog after a
/// request reaches its intended lifecycle boundary without racing database setup.
struct MentorDeadlineClock {
    var now: () -> ContinuousClock.Instant
    var sleepUntil: (ContinuousClock.Instant) async throws -> Void
    static var live: Self {
        Self(now: { ContinuousClock.now }, sleepUntil: { try await ContinuousClock().sleep(until: $0) })
    }
}

/// The M1 flow coordinator. Persistence commands remain the authority for lifecycle
/// and ownership; this store only owns foreground intent and presentation state.
@MainActor
final class MentorFeatureStore: ObservableObject {
    @Published private(set) var state = MentorFeatureState()
    private let repository: MentorRepository
    private let legacyNudgeAdapter: LegacyNudgeAdapter?
    private var transport: MentorTransport
    private var promptProvider: PromptProvider
    private let catalog: MentorLessonCatalog?
    private let timeZone: TimeZone
    private let now: () -> Date
    private let uptime: () -> TimeInterval
    private let deadlineClock: MentorDeadlineClock
    private let onOwnedDataDeleted: (() -> Void)?
    private let onReviewReady: ((UUID, [LifeGuidanceEvent]) -> Void)?
    private let beginForegroundAIActivity: (() -> Bool)?
    private let endForegroundAIActivity: (() -> Void)?
    private var requestPolicy: MentorRequestPolicy
    private var activeRequestPolicy: MentorRequestPolicy?
    private var activeStreamProgress: MentorStreamProgress?

    var hasLessonCatalog: Bool { catalog != nil }
    var canContinueRecall: Bool {
        !state.isViewingHistory && sessionTransitionID == nil && state.phase == .showingResponse &&
        state.session?.initialEntry == "review" &&
        (state.session?.recallCount ?? 0) >= 2 && state.responseItemID != nil &&
        state.responseItemID == state.acknowledgedResponseItemID &&
        !state.isGeneratingUnderstanding && state.materialSelection == nil &&
        pendingResponse == nil && pendingRequestEnd == nil
    }
    private var pendingRecallContinuation: (sessionID: UUID, commandID: UUID, epoch: Int)?
    private struct PendingResponse {
        let sessionID: UUID
        let requestID: UUID
        let payload: String
        let validated: MentorValidatedTurn
        let consumedDraft: MentorConsumedDraft?
    }
    private struct PendingRequestEnd {
        let sessionID: UUID
        let requestID: UUID
        let reason: MentorRequestEndReason
    }
    private var pendingRequestEnd: PendingRequestEnd?
    private var pendingResponse: PendingResponse?
    private var requestTask: Task<Void, Never>?
    private var requestWaitingTask: Task<Void, Never>?
    private var requestDeadlineTask: Task<Void, Never>?
    private var requestWaitingGeneration = UUID()
    private var activeRequestID: UUID?
    private var activeRequestGeneration: UUID?
    private var dependencyGeneration = UUID()
    private struct DraftSnapshot: Equatable {
        let sessionID: UUID
        let revision: Int
        let text: String
    }
    /// A discuss entry starts as an in-memory session. It is materialized only
    /// when the user supplies content that should survive leaving the page.
    private struct PendingSession {
        let id: UUID
        let entry: String
        let attemptID: UUID
    }
    /// A review entry can begin with no user material. The durable session is
    /// created first, then the opening prompt is sent after the navigation
    /// transition has ended so the response can be shown immediately.
    private struct ReviewOpening {
        let session: MentorSession
        let attemptID: UUID
    }
    private var pendingSession: PendingSession?
    private var draftDebounceTask: Task<Void, Never>?
    private var draftWriteTask: Task<Bool, Never>?
    private var draftWritingSnapshot: DraftSnapshot?
    private var sessionTransitionID: UUID?
    private var understandingDebounceTask: Task<Void, Never>?
    private var pendingUnderstandingText: String?
    private var understandingTask: Task<Void, Never>?
    private var understandingGenerationTask: Task<Void, Never>?
    private var understandingRequestGeneration = UUID()
    private var understandingGeneration = UUID()
    private var pendingUnderstandingCreation: (id: UUID, previousRevisionID: UUID?)?
    private var readingPositionTask: Task<Void, Never>?
    private var lessonFeedbackTask: Task<Void, Never>?
    private var benefitFeedbackTask: Task<Void, Never>?
    private var presentationTask: Task<Void, Never>?
    private var acknowledgedPresentationIDs = Set<UUID>()
    private var pendingPresentationIDs = Set<UUID>()
    private var presentationObservations: [UUID: (date: Date, uptime: TimeInterval)] = [:]
    private var historyTask: Task<Void, Never>?
    private var historyGeneration = UUID()
    private var historyPager = MentorHistoryPager()
    private var activeAttemptID: UUID?
    private var activeAttemptEventTask: Task<Void, Never>?
    private struct UsageAttempt {
        let startedAt: TimeInterval
        var currentEntry: String
        var sessionID: UUID?
        var hasPresentedContent = false
        var hasExited = false
        var pendingOperations = 0
    }
    private struct UsageRequest {
        let attemptID: UUID
        let sessionID: UUID
        let startedAt: TimeInterval
        var endedAt: TimeInterval?
        var switchedEntry: String?
    }
    private var usageAttempts: [UUID: UsageAttempt] = [:]
    private var usageRequests: [UUID: UsageRequest] = [:]
    private var waitingStartedAt: TimeInterval?
    private struct PendingMaterialSubmission {
        let sessionID: UUID
        let intent: String
        let text: String
        let restorePhase: MentorFeatureState.Phase
        var userItemID: UUID? = nil
    }
    private var pendingMaterialSubmission: PendingMaterialSubmission?

    init(repository: MentorRepository, transport: MentorTransport, legacyNudgeAdapter: LegacyNudgeAdapter? = nil,
         catalog: MentorLessonCatalog? = nil,
         promptProvider: PromptProvider = LocalPromptProvider(), timeZone: TimeZone = .current,
         now: @escaping () -> Date = { .now },
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         onOwnedDataDeleted: (() -> Void)? = nil,
         onReviewReady: ((UUID, [LifeGuidanceEvent]) -> Void)? = nil,
         beginForegroundAIActivity: (() -> Bool)? = nil,
         endForegroundAIActivity: (() -> Void)? = nil,
         requestWaitingNoticeAfter: Duration? = nil,
         requestDeadlineAfter: Duration? = nil,
         deadlineClock: MentorDeadlineClock = .live,
         requestPolicy: MentorRequestPolicy = .m1) {
        self.repository = repository
        self.transport = transport
        self.legacyNudgeAdapter = legacyNudgeAdapter
        self.promptProvider = promptProvider
        self.catalog = catalog
        self.timeZone = timeZone
        self.now = now
        self.uptime = uptime
        self.deadlineClock = deadlineClock
        self.onOwnedDataDeleted = onOwnedDataDeleted
        self.onReviewReady = onReviewReady
        self.beginForegroundAIActivity = beginForegroundAIActivity
        self.endForegroundAIActivity = endForegroundAIActivity
        self.requestPolicy = MentorRequestPolicy(
            deadline: requestDeadlineAfter ?? requestPolicy.deadline,
            waitingNoticeAfter: requestWaitingNoticeAfter ?? requestPolicy.waitingNoticeAfter,
            maxHTTPAttempts: requestPolicy.maxHTTPAttempts,
            allowsFormatFallback: requestPolicy.allowsFormatFallback,
            outputTokenBudget: requestPolicy.outputTokenBudget)
    }

    deinit { understandingDebounceTask?.cancel(); draftDebounceTask?.cancel(); draftWriteTask?.cancel(); readingPositionTask?.cancel(); lessonFeedbackTask?.cancel(); benefitFeedbackTask?.cancel(); requestTask?.cancel(); requestWaitingTask?.cancel(); requestDeadlineTask?.cancel(); historyTask?.cancel(); presentationTask?.cancel(); understandingTask?.cancel(); understandingGenerationTask?.cancel() }

    private func acquireForegroundAIActivity() -> Bool {
        beginForegroundAIActivity?() ?? true
    }

    private func releaseForegroundAIActivity() {
        endForegroundAIActivity?()
    }

    /// Keep the UI honest while a transport is still pending. The notice task
    /// exposes the earlier waiting state; the deadline is armed once the
    /// audited request has an ID that can be finalized safely.
    @discardableResult
    private func beginRequestWaitingNotice() -> UUID {
        requestWaitingTask?.cancel()
        requestDeadlineTask?.cancel()
        let generation = UUID()
        let policy = requestPolicy
        activeRequestPolicy = policy
        requestWaitingGeneration = generation
        waitingStartedAt = uptime()
        activeRequestID = nil
        activeRequestGeneration = nil
        state.requestWaitingNotice = false
        state.streamingPreview = ""
        activeStreamProgress = nil
        requestWaitingTask = Task { [weak self] in
            do {
                try await Task.sleep(for: policy.waitingNoticeAfter)
                guard let self, !Task.isCancelled, requestWaitingGeneration == generation else { return }
                state.requestWaitingNotice = true
            } catch {
                // Cancellation is the normal path when the request settles.
            }
        }
        return generation
    }

    private func makeStreamProgress(generation: UUID, startedAt: ContinuousClock.Instant, field: String) -> MentorStreamProgress {
        let progress = MentorStreamProgress(startedAt: startedAt, field: field) { [weak self] preview in
            Task { @MainActor [weak self] in
                guard let self, requestWaitingGeneration == generation,
                      state.phase == .submitting || state.isGeneratingUnderstanding else { return }
                guard preview.count >= state.streamingPreview.count else { return }
                state.streamingPreview = preview
            }
        }
        activeStreamProgress = progress
        return progress
    }

    private func armRequestDeadline(generation: UUID, policy: MentorRequestPolicy, startedAt: ContinuousClock.Instant) {
        requestDeadlineTask?.cancel()
        requestDeadlineTask = Task { [weak self] in
            do {
                while self != nil {
                    let expiry = self?.activeStreamProgress.map { max(startedAt, $0.lastContentAt).advanced(by: policy.streamingIdleDeadline) }
                        ?? startedAt.advanced(by: policy.deadline)
                    guard let clock = self?.deadlineClock else { return }
                    try await clock.sleepUntil(expiry)
                    let updated = self?.activeStreamProgress.map { max(startedAt, $0.lastContentAt).advanced(by: policy.streamingIdleDeadline) }
                        ?? startedAt.advanced(by: policy.deadline)
                    if clock.now() >= updated { break }
                }
                guard let self, !Task.isCancelled, requestWaitingGeneration == generation,
                      activeRequestGeneration == generation, activeRequestID != nil,
                      (state.phase == .submitting || state.isGeneratingUnderstanding) else { return }
                await timeOutRequest(generation: generation)
            } catch {
                // Cancellation is the normal path when the request settles.
            }
        }
    }

    private func endRequestWaitingNotice(generation: UUID? = nil) {
        if let generation, generation != requestWaitingGeneration { return }
        requestWaitingGeneration = UUID()
        requestWaitingTask?.cancel()
        requestWaitingTask = nil
        requestDeadlineTask?.cancel()
        requestDeadlineTask = nil
        activeRequestID = nil
        activeRequestGeneration = nil
        activeRequestPolicy = nil
        activeStreamProgress = nil
        waitingStartedAt = nil
        state.requestWaitingNotice = false
    }

    /// The UI watchdog is deliberately independent of transport cancellation.
    /// It restores the foreground state first, then records the request's
    /// terminal timeout so a non-cooperative transport cannot keep the screen
    /// stuck in `submitting`.
    private func timeOutRequest(generation: UUID) async {
        guard generation == requestWaitingGeneration,
              (state.phase == .submitting || state.isGeneratingUnderstanding) else { return }
        let sessionID = state.session?.id
        let requestID = activeRequestID
        if let requestID { markUsageRequestEnded(requestID) }
        let isUnderstanding = state.isGeneratingUnderstanding
        requestTask?.cancel()
        understandingGenerationTask?.cancel()
        if isUnderstanding {
            state.isGeneratingUnderstanding = false
            state.understandingGenerationError = "整理理解等待超时，原交流仍保留，可以重试。"
        } else {
            state.phase = .failed("回应等待超时，已停止等待，可以重试。")
        }
        // This method is running on the deadline task itself. Detach the
        // handle before clearing the waiting state so it is not cancelled
        // while finalizing the timed-out request below.
        requestDeadlineTask = nil
        endRequestWaitingNotice(generation: generation)
        let timeoutSettlementGeneration = requestWaitingGeneration
        guard let sessionID, let requestID else { return }
        do {
            try await repository.finishRequest(sessionID: sessionID, requestID: requestID, reason: .timedOut)
            recordUsageEvent(.requestFinished, sessionID: sessionID,
                attributes: ["reason": "timed_out"], requestID: requestID)
            guard state.session?.id == sessionID, requestWaitingGeneration == timeoutSettlementGeneration else { return }
            state.retryableRequest = try await repository.retryableRequest(sessionID: sessionID)
            state.retryError = nil
        } catch {
            guard state.session?.id == sessionID, requestWaitingGeneration == timeoutSettlementGeneration else { return }
            pendingRequestEnd = PendingRequestEnd(sessionID: sessionID, requestID: requestID, reason: .timedOut)
            state.canRetryRequestFinalization = true
            state.requestFinalizationError = String(describing: error)
        }
    }

    /// Configuration refresh affects future turns; each submitted turn captures
    /// the dependencies it started with and retains its own cancellation handle.
    func updateDependencies(transport: MentorTransport, promptProvider: PromptProvider,
                            requestPolicy: MentorRequestPolicy? = nil) {
        self.transport = transport
        self.promptProvider = promptProvider
        if let requestPolicy { self.requestPolicy = requestPolicy }
    }

    /// Cancels model work that started with the previous configuration. Local
    /// material and the current draft stay in place so the user can continue
    /// immediately with the newly configured model.
    func configurationDidChange() {
        dependencyGeneration = UUID()
        requestTask?.cancel()
        let sessionID = state.session?.id
        markPendingUsageRequestsEnded(sessionID: sessionID)
        if state.phase == .submitting {
            requestTask?.cancel()
            requestTask = nil
            endRequestWaitingNotice()
            state.phase = state.response == nil ? .editing : .showingResponse
        }
        requestWaitingGeneration = UUID()
        understandingGenerationTask?.cancel()
        understandingGenerationTask = nil
        understandingRequestGeneration = UUID()
        state.isGeneratingUnderstanding = false
        state.understandingGenerationError = nil
        endRequestWaitingNotice()
        pendingResponse = nil
        state.canRetryResponseSave = false
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil

        guard let sessionID else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await repository.interruptPendingRequests(sessionID: sessionID)
                recordCancelledUsageRequests(sessionID: sessionID, reason: "interrupted")
            } catch { return }
            guard state.session?.id == sessionID, !state.isViewingHistory else { return }
            state.retryableRequest = try? await repository.retryableRequest(sessionID: sessionID)
        }
    }

    func updateInputText(_ text: String) {
        guard !state.isViewingHistory else { return }
        guard let sessionID = state.session?.id, sessionTransitionID == nil,
              state.phase != .paused, state.phase != .ended, text != state.inputText else { return }
        state.inputText = text
        state.draftRevision += 1
        state.hasUnsavedDraft = true
        state.draftSaveError = nil
        draftDebounceTask?.cancel()
        let revision = state.draftRevision
        draftDebounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, !Task.isCancelled, state.session?.id == sessionID,
                  state.draftRevision == revision else { return }
            draftDebounceTask = nil
            _ = await flushDraft()
        }
    }

    private var pendingSessionHasMaterial: Bool {
        if !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !state.understandingInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return !(pendingUnderstandingText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Creates the database row exactly once, after an initially blank discuss
    /// entry has acquired material. The synthetic state keeps the existing UI
    /// lifecycle stable while the row remains absent for an abandoned entry.
    private func materializePendingSessionIfNeeded(force: Bool = false) async throws -> MentorSession? {
        guard let pending = pendingSession else { return state.session }
        guard let current = state.session, current.id == pending.id else { return nil }
        guard force || pendingSessionHasMaterial else { return nil }
        let pendingDraftRevision = state.draftRevision
        // Materialization only creates the durable session row. The current
        // in-memory text is still an unsaved draft and must go through the
        // normal revisioned writer below. Keeping the row empty here preserves
        // retry/error semantics when that write fails.
        let materialized = MentorSession(id: current.id, initialEntry: pending.entry,
            lifecycle: .draft, draftText: "", draftRevision: 0, activityAt: now())
        try await repository.createSession(materialized)
        guard state.session?.id == materialized.id else { return materialized }
        pendingSession = nil
        state.session = materialized
        // Preserve the revision accumulated while the session was still
        // in-memory so the first durable draft write is not mistaken for a
        // same-revision conflict.
        state.draftRevision = max(pendingDraftRevision, materialized.draftRevision)
        await activeAttemptEventTask?.value
        if (try? await repository.attachUsageEvent(pending.attemptID, to: materialized.id)) != nil {
            usageAttempts[pending.attemptID]?.sessionID = materialized.id
        }
        return materialized
    }

    /// Flush before navigation/background or submission. Failure leaves the buffer intact.
    @discardableResult
    func flushDraft() async -> Bool {
        draftDebounceTask?.cancel()
        draftDebounceTask = nil
        guard state.session?.id != nil else { return true }
        if pendingSession != nil, !state.hasUnsavedDraft {
            return true
        }
        do {
            // A response transaction may have finished just as Return or
            // Finish cancelled its task. Reconcile its consumed composer
            // before suspension tries to persist an obsolete snapshot.
            if let pending = pendingResponse, let draft = pending.consumedDraft,
               state.session?.id == pending.sessionID, state.draftRevision == draft.revision,
               state.inputText == draft.text,
               try await repository.requestOutcome(sessionID: pending.sessionID, requestID: pending.requestID) == .succeeded,
               let session = try await repository.session(id: pending.sessionID) {
                applyConsumedDraft(pending, session: session)
            }
            guard let materialized = try await materializePendingSessionIfNeeded() else {
                return pendingSession == nil
            }
            guard state.session?.id == materialized.id else { return false }
        } catch {
            state.draftSaveError = "草稿尚未保存，请重试。"
            return false
        }
        guard let sessionID = state.session?.id else { return true }
        // A legacy root is displayed through a read-only synthetic session
        // until the user explicitly continues it; there is no Mentor draft row
        // to flush in that state.
        if state.session?.originLegacyRootID == sessionID { return true }
        while state.hasUnsavedDraft, state.session?.id == sessionID {
            guard !Task.isCancelled else { return false }
            let snapshot = DraftSnapshot(sessionID: sessionID, revision: state.draftRevision, text: state.inputText)
            let task: Task<Bool, Never>
            if draftWritingSnapshot == snapshot, let existing = draftWriteTask {
                task = existing
            } else {
                let previous = draftWriteTask
                state.isSavingDraft = true
                draftWritingSnapshot = snapshot
                task = Task { [weak self] in
                    _ = await previous?.value
                    guard let self else { return false }
                    defer {
                        if draftWritingSnapshot == snapshot {
                            draftWritingSnapshot = nil
                            if state.session?.id == snapshot.sessionID { state.isSavingDraft = false }
                        }
                    }
                    do {
                        try await repository.saveDraft(sessionID: snapshot.sessionID, revision: snapshot.revision, text: snapshot.text)
                        if state.session?.id == snapshot.sessionID, state.draftRevision == snapshot.revision {
                            state.hasUnsavedDraft = false
                            state.draftSaveError = nil
                        }
                        return true
                    } catch {
                        if state.session?.id == snapshot.sessionID, state.draftRevision == snapshot.revision {
                            state.draftSaveError = "草稿尚未保存，请重试。"
                        }
                        return false
                    }
                }
                draftWriteTask = task
            }
            guard await task.value else { return false }
        }
        return !Task.isCancelled && state.session?.id == sessionID
    }

    /// Wait for both independent editing queues before leaving or backgrounding.
    @discardableResult
    func flushPendingEdits() async -> Bool {
        let sessionID = state.session?.id
        while !Task.isCancelled {
            // A queued understanding creation can materialize the same
            // in-memory session. Let that queue own creation first so two
            // async writers cannot race to insert the same session ID.
            if pendingSession != nil, pendingSessionHasMaterial,
               state.pendingUnderstandingOperations == 0 {
                do {
                    guard let materialized = try await materializePendingSessionIfNeeded(),
                          state.session?.id == materialized.id else { return false }
                } catch {
                    state.draftSaveError = "草稿尚未保存，请重试。"
                    return false
                }
            }
            guard await flushDraft(), state.session?.id == sessionID else { return false }
            let generation = understandingGeneration
            flushScheduledUnderstanding()
            await understandingTask?.value
            guard !Task.isCancelled, state.session?.id == sessionID,
                  understandingGeneration == generation, state.understandingError == nil else { return false }
            if !state.hasUnsavedDraft, !state.hasUnsavedUnderstanding,
               pendingUnderstandingText == nil, state.pendingUnderstandingOperations == 0 { return true }
        }
        return false
    }

    /// Discards only the in-memory conversation draft after the user confirms
    /// the destructive exit. The last successfully persisted draft remains the
    /// source of truth; queued writes are allowed to settle before reloading it.
    @discardableResult
    func discardUnsavedDraftAndExit(ending: Bool = false) async -> Bool {
        guard !state.isViewingHistory, sessionTransitionID == nil,
              let sessionID = state.session?.id,
              state.hasUnsavedDraft || state.draftSaveError != nil else { return false }
        if pendingSession?.id == sessionID {
            let exitPhase = usageExitPhase
            draftDebounceTask?.cancel()
            draftDebounceTask = nil
            pendingUnderstandingText = nil
            understandingDebounceTask?.cancel()
            understandingDebounceTask = nil
            state.inputText = ""
            state.draftRevision = 0
            state.hasUnsavedDraft = false
            state.draftSaveError = nil
            state.understandingInputText = ""
            state.hasUnsavedUnderstanding = false
            state.understandingError = nil
            state.phase = ending ? .ended : .paused
            recordUsageExit(phase: exitPhase, reason: "user", action: ending ? "finish" : "pause")
            return true
        }
        let transition = beginSessionTransition()
        draftDebounceTask?.cancel()
        draftDebounceTask = nil
        _ = await draftWriteTask?.value
        guard !Task.isCancelled, state.session?.id == sessionID,
              sessionTransitionID == transition else {
            endSessionTransition(transition)
            return false
        }
        do {
            guard let persisted = try await repository.session(id: sessionID) else { throw MentorFeatureError.missingSession }
            guard state.session?.id == sessionID, sessionTransitionID == transition else {
                endSessionTransition(transition)
                return false
            }
            state.session = persisted
            state.inputText = persisted.draftText
            state.draftRevision = persisted.draftRevision
            state.hasUnsavedDraft = false
            state.isSavingDraft = false
            state.draftSaveError = nil
            draftWriteTask = nil
            draftWritingSnapshot = nil
            endSessionTransition(transition)
            if ending { finish() } else { pause() }
            return true
        } catch {
            state.draftSaveError = "未保存改动仍在当前页面，请重试保存。"
            endSessionTransition(transition)
            return false
        }
    }

    private func beginSessionTransition() -> UUID {
        let id = UUID()
        sessionTransitionID = id
        state.isTransitioningSession = true
        return id
    }

    private func endSessionTransition(_ id: UUID) {
        guard sessionTransitionID == id else { return }
        sessionTransitionID = nil
        state.isTransitioningSession = false
    }

    func start(entry: String, initialText: String = "", automaticallyOpenReview: Bool = true) {
        guard !state.isDeletingSession, !state.isDeletingUnderstanding else { return }
        guard pendingResponse == nil, pendingRequestEnd == nil else { return }
        markPendingUsageRequestsEnded(sessionID: state.session?.id)
        requestTask?.cancel()
        let attemptID = beginUsageAttempt(entry: entry, hasMaterial: !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                endSessionTransition(transition)
                recordUnopenedUsageAttempt(attemptID)
            }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            await activeAttemptEventTask?.value
            let opening = await startTask(entry: entry, initialText: initialText, attemptID: attemptID,
                                          automaticallyOpenReview: automaticallyOpenReview)
            guard !Task.isCancelled else { return }
            endSessionTransition(transition)
            if let opening {
                await startReviewOpening(opening)
            }
        }
    }

    /// Opens selected material locally. The first online action remains an
    /// explicit choice on the conversation page; no key is needed to enter.
    func startCaptureSession(from captureID: UUID) async -> Bool {
        guard sessionTransitionID == nil, !state.isDeletingSession, !state.isDeletingUnderstanding,
              pendingResponse == nil, pendingRequestEnd == nil else { return false }
        let transition = beginSessionTransition()
        defer { endSessionTransition(transition) }
        markPendingUsageRequestsEnded(sessionID: state.session?.id)
        requestTask?.cancel()
        let attemptID = beginUsageAttempt(entry: "capture", hasMaterial: true)
        defer { recordUnopenedUsageAttempt(attemptID) }
        await activeAttemptEventTask?.value
        guard await flushPendingEdits(), !Task.isCancelled else { return false }
        await lessonFeedbackTask?.value
        await benefitFeedbackTask?.value
        await readingPositionTask?.value
        do {
            try Task.checkCancellation()
            try await suspendPreviousSession(destinationID: nil, destinationEntry: "capture")
            let session = try await repository.beginCaptureSession(captureID: captureID, sessionID: UUID(), at: now())
            var restored = try await restoredState(session: session)
            try Task.checkCancellation()
            resetSessionBuffers()
            restored.isTransitioningSession = true
            state = restored
            activeAttemptID = attemptID
            await attachActiveAttempt(to: session.id)
            return true
        } catch is CancellationError { return false }
        catch {
            state.actionError = "这条闪念暂时没能带入交流，原文仍保留，请重试。"
            return false
        }
    }

    private func beginUsageAttempt(entry: String, hasMaterial: Bool) -> UUID {
        let id = UUID()
        let observedEntry = MentorUsageEvent.entries.contains(entry) ? entry : "unknown"
        usageAttempts[id] = UsageAttempt(startedAt: uptime(), currentEntry: observedEntry)
        let event = MentorUsageEvent(
            id: id,
            attemptID: id,
            kind: .entryStarted,
            occurredAt: now(),
            attributes: [
                "entry": observedEntry,
                "has_material": hasMaterial ? "true" : "false",
                "content_version": catalog?.pack.version ?? "unavailable",
                "schema_version": "1.0.0"
            ]
        )
        enqueueUsageEvent(event)
        return id
    }

    /// Events survive a later start/cancel and settle in order. They contain
    /// coarse metadata only; business navigation does not depend on logging.
    private func enqueueUsageEvent(_ event: MentorUsageEvent) {
        let previous = activeAttemptEventTask
        let repository = repository
        activeAttemptEventTask = Task {
            await previous?.value
            try? await repository.recordUsageEvent(event)
        }
    }

    func flushUsageEvents() async {
        await presentationTask?.value
        await activeAttemptEventTask?.value
    }

    private func attachActiveAttempt(to sessionID: UUID) async {
        guard let attemptID = activeAttemptID else { return }
        await activeAttemptEventTask?.value
        do {
            try await repository.attachUsageEvent(attemptID, to: sessionID)
            usageAttempts[attemptID]?.sessionID = sessionID
        } catch { /* A read-only legacy root has no Mentor row to attach. */ }
    }

    private func restoreUsagePath(attemptID: UUID, from restored: MentorFeatureState) {
        if restored.lesson != nil, restored.response == nil {
            usageAttempts[attemptID]?.currentEntry = "listen"
        } else if restored.session?.initialEntry == "listen", restored.timeline.contains(where: { $0.kind == .user }) {
            usageAttempts[attemptID]?.currentEntry = "discuss"
        } else if let entry = restored.session?.initialEntry {
            usageAttempts[attemptID]?.currentEntry = entry
        }
    }

    private func recordUsageEvent(_ kind: MentorUsageEventKind, sessionID: UUID? = nil,
                                  attributes: [String: String] = [:], attemptID explicitAttempt: UUID? = nil,
                                  requestID: UUID? = nil, occurredAt: Date? = nil, observedUptime: TimeInterval? = nil) {
        let request = requestID.flatMap { usageRequests[$0] }
        if kind == .requestFinished, request == nil { return }
        guard let attemptID = request?.attemptID ?? explicitAttempt ?? activeAttemptID,
              let attempt = usageAttempts[attemptID] else { return }
        var metadata = attributes
        let switchedEntry: String?
        if kind == .contentPresented, metadata["content_kind"] == "lesson", metadata["presentation"] == "new",
           ["discuss", "recall", "capture", "legacy-nudge", "legacy-nudge-selection"].contains(attempt.currentEntry) {
            switchedEntry = "listen"
        } else { switchedEntry = request?.switchedEntry }
        if let switchedEntry {
            metadata["switched_entry"] = switchedEntry
            usageAttempts[attemptID]?.currentEntry = switchedEntry
        }
        if kind == .contentPresented {
            metadata["first_content"] = attempt.hasPresentedContent ? "false" : "true"
            if !attempt.hasPresentedContent {
                metadata["duration_ms"] = usageMilliseconds(since: attempt.startedAt, until: observedUptime)
                metadata["timing_scope"] = "entry_to_content"
            }
            usageAttempts[attemptID]?.hasPresentedContent = true
        }
        if kind == .requestFinished, let requestID, let request {
            metadata["duration_ms"] = usageMilliseconds(since: request.startedAt, until: request.endedAt)
            metadata["timing_scope"] = "request"
            usageRequests.removeValue(forKey: requestID)
        }
        enqueueUsageEvent(MentorUsageEvent(attemptID: attemptID,
            sessionID: attempt.sessionID == sessionID ? sessionID : nil,
            kind: kind, occurredAt: occurredAt ?? now(), attributes: metadata))
        pruneUsageAttempts()
    }

    private func usageMilliseconds(since start: TimeInterval, until end: TimeInterval? = nil) -> String {
        let elapsed = (end ?? uptime()) - start
        guard elapsed.isFinite, elapsed >= 0 else { return "0" }
        return String(Int(min(elapsed * 1000, Double(Int.max / 2))))
    }

    private func trackUsageRequest(_ requestID: UUID, sessionID: UUID, attemptID: UUID?, startedAt: TimeInterval,
                                   switchedEntry: String? = nil) {
        guard let attemptID else { return }
        usageRequests[requestID] = UsageRequest(attemptID: attemptID, sessionID: sessionID,
            startedAt: startedAt, switchedEntry: switchedEntry)
    }

    private func recordCancelledUsageRequests(sessionID: UUID, reason: String = "cancelled") {
        let ids = usageRequests.filter { $0.value.sessionID == sessionID }.map(\.key)
        for id in ids {
            markUsageRequestEnded(id)
            recordUsageEvent(.requestFinished, sessionID: sessionID, attributes: ["reason": reason], requestID: id)
        }
    }

    private func markUsageRequestEnded(_ requestID: UUID) {
        if usageRequests[requestID]?.endedAt == nil { usageRequests[requestID]?.endedAt = uptime() }
    }

    private func markPendingUsageRequestsEnded(sessionID: UUID?) {
        guard let sessionID else { return }
        for id in usageRequests.filter({ $0.value.sessionID == sessionID }).map(\.key) {
            markUsageRequestEnded(id)
        }
    }

    private func reconcileAbandonedUsageRequest(sessionID: UUID, requestID: UUID) async {
        guard usageRequests[requestID] != nil else { return }
        // A submit write can settle after navigation already suspended its
        // session. Read the owned terminal fact on an uncancelled task instead
        // of assigning a late callback to the new attempt or guessing success.
        await Task { @MainActor in
            if let outcome = try? await repository.requestOutcome(sessionID: sessionID, requestID: requestID) {
                recordUsageEvent(.requestFinished, sessionID: sessionID,
                    attributes: ["reason": outcome.usageReason], requestID: requestID)
            } else {
                usageRequests.removeValue(forKey: requestID)
                pruneUsageAttempts()
            }
        }.value
    }

    private func recordUnopenedUsageAttempt(_ attemptID: UUID) {
        guard activeAttemptID != attemptID else { return }
        recordUsageExit(phase: "entry", reason: Task.isCancelled ? "entry_cancelled" : "entry_failed",
            attemptID: attemptID)
    }

    private func pruneUsageAttempts() {
        let pending = Set(usageRequests.values.map(\.attemptID))
        usageAttempts = usageAttempts.filter {
            $0.key == activeAttemptID || !$0.value.hasExited || $0.value.pendingOperations > 0 || pending.contains($0.key)
        }
    }

    private var usageExitPhase: String {
        if state.isViewingHistory { return "history" }
        if state.isGeneratingUnderstanding { return "understanding" }
        switch state.phase {
        case .idle: return "idle"
        case .editing: return "editing"
        case .reading: return "reading"
        case .selectingLesson: return "selecting_lesson"
        case .lessonExhausted: return "lesson_exhausted"
        case .submitting: return "submitting"
        case .showingResponse: return "showing_response"
        case .paused: return "paused"
        case .ended: return "ended"
        case .failed: return "failed"
        }
    }

    private func recordUsageExit(phase: String, reason: String, action: String? = nil,
                                 destinationEntry: String? = nil, attemptID: UUID? = nil) {
        guard let id = attemptID ?? activeAttemptID, let attempt = usageAttempts[id], !attempt.hasExited else { return }
        usageAttempts[id]?.hasExited = true
        var attributes = ["exit_phase": phase, "reason": reason,
            "duration_ms": usageMilliseconds(since: attempt.startedAt), "timing_scope": "attempt"]
        if let action { attributes["exit_action"] = action }
        if let destinationEntry {
            attributes["switched_entry"] = MentorUsageEvent.entries.contains(destinationEntry) ? destinationEntry : "unknown"
        }
        recordUsageEvent(.sessionLeft, sessionID: attempt.sessionID, attributes: attributes, attemptID: id)
    }

    func makeLessonPreferencesStore() -> MentorLessonPreferencesStore { MentorLessonPreferencesStore(repository: repository) }

    func makeHistoryStore() -> MentorHistoryStore {
        MentorHistoryStore(repository: repository, legacyNudgeAdapter: legacyNudgeAdapter)
    }

    /// Resolves references against the loaded session snapshot. This is a read-only
    /// operation so opening a source from history cannot create a receipt or alter
    /// the lifecycle of the viewed session.
    func sourceDetails(for references: [MentorSourceReference]) async -> [MentorSourceDetail] {
        guard let session = state.session else {
            return references.map { MentorSourceDetail(id: $0, kind: "unknown", title: "来源详情", content: nil,
                sourceVersion: nil, contentHash: nil, externalLinks: [], status: .unavailable("当前没有打开的交流。")) }
        }
        let timeline = state.timeline
        let understandings = state.understandings
        let legacyHistory = state.legacyChain
        do {
            let links = try await repository.sourceLinks(sessionID: session.id)
            let legacyIDs = Set(references.compactMap { reference -> UUID? in
                let parts = reference.value.split(separator: ":", maxSplits: 1)
                guard parts.first == "legacy-nudge", parts.count == 2 else { return nil }
                return UUID(uuidString: String(parts[1]))
            })
            let legacyRounds = try await legacyNudgeAdapter?.sourceRounds(sessionID: session.id,
                roundIDs: legacyIDs, historyRootID: legacyHistory?.rootID) ?? []
            try Task.checkCancellation()
            guard state.session?.id == session.id else { throw MentorFeatureError.missingSession }
            return MentorSourceResolver().resolve(references, sessionID: session.id,
                timeline: timeline, understandings: understandings, links: links,
                legacyRounds: legacyRounds, legacyHistory: legacyHistory)
        } catch {
            return references.map { MentorSourceDetail(id: $0, kind: "unknown", title: "来源详情", content: nil,
                sourceVersion: nil, contentHash: nil, externalLinks: [], status: .unavailable("来源详情暂时无法读取。")) }
        }
    }

    func understandingSourceReferences() async -> [UUID: [MentorSourceReference]] {
        guard let session = state.session else { return [:] }
        let noteIDs = Set(state.understandings.map(\.id))
        guard !noteIDs.isEmpty else { return [:] }
        guard let links = try? await repository.sourceLinks(sessionID: session.id) else { return [:] }
        var result: [UUID: [MentorSourceReference]] = [:]
        for link in links where link.ownerKind == .understanding && noteIDs.contains(link.ownerID) {
            let raw: String
            if link.sourceKind.caseInsensitiveCompare("lesson") == .orderedSame {
                raw = link.sourceID.contains("@") ? "lesson:\(link.sourceID)" :
                    link.sourceVersion.map { "lesson:\(link.sourceID)@\($0)" } ?? ""
            } else {
                raw = "\(link.sourceKind):\(link.sourceID)"
            }
            guard let reference = try? MentorSourceReference(raw),
                  result[link.ownerID, default: []].contains(reference) == false else { continue }
            result[link.ownerID, default: []].append(reference)
        }
        guard !Task.isCancelled, state.session?.id == session.id else { return [:] }
        return result
    }

    func loadRecentSessions(limit: Int = 3) {
        historyTask?.cancel()
        let generation = UUID()
        historyGeneration = generation
        state.isLoadingHistory = true
        state.historyError = nil
        historyTask = Task { [weak self] in
            guard let self else { return }
            do {
                var nextPager = MentorHistoryPager()
                let page = try await nextPager.nextPage(repository: repository, legacy: legacyNudgeAdapter, limit: limit)
                let mentorUnfinished = try await repository.latestUnfinishedSession()
                let legacyUnfinished: MentorSessionSummary?
                if let legacyNudgeAdapter {
                    legacyUnfinished = try await legacyNudgeAdapter.recentSummaries(limit: 1, unfinishedOnly: true).sessions.first
                } else {
                    legacyUnfinished = nil
                }
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.latestUnfinishedSession = [mentorUnfinished, legacyUnfinished].compactMap { $0 }
                    .sorted { MentorHistoryPager.isNewer($0, than: $1) }.first
                state.recentSessions = page
                historyPager = nextPager
                state.hasMoreRecentSessions = nextPager.hasMore
            } catch {
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.historyError = String(describing: error)
            }
            state.isLoadingHistory = false
        }
    }

    func loadMoreRecentSessions(limit: Int = 20) {
        guard !state.isLoadingHistory, state.hasMoreRecentSessions else { return }
        let generation = historyGeneration
        state.isLoadingHistory = true
        state.historyError = nil
        historyTask = Task { [weak self] in
            guard let self else { return }
            do {
                var nextPager = historyPager
                let page = try await nextPager.nextPage(repository: repository, legacy: legacyNudgeAdapter, limit: limit)
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.recentSessions += page
                historyPager = nextPager
                state.hasMoreRecentSessions = nextPager.hasMore
            } catch {
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.historyError = String(describing: error)
            }
            state.isLoadingHistory = false
        }
    }

    func continueSession(id: UUID) { openSession(id: id, resuming: true) }

    /// Starts a new Mentor session that borrows exactly one preserved legacy
    /// round. This is the explicit fallback for a damaged old lineage.
    func startIndependentLegacySession(fromRoundID roundID: UUID) {
        guard state.isViewingHistory, state.legacyChain != nil,
              sessionTransitionID == nil, let legacyNudgeAdapter else { return }
        guard state.legacyChain?.rounds.contains(where: { $0.id == roundID }) == true else { return }
        let attemptID = beginUsageAttempt(entry: "legacy-nudge-selection", hasMaterial: true)
        let transition = beginSessionTransition()
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                endSessionTransition(transition)
                recordUnopenedUsageAttempt(attemptID)
            }
            do {
                await activeAttemptEventTask?.value
                await benefitFeedbackTask?.value
                await readingPositionTask?.value
                try Task.checkCancellation()
                let session = try await legacyNudgeAdapter.startIndependentSession(fromRoundID: roundID, at: now())
                var restored = try await restoredState(session: session)
                try Task.checkCancellation()
                try await suspendPreviousSession(destinationID: session.id, destinationEntry: "legacy-nudge-selection")
                resetSessionBuffers()
                activeAttemptID = attemptID
                await attachActiveAttempt(to: session.id)
                restored.session = session
                restored.isViewingHistory = false
                restored.legacyChain = nil
                restored.phase = restored.response != nil ? .showingResponse : .editing
                state = restored
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state.actionError = "这条旧记录暂时无法开启新交流，请稍后重试。"
            }
        }
    }

    func viewSession(id: UUID) {
        guard state.phase != .submitting || state.session?.id != id else { return }
        openSession(id: id, resuming: false)
    }

    private func openSession(id: UUID, resuming: Bool) {
        guard !state.isDeletingSession, !state.isDeletingUnderstanding else { return }
        guard pendingResponse == nil, pendingRequestEnd == nil else { return }
        markPendingUsageRequestsEnded(sessionID: state.session?.id)
        requestTask?.cancel()
        let attemptID = beginUsageAttempt(entry: resuming ? "continue" : "history", hasMaterial: true)
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                endSessionTransition(transition)
                recordUnopenedUsageAttempt(attemptID)
            }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            do {
                await activeAttemptEventTask?.value
                await benefitFeedbackTask?.value
                await self.readingPositionTask?.value
                try Task.checkCancellation()
                guard let session = try await self.repository.session(id: id) else {
                    guard let legacyNudgeAdapter,
                          let chain = try await legacyNudgeAdapter.chain(rootID: id) else {
                        throw MentorFeatureError.missingSession
                    }
                    if resuming {
                        if !chain.canContinueAutomatically {
                            let synthetic = MentorSession(id: id, initialEntry: "legacy-nudge",
                                lifecycle: .ended, draftText: "", draftRevision: 0,
                                activityAt: chain.activityAt, originLegacyRootID: id)
                            let items = try await legacyNudgeAdapter.projectedItems(rootID: id)
                            try await suspendPreviousSession(destinationID: id, destinationEntry: "continue")
                            resetSessionBuffers()
                            activeAttemptID = attemptID
                            await attachActiveAttempt(to: synthetic.id)
                            self.state = MentorFeatureState(phase: .ended, session: synthetic,
                                isViewingHistory: true, timeline: items, legacyChain: chain)
                            return
                        }
                        let wrapped = try await legacyNudgeAdapter.continueChain(rootID: id, at: now())
                        var restored = try await self.restoredState(session: wrapped)
                        try Task.checkCancellation()
                        try await suspendPreviousSession(destinationID: wrapped.id, destinationEntry: "continue")
                        restored.session = wrapped
                        restored.isViewingHistory = false
                        restored.legacyChain = nil
                        restored.phase = restored.response != nil ? .showingResponse : .editing
                        resetSessionBuffers()
                        activeAttemptID = attemptID
                        await attachActiveAttempt(to: wrapped.id)
                        self.state = restored
                    } else {
                        let synthetic = MentorSession(id: id, initialEntry: "legacy-nudge",
                            lifecycle: .ended, draftText: "", draftRevision: 0,
                            activityAt: chain.activityAt, originLegacyRootID: id)
                        let items = try await legacyNudgeAdapter.projectedItems(rootID: id)
                        try await suspendPreviousSession(destinationID: id, destinationEntry: "history")
                        resetSessionBuffers()
                        activeAttemptID = attemptID
                        await attachActiveAttempt(to: synthetic.id)
                        self.state = MentorFeatureState(phase: .ended, session: synthetic,
                            isViewingHistory: true, timeline: items, legacyChain: chain)
                    }
                    return
                }
                try Task.checkCancellation()
                var restored = try await self.restoredState(session: session)
                try Task.checkCancellation()
                try await suspendPreviousSession(destinationID: id, destinationEntry: resuming ? "continue" : "history")
                if resuming, session.lifecycle != .active { try await self.repository.resumeSession(id: id) }
                try Task.checkCancellation()
                guard let current = try await self.repository.session(id: id) else { throw MentorFeatureError.missingSession }
                try Task.checkCancellation()
                restored.session = current
                restored.isViewingHistory = !resuming
                restored.phase = restored.response != nil ? .showingResponse :
                    (restored.lesson == nil ? .editing : .reading)
                if !resuming, current.lifecycle == .ended { restored.phase = .ended }
                if !resuming, current.lifecycle == .paused { restored.phase = .paused }
                resetSessionBuffers()
                activeAttemptID = attemptID
                restoreUsagePath(attemptID: attemptID, from: restored)
                await attachActiveAttempt(to: current.id)
                self.state = restored
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    /// Only a confirmed user action in the history detail may delete its owned graph.
    @discardableResult
    func deleteViewedSession() async -> Bool {
        guard state.isViewingHistory, sessionTransitionID == nil, let id = state.session?.id else { return false }
        let transition = beginSessionTransition()
        state.isDeletingSession = true
        defer {
            state.isDeletingSession = false
            endSessionTransition(transition)
        }
        state.deletionError = nil
        historyTask?.cancel()
        historyGeneration = UUID()
        state.isLoadingHistory = false
        do {
            if let rootID = state.session?.originLegacyRootID, let legacyNudgeAdapter {
                if rootID == id {
                    _ = try await legacyNudgeAdapter.deleteLegacyChain(rootID: rootID)
                } else {
                    _ = try await legacyNudgeAdapter.deleteWrapper(sessionID: id)
                }
            } else {
                try await repository.deleteSession(id: id)
            }
            // A committed deletion remains authoritative even if the caller was cancelled.
            if state.session?.id == id {
                resetSessionBuffers()
                state = MentorFeatureState()
            }
            onOwnedDataDeleted?()
            loadRecentSessions()
            return true
        } catch {
            if state.session?.id == id { state.deletionError = String(describing: error) }
            return false
        }
    }

    /// Explicit confirmation in history manages a whole version group.
    @discardableResult
    func deleteViewedUnderstanding(groupID: UUID) async -> Bool {
        guard state.isViewingHistory, sessionTransitionID == nil,
              let session = state.session,
              state.understandings.contains(where: { $0.groupID == groupID }) else { return false }
        let transition = beginSessionTransition()
        state.isDeletingUnderstanding = true
        state.understandingDeletionError = nil
        defer {
            state.isDeletingUnderstanding = false
            endSessionTransition(transition)
        }
        historyTask?.cancel()
        historyGeneration = UUID()
        state.isLoadingHistory = false
        do {
            try await repository.deleteUnderstandingGroup(sessionID: session.id, groupID: groupID)
        } catch {
            state.understandingDeletionError = "暂时没有删除成功，内容仍保留。请重试。"
            return false
        }
        // Clear all potentially derived presentation copies immediately after commit.
        // Reconciliation has its own task so cancellation of the presenting view
        // cannot leave the pre-deletion response or epoch in memory.
        resetSessionBuffers()
        state = MentorFeatureState(phase: .editing, session: session, isViewingHistory: true,
            isDeletingUnderstanding: true, inputText: session.draftText, draftRevision: session.draftRevision,
            isTransitioningSession: true)
        await Task { @MainActor in
            do {
                guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
                var restored = try await restoredState(session: current)
                restored.isViewingHistory = true
                restored.isTransitioningSession = true
                restored.isDeletingUnderstanding = true
                switch current.lifecycle {
                case .ended: restored.phase = .ended
                case .paused: restored.phase = .paused
                default: restored.phase = restored.response == nil ? .editing : .showingResponse
                }
                state = restored
            } catch {
                state.understandingDeletionError = "理解已删除，但详情暂时无法刷新。请返回后重新打开这次交流。"
            }
            loadRecentSessions()
        }.value
        return true
    }

    func canCorrectUserItem(_ itemID: UUID) -> Bool {
        !state.isViewingHistory && sessionTransitionID == nil && !state.isConfirmingUnderstanding &&
        state.phase != .paused && state.phase != .ended && state.phase != .selectingLesson &&
        state.timeline.contains { $0.id == itemID && $0.kind == .user } &&
        !state.timeline.contains { $0.supersedesItemID == itemID }
    }

    /// A local correction preserves both versions and invalidates work based on
    /// old evidence. It never submits the correction to the model.
    @discardableResult
    func correctUserItem(_ itemID: UUID, text: String) async -> Bool {
        guard canCorrectUserItem(itemID), let sessionID = state.session?.id else { return false }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state.correctionError = "更正后的原话不能为空。"
            return false
        }
        state.correctionError = nil
        let transition = beginSessionTransition()
        defer { endSessionTransition(transition) }
        let cancelledRequestID = activeRequestID
        markPendingUsageRequestsEnded(sessionID: sessionID)
        requestTask?.cancel()
        understandingGenerationTask?.cancel()
        understandingRequestGeneration = UUID()
        state.isGeneratingUnderstanding = false
        endRequestWaitingNotice()
        do {
            guard await flushPendingEdits() else { throw MentorFeatureError.draftSaveFailed }
            await presentationTask?.value
            guard !Task.isCancelled, state.session?.id == sessionID,
                  sessionTransitionID == transition,
                  var current = try await repository.session(id: sessionID) else { throw MentorFeatureError.missingSession }
            let items = try await repository.items(sessionID: sessionID)
            try Task.checkCancellation()
            let corrected = try await repository.correctUserItem(sessionID: sessionID, itemID: itemID,
                commandID: UUID(), expectedRevision: current.semanticRevision, text: text)
            // The returned item proves the whole transaction committed. Publish
            // it without a fallible post-commit reload or a second append.
            recordCancelledUsageRequests(sessionID: sessionID)
            guard state.session?.id == sessionID else { return true }
            current.semanticRevision += 1
            current.requestEpoch += 1
            current.activityAt = now()
            state.session = current
            state.timeline = items + [corrected]
            state.response = nil
            state.responseItemID = nil
            state.acknowledgedResponseItemID = nil
            state.retryableRequest = nil
            state.retryError = nil
            state.understandingGenerationError = nil
            state.generatedUnderstandingID = nil
            pendingResponse = nil
            pendingRequestEnd = nil
            state.canRetryResponseSave = false
            state.canRetryRequestFinalization = false
            state.requestFinalizationError = nil
            state.phase = state.lesson == nil ? .editing : .reading
            return true
        } catch {
            if let cancelledRequestID {
                let end = PendingRequestEnd(sessionID: sessionID, requestID: cancelledRequestID, reason: .cancelled)
                pendingRequestEnd = end
                await persistRequestEnd(end)
            }
            guard state.session?.id == sessionID else { return false }
            if state.phase == .submitting { state.phase = .failed("更正尚未保存") }
            state.correctionError = "更正尚未保存，原文仍保留。可以重试或取消。"
            return false
        }
    }

    /// Reopens the material budget only after the user explicitly chooses to
    /// continue. This local command preserves the draft and sends no model request.
    func continueRecall() async -> Bool {
        guard canContinueRecall, let session = state.session else { return false }
        let transition = beginSessionTransition()
        defer { endSessionTransition(transition) }
        state.actionError = nil
        guard await flushPendingEdits(), !Task.isCancelled,
              sessionTransitionID == transition, state.session?.id == session.id else { return false }
        let command = pendingRecallContinuation.flatMap {
            $0.sessionID == session.id && $0.epoch == session.requestEpoch ? $0 : nil
        }
            ?? (sessionID: session.id, commandID: UUID(), epoch: session.requestEpoch)
        pendingRecallContinuation = command
        do {
            try await repository.continueRecall(sessionID: command.sessionID,
                commandID: command.commandID, expectedEpoch: command.epoch)
            guard let current = try await repository.session(id: session.id) else {
                throw MentorFeatureError.missingSession
            }
            guard !Task.isCancelled, sessionTransitionID == transition,
                  state.session?.id == session.id else { return false }
            state.session = current
            pendingRecallContinuation = nil
            return true
        } catch {
            guard !Task.isCancelled, sessionTransitionID == transition,
                  state.session?.id == session.id else { return false }
            state.actionError = "暂时没能继续回忆，已有交流和输入仍保留。请重试。"
            return false
        }
    }

    func submit(intent: String = "reply", text: String? = nil) {
        guard !state.isViewingHistory else { return }
        guard ["reply", "explain", "finish", "another_lesson"].contains(intent) else {
            state.actionError = "这个操作暂不可用。可以继续交流，或自己写一句理解。"
            return
        }
        state.actionError = nil
        if intent == "finish" { finish(); return }
        if intent == "another_lesson" { selectAnotherLesson(); return }
        guard state.materialSelection == nil else { return }
        guard sessionTransitionID == nil, let session = state.session, [.editing, .showingResponse, .reading].contains(state.phase) else { return }
        if state.phase == .showingResponse, state.acknowledgedResponseItemID != state.responseItemID { return }
        // Teaching buttons are intent only; never resubmit the draft as evidence.
        let value = text ?? (intent == "reply" ? state.inputText : "")
        if intent == "reply" || text != nil { updateInputText(value) }
        let startedAt = ContinuousClock().now
        state.phase = .submitting
        requestTask?.cancel()
        let waitingGeneration = beginRequestWaitingNotice()
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        let generation = dependencyGeneration
        requestTask = Task { [weak self] in
            defer { self?.endRequestWaitingNotice(generation: waitingGeneration) }
            await self?.submitTask(session: session, intent: intent, text: value,
                transport: transport, prompt: prompt, startedAt: startedAt, generation: generation,
                operationGeneration: waitingGeneration)
        }
    }

    func toggleMaterialFragment(_ id: UUID) {
        guard var selection = state.materialSelection else { return }
        if selection.selectedIDs.contains(id) { selection.selectedIDs.remove(id) }
        else if selection.candidates.contains(where: { $0.id == id }) { selection.selectedIDs.insert(id) }
        selection.error = nil
        state.materialSelection = selection
    }

    func submitMaterialSelection() {
        guard let selection = state.materialSelection,
              let pending = pendingMaterialSubmission,
              state.session?.id == pending.sessionID else { return }
        let fragments = selection.selectedFragments
        guard !fragments.isEmpty else {
            var updated = selection
            updated.error = "至少选择一条片段后再发送。"
            state.materialSelection = updated
            return
        }
        if !pending.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !fragments.contains(where: { $0.sourceID == pending.userItemID && $0.field == .userText }) {
            var updated = selection
            updated.error = "请至少选一段本轮输入，让导师知道这次要回应什么。也可以取消后改写问题。"
            state.materialSelection = updated
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture") {
            state.materialSelection = nil
            pendingMaterialSubmission = nil
            state.phase = .editing
            state.actionError = nil
            return
        }
        state.materialSelection = nil
        state.phase = .submitting
        state.actionError = nil
        requestTask?.cancel()
        let waitingGeneration = beginRequestWaitingNotice()
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        let generation = dependencyGeneration
        let startedAt = ContinuousClock().now
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endRequestWaitingNotice(generation: waitingGeneration) }
            await submitTask(session: MentorSession(id: pending.sessionID, initialEntry: "", lifecycle: .active,
                draftText: "", draftRevision: 0, activityAt: now()), intent: pending.intent, text: pending.text,
                transport: transport, prompt: prompt, startedAt: startedAt, generation: generation,
                operationGeneration: waitingGeneration, selectedMaterialFragments: fragments)
        }
    }

    func cancelMaterialSelection() {
        guard let pending = pendingMaterialSubmission else { return }
        state.materialSelection = nil
        pendingMaterialSubmission = nil
        state.phase = pending.restorePhase
        state.actionError = "本轮未发送新的片段，原话仍保留。"
    }

    #if DEBUG
    func debugPresentMaterialSelectionForUITest() {
        guard ProcessInfo.processInfo.arguments.contains("--mentor-material-selection-fixture"),
              let sessionID = state.session?.id else { return }
        Task { [weak self] in
            guard let self else { return }
            let userID = UUID()
            let candidate = MentorMaterialFragment(id: UUID(), sourceID: userID,
                label: "本轮输入 · 片段 1/1", text: state.inputText.isEmpty ? "请解释选中的老师原话。" : state.inputText)
            let teacher = MentorMaterialFragment(id: UUID(), sourceID: UUID(), label: "老师回应第 2 条 · 正文 · 片段 1/1",
                text: "完成是动作结束，有效是目标结果发生变化。" + String(repeating: "可以只比较一个实际结果。", count: 20) + "本段全文到此结束。", field: .assistantBody)
            let candidates = [candidate, teacher]
            state.materialSelection = MentorMaterialSelectionState(characterCount: 30_000, limit: 24_000,
                candidates: candidates, currentUserSourceID: userID)
            pendingMaterialSubmission = PendingMaterialSubmission(sessionID: sessionID, intent: "reply", text: state.inputText,
                restorePhase: .editing, userItemID: userID)
        }
    }
    #endif

    /// Generates an auditable, source-backed understanding draft. The result is
    /// never treated as confirmed until the user saves it from the editor.
    func generateUnderstanding() {
        guard !state.isViewingHistory, sessionTransitionID == nil,
              !state.isGeneratingUnderstanding,
              let session = state.session,
              state.phase == .showingResponse,
              state.response?.availableSuggestedActions.contains(.draftUnderstanding) == true,
              state.responseItemID == state.acknowledgedResponseItemID else { return }
        guard acquireForegroundAIActivity() else {
            state.understandingGenerationError = "今日整理正在处理中，完成后再试。"
            return
        }
        let policy = requestPolicy
        let startedAt = ContinuousClock().now
        state.isGeneratingUnderstanding = true
        state.understandingGenerationError = nil
        state.generatedUnderstandingID = nil
        understandingGenerationTask?.cancel()
        let waitingGeneration = beginRequestWaitingNotice()
        let generation = UUID()
        understandingRequestGeneration = generation
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorDraftUnderstanding, mode: .standard)
        let dependencyGeneration = self.dependencyGeneration
        let requestAttemptID = activeAttemptID
        let requestStartedAt = waitingStartedAt ?? uptime()
        if let requestAttemptID { usageAttempts[requestAttemptID]?.pendingOperations += 1 }
        understandingGenerationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                releaseForegroundAIActivity()
                endRequestWaitingNotice(generation: waitingGeneration)
                if understandingRequestGeneration == generation { state.isGeneratingUnderstanding = false }
                if let requestAttemptID { usageAttempts[requestAttemptID]?.pendingOperations -= 1 }
                pruneUsageAttempts()
            }
            var requestID: UUID?
            var requestCompleted = false
            do {
                guard await flushPendingEdits(), !Task.isCancelled else { return }
                guard self.dependencyGeneration == dependencyGeneration else { throw CancellationError() }
                guard state.session?.id == session.id, !state.isViewingHistory else { return }
                guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
                let items = try await repository.items(sessionID: current.id)
                let built = try MentorContextBuilder().build(session: current, items: items,
                    intent: "draft_understanding", responseIntent: .discuss,
                    currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [],
                    suppressCurrentUserAnchor: true)
                guard !built.validation.userExpressionSources.isEmpty else { throw MentorResponseError.noUserExpression }
                requestID = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: current.id,
                    text: nil, intent: "draft_understanding", contextSnapshotJSON: "{}"))
                guard let requestID else { throw MentorFeatureError.missingSession }
                trackUsageRequest(requestID, sessionID: current.id, attemptID: requestAttemptID, startedAt: requestStartedAt)
                activeRequestID = requestID
                activeRequestGeneration = waitingGeneration
                let progress = makeStreamProgress(generation: waitingGeneration, startedAt: startedAt, field: "text")
                armRequestDeadline(generation: waitingGeneration, policy: policy, startedAt: startedAt)
                var request = LLMRequest(prompt: prompt, inputSummary: built.json,
                    sourceRecordIDs: built.payload.sources.map { $0.ref.value }, contextVersion: 1,
                    contextRecordIDs: built.payload.sources.map { $0.ref.value })
                request.mentorExecutionPolicy = policy
                request.mentorStartedAt = startedAt
                request.mentorStreamProgress = progress
                request.mentorAuditToken = LLMRequest.MentorAuditToken(sessionID: current.id,
                    requestID: requestID, requestEpoch: current.requestEpoch,
                    semanticRevision: current.semanticRevision)
                try await repository.prepareRequestContext(token: request.mentorAuditToken!, json: built.json)
                let data = try await transport.complete(request)
                markUsageRequestEnded(requestID)
                try Task.checkCancellation()
                guard self.dependencyGeneration == dependencyGeneration,
                      requestWaitingGeneration == waitingGeneration else { throw CancellationError() }
                let draft = try MentorResponseParser().parseUnderstanding(data, context: built.validation)
                let saved = try await repository.beginAIUnderstanding(sessionID: current.id, draftID: UUID(),
                    text: draft.text, sourceRefs: draft.sourceRefs)
                try await repository.completeUnderstandingRequest(sessionID: current.id, requestID: requestID)
                recordUsageEvent(.requestFinished, sessionID: current.id,
                                 attributes: ["reason": "succeeded"], requestID: requestID)
                requestCompleted = true
                guard !Task.isCancelled, understandingRequestGeneration == generation,
                      state.session?.id == current.id else { return }
                state.understandings.append(saved)
                state.understanding = saved
                state.understandingInputText = saved.text
                state.hasUnsavedUnderstanding = false
                state.understandingError = nil
                state.generatedUnderstandingID = saved.id
                state.streamingPreview = ""
            } catch is CancellationError {
                if let requestID { markUsageRequestEnded(requestID) }
                guard requestWaitingGeneration == waitingGeneration else {
                    if let requestID { await reconcileAbandonedUsageRequest(sessionID: session.id, requestID: requestID) }
                    return
                }
                if let requestID, !requestCompleted {
                    let end = PendingRequestEnd(sessionID: session.id, requestID: requestID, reason: .cancelled)
                    pendingRequestEnd = end
                    await persistRequestEnd(end)
                }
            } catch {
                if let requestID { markUsageRequestEnded(requestID) }
                guard requestWaitingGeneration == waitingGeneration else {
                    if let requestID { await reconcileAbandonedUsageRequest(sessionID: session.id, requestID: requestID) }
                    return
                }
                if let requestID, !requestCompleted {
                    let reason: MentorRequestEndReason
                    switch error {
                    case MentorRequestExecutionError.timedOut: reason = .timedOut
                    case MentorRequestExecutionError.cancelled: reason = .cancelled
                    default: reason = .failed
                    }
                    let end = PendingRequestEnd(sessionID: session.id, requestID: requestID, reason: reason)
                    pendingRequestEnd = end
                    await persistRequestEnd(end)
                }
                guard understandingRequestGeneration == generation, state.session?.id == session.id else { return }
                state.understandingGenerationError = (error as? LLMClientError)?.userFacingMessage
                    ?? "整理理解暂时没有完成，原交流仍保留，可以重试。"
            }
        }
    }

    func consumeGeneratedUnderstandingEditor() {
        state.generatedUnderstandingID = nil
    }

    /// Explicit network retry; local response-save retries never use this path.
    func retryLastRequest() {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, let session = state.session, pendingResponse == nil, pendingRequestEnd == nil,
              state.phase != .submitting, state.phase != .selectingLesson else { return }
        let startedAt = ContinuousClock().now
        let previousPhase = state.phase
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        let generation = dependencyGeneration
        state.phase = .submitting
        state.retryError = nil
        requestTask?.cancel()
        let waitingGeneration = beginRequestWaitingNotice()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endRequestWaitingNotice(generation: waitingGeneration) }
            do {
                let candidate = try await repository.retryableRequest(sessionID: session.id)
                try Task.checkCancellation()
                guard let candidate else {
                    state.retryableRequest = nil
                    state.retryError = "当前没有可重试的轮次。"
                    state.phase = previousPhase
                    return
                }
                guard ["reply", "explain"].contains(candidate.intent) else {
                    state.retryError = "这次操作暂不能重试，请继续交流。"
                    state.phase = previousPhase
                    return
                }
                await submitTask(session: session, intent: candidate.intent, text: candidate.text ?? "",
                    transport: transport, prompt: prompt, startedAt: startedAt, retry: candidate,
                    generation: generation, operationGeneration: waitingGeneration)
            } catch {
                guard !Task.isCancelled else { return }
                state.retryError = String(describing: error)
                state.phase = previousPhase
            }
        }
    }

    /// Reading and changing lessons are local actions even when a draft exists.
    func selectAnotherLesson() {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, let session = state.session,
              [.editing, .reading, .showingResponse, .lessonExhausted].contains(state.phase) else { return }
        guard let catalog else {
            state.lessonError = "教材暂不可用，请稍后重试。"
            return
        }
        let previousPhase = state.phase
        let receipt = presentationTask
        let feedback = lessonFeedbackTask
        let position = readingPositionTask
        state.phase = .selectingLesson
        state.lessonError = nil
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                await receipt?.value
                await feedback?.value
                await position?.value
                try Task.checkCancellation()
                guard state.lessonFeedbackError == nil else {
                    state.phase = previousPhase
                    return
                }
                guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
                try Task.checkCancellation()
                let lesson = try await repository.selectNextLesson(sessionID: current.id, itemID: UUID(),
                    expectedEpoch: current.requestEpoch, catalog: catalog, at: now(), timeZone: timeZone)
                let items = try await repository.items(sessionID: current.id)
                try Task.checkCancellation()
                guard state.session?.id == current.id else { return }
                state.timeline = items
                state.lesson = lesson
                state.lessonFeedbackNotice = nil
                state.readingPositionError = nil
                state.pendingReadingPositionSaves = 0
                state.phase = lesson == nil ? .lessonExhausted : .reading
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                state.lessonError = String(describing: error)
                state.phase = previousPhase
            }
        }
    }

    /// Feedback records a preference without replacing the current readable snapshot.
    /// A subsequent change of lesson waits for this local write to finish.
    func recordLessonFeedback(_ kind: MentorLessonFeedback) {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, let session = state.session, let lesson = state.lesson,
              [.reading, .showingResponse, .paused, .ended].contains(state.phase) else { return }
        saveLessonFeedback(sessionID: session.id, itemID: lesson.id, kind: kind)
    }

    /// Keeps the private explanation in the session-owned feedback table. The
    /// usage event below contains only the selected enum, never this note.
    func updateBenefitFeedbackNote(_ note: String) {
        guard !state.isViewingHistory, state.session != nil,
              sessionTransitionID == nil else { return }
        state.benefitFeedbackNote = String(note.prefix(2_000))
        state.benefitFeedbackError = nil
    }

    func recordBenefitFeedback(_ kind: MentorBenefitFeedbackKind) {
        guard !state.isViewingHistory, benefitFeedbackTask == nil,
              sessionTransitionID == nil, let session = state.session,
              [.reading, .showingResponse, .paused, .ended].contains(state.phase),
              state.responseItemID != nil || state.lesson != nil else { return }
        let note = state.benefitFeedbackNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let commandID = UUID()
        let foregroundSessionID = session.id
        state.benefitFeedbackError = nil
        state.isSavingBenefitFeedback = true
        benefitFeedbackTask = Task { [weak self] in
            guard let self else { return }
            defer {
                benefitFeedbackTask = nil
                if state.session?.id == foregroundSessionID { state.isSavingBenefitFeedback = false }
            }
            do {
                let saved = try await repository.recordBenefitFeedback(sessionID: foregroundSessionID,
                    commandID: commandID, kind: kind, note: note.isEmpty ? nil : note, at: now())
                guard !Task.isCancelled, state.session?.id == foregroundSessionID else { return }
                state.benefitFeedback = saved
                state.benefitFeedbackNote = saved.note ?? ""
                state.benefitFeedbackError = nil
                recordUsageEvent(.benefitFeedback, sessionID: foregroundSessionID,
                    attributes: ["feedback": kind.rawValue])
            } catch {
                guard !Task.isCancelled, state.session?.id == foregroundSessionID else { return }
                state.benefitFeedbackError = String(describing: error)
            }
        }
    }

    /// Settings can revoke known-item exclusions without deleting reading history.
    func resetKnownLessonFeedback() {
        saveLessonFeedback(sessionID: nil, itemID: nil, kind: nil)
    }

    private func saveLessonFeedback(sessionID: UUID?, itemID: UUID?, kind: MentorLessonFeedback?) {
        guard lessonFeedbackTask == nil else { return }
        let foregroundSessionID = state.session?.id
        let receipt = presentationTask
        let commandID = UUID()
        state.lessonFeedbackError = nil
        state.lessonFeedbackNotice = nil
        state.isSavingLessonFeedback = true
        lessonFeedbackTask = Task { [weak self] in
            guard let self else { return }
            defer {
                lessonFeedbackTask = nil
                if state.session?.id == foregroundSessionID { state.isSavingLessonFeedback = false }
            }
            do {
                await receipt?.value
                try Task.checkCancellation()
                if let sessionID, let itemID, let kind {
                    try await repository.recordLessonFeedback(sessionID: sessionID, itemID: itemID,
                        commandID: commandID, kind: kind, at: now())
                } else {
                    try await repository.resetKnownLessonFeedback(commandID: commandID, at: now())
                }
                guard state.session?.id == foregroundSessionID else { return }
                switch kind {
                case .notRelevant: state.lessonFeedbackNotice = "已记录，这次交流不再推荐这个主题。"
                case .alreadyKnown: state.lessonFeedbackNotice = "已记录，以后不再自动推荐这篇内容。已读记录仍会保留。"
                case nil: state.lessonFeedbackNotice = "已重置“已知道”反馈，已读记录仍会保留。"
                }
            } catch {
                guard !Task.isCancelled, state.session?.id == foregroundSessionID else { return }
                state.lessonFeedbackError = String(describing: error)
            }
        }
    }

    func finish() {
        guard !state.isViewingHistory else { return }
        guard let session = state.session else { return }
        let exitPhase = usageExitPhase
        let attemptID = activeAttemptID
        markPendingUsageRequestsEnded(sessionID: session.id)
        requestTask?.cancel()
        understandingGenerationTask?.cancel()
        endRequestWaitingNotice()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            if pendingSession != nil {
                // A blank in-memory entry has nothing to pause or end in the
                // database. Keep the synthetic state long enough for the view
                // to dismiss; the next start/continue discards it explicitly.
                state.phase = .ended
                recordUsageExit(phase: exitPhase, reason: "user", action: "finish", attemptID: attemptID)
                return
            }
            await presentationTask?.value
            await readingPositionTask?.value
            await benefitFeedbackTask?.value
            guard !Task.isCancelled else { return }
            let revision = state.draftRevision
            let text = state.inputText
            do {
                let current = try await self.repository.session(id: session.id) ?? session
                try Task.checkCancellation()
                try await self.repository.suspendSession(id: current.id, ending: true,
                    draftRevision: revision,
                    draftText: text)
                recordCancelledUsageRequests(sessionID: session.id)
                recordUsageExit(phase: exitPhase, reason: "user", action: "finish", attemptID: attemptID)
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                pendingResponse = nil
                pendingRequestEnd = nil
                state.canRetryRequestFinalization = false
                state.requestFinalizationError = nil
                state.canRetryResponseSave = false
                self.state.phase = .ended
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    func pause() {
        if state.isViewingHistory {
            recordUsageExit(phase: "history", reason: "user", action: "pause")
            return
        }
        guard let session = state.session else { return }
        let exitPhase = usageExitPhase
        let attemptID = activeAttemptID
        markPendingUsageRequestsEnded(sessionID: session.id)
        requestTask?.cancel()
        understandingGenerationTask?.cancel()
        endRequestWaitingNotice()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            if pendingSession != nil {
                state.phase = .paused
                recordUsageExit(phase: exitPhase, reason: "user", action: "pause", attemptID: attemptID)
                return
            }
            await presentationTask?.value
            await readingPositionTask?.value
            await benefitFeedbackTask?.value
            guard !Task.isCancelled else { return }
            let revision = state.draftRevision
            let text = state.inputText
            do {
                let current = try await self.repository.session(id: session.id) ?? session
                try Task.checkCancellation()
                try await self.repository.suspendSession(id: current.id, ending: false,
                    draftRevision: revision,
                    draftText: text)
                recordCancelledUsageRequests(sessionID: session.id)
                recordUsageExit(phase: exitPhase, reason: "user", action: "pause", attemptID: attemptID)
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                pendingResponse = nil
                pendingRequestEnd = nil
                state.canRetryRequestFinalization = false
                state.requestFinalizationError = nil
                state.canRetryResponseSave = false
                self.state.phase = .paused
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    /// Called by the view only after this exact response has appeared.
    /// Keeping the item ID in the event prevents an old view acknowledging a new response.
    func acknowledgeResponse(itemID: UUID) {
        guard state.responseItemID == itemID else { return }
        if state.isViewingHistory { observeHistoryPresentation(itemID: itemID, isResponse: true); return }
        acknowledge(itemID: itemID, isResponse: true)
    }

    /// The visible lesson's identity travels with scroll events, so a disappearing
    /// page cannot move the reading position of its replacement.
    func saveReadingPosition(itemID: UUID, section: MentorReadingSection, offset: Double = 0, layoutKey: String? = nil) {
        guard !state.isViewingHistory, sessionTransitionID == nil,
              state.phase != .paused, state.phase != .ended else { return }
        guard let lesson = state.lesson, lesson.id == itemID,
              lesson.sessionID == state.session?.id, state.phase != .selectingLesson,
              section != .observation || lesson.lesson.observation != nil else { return }
        guard offset.isFinite, offset >= 0, offset == 0 || layoutKey != nil else { return }
        guard section != lesson.readingSection || offset != lesson.readingOffset ||
              layoutKey != lesson.readingLayoutKey || state.readingPositionError != nil else { return }
        let updated = MentorSavedLesson(id: lesson.id, sessionID: lesson.sessionID,
            lesson: lesson.lesson, readingSection: section, readingRevision: lesson.readingRevision + 1,
            readingOffset: offset, readingLayoutKey: layoutKey)
        #if DEBUG
        NSLog("READING save section=%@:%f layout=%@ revision=%d", section.rawValue, offset, layoutKey ?? "nil", updated.readingRevision)
        #endif
        state.lesson = updated
        enqueueReadingPosition(updated)
    }

    func retryReadingPositionSave() {
        guard !state.isViewingHistory, sessionTransitionID == nil,
              state.phase != .paused, state.phase != .ended else { return }
        guard state.pendingReadingPositionSaves == 0, state.readingPositionError != nil,
              let lesson = state.lesson else { return }
        enqueueReadingPosition(lesson)
    }

    private func enqueueReadingPosition(_ lesson: MentorSavedLesson) {
        let previous = readingPositionTask
        state.pendingReadingPositionSaves += 1
        state.readingPositionError = nil
        readingPositionTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            defer {
                if state.session?.id == lesson.sessionID, state.lesson?.id == lesson.id {
                    state.pendingReadingPositionSaves -= 1
                }
            }
            do {
                try Task.checkCancellation()
                try await repository.saveReadingPosition(sessionID: lesson.sessionID, itemID: lesson.id,
                    revision: lesson.readingRevision, section: lesson.readingSection,
                    offset: lesson.readingOffset, layoutKey: lesson.readingLayoutKey)
                guard state.lesson?.id == lesson.id,
                      state.lesson?.readingRevision == lesson.readingRevision else { return }
                state.readingPositionError = nil
            } catch {
                guard !Task.isCancelled, state.lesson?.id == lesson.id,
                      state.lesson?.readingRevision == lesson.readingRevision else { return }
                state.readingPositionError = String(describing: error)
            }
        }
    }

    func acknowledgeLesson() {
        guard let lesson = state.lesson else { return }
        if state.isViewingHistory { observeHistoryPresentation(itemID: lesson.id, isResponse: false); return }
        acknowledge(itemID: lesson.id, isResponse: false)
    }

    /// Reopening content is observable but never a new recommendation or a
    /// domain presentation receipt. Read-only history stays read-only.
    private func observeHistoryPresentation(itemID: UUID, isResponse: Bool) {
        guard let session = state.session, acknowledgedPresentationIDs.insert(itemID).inserted else { return }
        recordUsageEvent(.contentPresented, sessionID: session.id,
            attributes: ["content_kind": isResponse ? "response" : "lesson", "presentation": "revisit",
                "content_version": isResponse ? "model-only" : state.lesson?.lesson.version ?? "unavailable",
                "schema_version": "1.0.0"])
    }

    private func acknowledge(itemID: UUID, isResponse: Bool) {
        guard let session = state.session,
              !acknowledgedPresentationIDs.contains(itemID),
              !pendingPresentationIDs.contains(itemID) else { return }
        let attemptID = activeAttemptID
        let observation = presentationObservations[itemID] ?? (date: now(), uptime: uptime())
        presentationObservations[itemID] = observation
        let presentationDate = observation.date
        let presentationUptime = observation.uptime
        let contentVersion = isResponse ? "model-only" : state.lesson?.lesson.version ?? "unavailable"
        let previous = presentationTask
        pendingPresentationIDs.insert(itemID)
        if state.presentationError != nil { state.presentationError = nil }
        presentationTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            defer { pendingPresentationIDs.remove(itemID) }
            guard !Task.isCancelled, state.session?.id == session.id else { return }
            do {
                let isNew = try await repository.acknowledgePresentation(sessionID: session.id, itemID: itemID,
                    at: presentationDate, timeZone: timeZone)
                let current = try await repository.session(id: session.id)
                recordUsageEvent(.contentPresented, sessionID: session.id,
                    attributes: ["content_kind": isResponse ? "response" : "lesson", "content_version": contentVersion,
                        "schema_version": "1.0.0", "presentation": isNew ? "new" : "revisit"],
                    attemptID: attemptID, occurredAt: presentationDate, observedUptime: presentationUptime)
                presentationObservations.removeValue(forKey: itemID)
                // Receipt updates must not overwrite foreground lifecycle or draft edits.
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                if let current { state.session?.recallCount = current.recallCount }
                acknowledgedPresentationIDs.insert(itemID)
                if isResponse, state.responseItemID == itemID {
                    state.acknowledgedResponseItemID = itemID
                }
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                state.presentationError = String(describing: error)
            }
        }
    }

    private enum UnderstandingCommand {
        case begin(UUID, UUID?)
        case save(String)
        case confirm
    }

    /// Switching editors is disabled until queued writes finish. A failed edit
    /// must be retried before another draft can replace its in-memory text.
    func selectUnderstandingDraft(id: UUID) {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, !state.hasUnsavedUnderstanding,
              state.pendingUnderstandingOperations == 0, state.understandingError == nil,
              let draft = state.understandings.first(where: { $0.id == id }),
              draft.sessionID == state.session?.id, draft.state == .draft else { return }
        understandingGeneration = UUID()
        state.understanding = draft
        state.understandingInputText = draft.text
    }

    func beginUnderstanding(previousRevisionID: UUID? = nil) {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, !state.hasUnsavedUnderstanding,
              state.session != nil, state.pendingUnderstandingOperations == 0,
              state.understandingError == nil else { return }
        var initialText = ""
        if let previousRevisionID {
            guard let previous = state.understandings.first(where: { $0.id == previousRevisionID }),
                  previous.state == .confirmed, previous.sessionID == state.session?.id else { return }
            // Resume an existing revision draft rather than creating a second one.
            if let draft = state.understandings.first(where: { $0.previousRevisionID == previousRevisionID && $0.state == .draft }) {
                selectUnderstandingDraft(id: draft.id)
                return
            }
            guard !state.understandings.contains(where: { $0.groupID == previous.groupID && $0.revision > previous.revision }) else { return }
            initialText = previous.text
        }
        understandingGeneration = UUID()
        state.understanding = nil
        state.understandingInputText = initialText
        state.understandingError = nil
        let id = UUID()
        pendingUnderstandingCreation = (id, previousRevisionID)
        // Keep an empty editor entirely in memory when the conversation itself
        // is still a pending blank entry. The first non-empty edit queues the
        // creation together with its text.
        if pendingSession == nil {
            enqueueUnderstanding(.begin(id, previousRevisionID))
        }
    }

    /// Text-editor input is immediate in memory and persisted after 500 ms of quiet.
    func updateUnderstandingText(_ text: String) {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding,
              state.session != nil, state.understanding?.state != .confirmed,
              state.understanding != nil || pendingUnderstandingCreation != nil,
              text != state.understandingInputText else { return }
        state.understandingInputText = text
        state.hasUnsavedUnderstanding = true
        pendingUnderstandingText = text
        understandingDebounceTask?.cancel()
        let generation = understandingGeneration
        understandingDebounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) }
            catch { return }
            guard let self, !Task.isCancelled, understandingGeneration == generation else { return }
            understandingDebounceTask = nil
            flushScheduledUnderstanding()
        }
    }

    private func flushScheduledUnderstanding() {
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        guard let text = pendingUnderstandingText else { return }
        pendingUnderstandingText = nil
        // A blank conversation keeps the editor's draft in memory until its
        // first real edit. Queue creation before the save, including when a
        // navigation flush has just materialized the conversation row.
        if state.understanding == nil, let pending = pendingUnderstandingCreation,
           state.pendingUnderstandingOperations == 0, state.understandingError == nil {
            enqueueUnderstanding(.begin(pending.id, pending.previousRevisionID))
        }
        enqueueUnderstanding(.save(text))
    }

    /// Explicit save bypasses the input debounce and replaces any scheduled text.
    func saveUnderstanding(text: String) {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding,
              state.session != nil, state.understanding?.state != .confirmed,
              state.understanding != nil || pendingUnderstandingCreation != nil else { return }
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        pendingUnderstandingText = nil
        state.understandingInputText = text
        state.hasUnsavedUnderstanding = true
        // A failed creation has no writable row yet; retain edits for its retry.
        if state.understanding == nil {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if pendingSession != nil {
                // The first save in a pending blank session queues creation
                // and the text write. Later edits can queue another save
                // behind that creation, but must not enqueue a duplicate
                // begin command for the same draft ID.
                if let pending = pendingUnderstandingCreation,
                   state.pendingUnderstandingOperations == 0 {
                    enqueueUnderstanding(.begin(pending.id, pending.previousRevisionID))
                }
            } else if state.pendingUnderstandingOperations == 0 {
                return
            }
        }
        enqueueUnderstanding(.save(text))
    }

    func retryUnderstandingSave() {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, state.pendingUnderstandingOperations == 0, state.understandingError != nil else { return }
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        pendingUnderstandingText = nil
        if let pending = pendingUnderstandingCreation {
            enqueueUnderstanding(.begin(pending.id, pending.previousRevisionID))
            enqueueUnderstanding(.save(state.understandingInputText))
        } else if state.understanding?.state == .draft {
            enqueueUnderstanding(.save(state.understandingInputText))
        }
    }

    /// Call only after the user explicitly confirms discarding unsaved understanding edits.
    /// Already queued writes settle first; only the remaining memory buffer is discarded.
    @discardableResult
    func discardUnderstandingEdits() async -> Bool {
        guard !state.isViewingHistory, sessionTransitionID == nil, !state.isConfirmingUnderstanding,
              let sessionID = state.session?.id else { return false }
        let transition = beginSessionTransition()
        defer { endSessionTransition(transition) }
        let selectedID = state.understanding?.id ?? pendingUnderstandingCreation?.id
        let generation = understandingGeneration
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        await understandingTask?.value
        guard !Task.isCancelled, state.session?.id == sessionID,
              understandingGeneration == generation, sessionTransitionID == transition else { return false }
        do {
            let saved = try await repository.understandings(sessionID: sessionID)
            guard !Task.isCancelled, state.session?.id == sessionID,
                  understandingGeneration == generation, sessionTransitionID == transition else { return false }
            let selected = saved.first { $0.id == selectedID }
            understandingGeneration = UUID()
            pendingUnderstandingText = nil
            pendingUnderstandingCreation = nil
            state.understandings = saved
            state.understanding = selected
            state.understandingInputText = selected?.text ?? ""
            state.hasUnsavedUnderstanding = false
            state.understandingError = nil
            return true
        } catch {
            guard !Task.isCancelled, state.session?.id == sessionID,
                  sessionTransitionID == transition else { return false }
            state.understandingError = String(describing: error)
            return false
        }
    }

    func confirmUnderstanding() {
        guard !state.isViewingHistory else { return }
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding, state.session != nil,
              state.understanding != nil || pendingUnderstandingCreation != nil else { return }
        if pendingSession != nil && state.understandingInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.understandingError = "请先写下一句自己的理解。"
            return
        }
        state.isConfirmingUnderstanding = true
        flushScheduledUnderstanding()
        enqueueUnderstanding(.confirm)
    }

    /// Serialize local edits independently of model work. Confirmation reads the
    /// last successfully saved revision after all earlier commands have finished.
    private func enqueueUnderstanding(_ command: UnderstandingCommand) {
        let generation = understandingGeneration
        let previous = understandingTask
        state.pendingUnderstandingOperations += 1
        understandingTask = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled, understandingGeneration == generation else { return }
            defer { if understandingGeneration == generation {
                state.pendingUnderstandingOperations -= 1
                if case .confirm = command { state.isConfirmingUnderstanding = false }
            } }
            do {
                let materializeForEditor: Bool
                if case .begin = command { materializeForEditor = true }
                else { materializeForEditor = false }
                guard let session = try await materializePendingSessionIfNeeded(force: materializeForEditor) else { return }
                let sessionID = session.id
                guard state.session?.id == sessionID else { return }
                let saved: MentorUnderstanding
                switch command {
                case .begin(let id, let previousID):
                    saved = try await repository.beginUserUnderstanding(sessionID: sessionID,
                        draftID: id, previousRevisionID: previousID)
                case .save(let text):
                    guard let draft = state.understanding else { return }
                    saved = try await repository.saveUnderstandingDraft(sessionID: sessionID,
                        draftID: draft.id, editRevision: draft.editRevision + 1, text: text)
                case .confirm:
                    // A failed preceding edit must not confirm the older text.
                    guard state.understandingError == nil, let draft = state.understanding else { return }
                    saved = try await repository.confirmUnderstanding(sessionID: sessionID,
                        draftID: draft.id, expectedEditRevision: draft.editRevision)
                }
                guard !Task.isCancelled, understandingGeneration == generation,
                      state.session?.id == sessionID else { return }
                if case .begin = command { pendingUnderstandingCreation = nil }
                state.understanding = saved
                state.hasUnsavedUnderstanding = pendingUnderstandingText != nil || saved.text != state.understandingInputText
                if let index = state.understandings.firstIndex(where: { $0.id == saved.id }) {
                    state.understandings[index] = saved
                } else {
                    state.understandings.append(saved)
                }
                state.understandingError = nil
                if case .confirm = command, saved.state == .confirmed {
                    recordUsageEvent(.understandingConfirmed, sessionID: sessionID)
                }
            } catch {
                guard !Task.isCancelled, understandingGeneration == generation else { return }
                state.understandingError = String(describing: error)
            }
        }
    }

    /// Keep original model output for audit; only executable suggestions reach
    /// the UI. The current mentor contract asks for at most two follow-up
    /// entries. Enforce that presentation budget locally as well, so an older
    /// or over-eager model response cannot turn the bottom of the conversation
    /// into a menu of competing tasks. The stored response remains unchanged
    /// for replay and audit.
    private func supportedSuggestions(_ turn: MentorValidatedTurn) -> MentorValidatedTurn {
        let actions = Array(turn.availableSuggestedActions.filter { action in
            switch action {
            case .draftUnderstanding: return true
            case .anotherLesson: return catalog != nil
            case .reply, .explain, .finish: return true
            }
        }.prefix(2))
        return MentorValidatedTurn(response: turn.response, availableSuggestedActions: actions)
    }

    /// Reconstruct from saved versions, never from the current teaching catalog.
    /// Preserve every understanding group; only a unique draft is auto-selected.
    private func restoredState(session: MentorSession, lesson: MentorSavedLesson? = nil) async throws -> MentorFeatureState {
        let items = try await repository.items(sessionID: session.id)
        try Task.checkCancellation()
        var savedLesson = lesson
        if savedLesson == nil, let item = items.last(where: { $0.kind == .lesson }) {
            savedLesson = try await repository.savedLesson(sessionID: session.id, itemID: item.id)
            guard savedLesson != nil else { throw MentorFeatureError.missingSavedLesson }
        }
        try Task.checkCancellation()
        let notes = try await repository.understandings(sessionID: session.id)
        try Task.checkCancellation()
        let benefitFeedback = try await repository.benefitFeedback(sessionID: session.id)
        try Task.checkCancellation()
        let drafts = notes.filter { $0.state == .draft }
        let draft = drafts.count == 1 ? drafts.first : nil
        var restored = MentorFeatureState(phase: .editing, session: session, timeline: items,
            lesson: savedLesson, benefitFeedback: benefitFeedback,
            benefitFeedbackNote: benefitFeedback?.note ?? "", understandings: notes, understanding: draft,
            understandingInputText: draft?.text ?? "", inputText: session.draftText,
            draftRevision: session.draftRevision)
        let links = try await repository.sourceLinks(sessionID: session.id)
        let userItemIDs = Set(items.filter { $0.kind == .user }.map(\.id))
        for link in links where link.ownerKind == .item && link.sourceKind == "capture" && userItemIDs.contains(link.ownerID) {
            if let reference = try? MentorSourceReference("capture:\(link.sourceID)"),
               !restored.borrowedCaptureSources[link.ownerID, default: []].contains(reference) {
                restored.borrowedCaptureSources[link.ownerID, default: []].append(reference)
            }
        }
        if let last = items.last, last.kind == .assistant {
            // Replay the committed original, without re-evaluating historical
            // sources against today's context or counting it as presented.
            let response = try JSONDecoder().decode(MentorTurnResponse.self, from: Data(last.payloadJSON.utf8))
            guard response.schemaVersion == "1.0.0" else { throw MentorResponseError.unsupportedSchema }
            restored.response = supportedSuggestions(MentorValidatedTurn(response: response,
                availableSuggestedActions: response.suggestedActions))
            restored.responseItemID = last.id
        }
        restored.retryableRequest = try await repository.retryableRequest(sessionID: session.id)
        try Task.checkCancellation()
        return restored
    }

    /// The database epoch, rather than transport cancellation alone, rejects late responses.
    private func suspendPreviousSession(destinationID: UUID?, destinationEntry: String) async throws {
        await presentationTask?.value
        try Task.checkCancellation()
        guard let previous = state.session else { return }
        let exitPhase = usageExitPhase
        if state.isViewingHistory || previous.id == destinationID {
            recordUsageExit(phase: exitPhase, reason: "switch", action: "switch", destinationEntry: destinationEntry)
            return
        }
        if pendingSession?.id == previous.id {
            // The user opened a blank discuss entry and left it without adding
            // material. There is no database lifecycle to suspend.
            pendingSession = nil
            recordUsageExit(phase: exitPhase, reason: "switch", action: "switch", destinationEntry: destinationEntry)
            return
        }
        let text = state.inputText
        let revision = state.draftRevision
        guard let current = try await repository.session(id: previous.id) else {
            throw MentorFeatureError.missingSession
        }
        try Task.checkCancellation()
        if current.lifecycle != .ended && current.lifecycle != .paused {
            try await repository.suspendSession(id: current.id, ending: false,
                draftRevision: revision, draftText: text)
            try Task.checkCancellation()
            // Keep the old screen truthful if destination activation subsequently fails.
            let suspended = try await repository.session(id: current.id)
            try Task.checkCancellation()
            state.session = suspended
            state.phase = .paused
        }
        recordCancelledUsageRequests(sessionID: previous.id)
        recordUsageExit(phase: exitPhase, reason: "switch", action: "switch", destinationEntry: destinationEntry)
        try Task.checkCancellation()
    }

    private func resetSessionBuffers() {
        acknowledgedPresentationIDs.removeAll()
        pendingPresentationIDs.removeAll()
        presentationObservations.removeAll()
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        understandingGenerationTask?.cancel()
        understandingGenerationTask = nil
        understandingRequestGeneration = UUID()
        pendingUnderstandingText = nil
        state.hasUnsavedUnderstanding = false
        understandingGeneration = UUID()
        state.pendingUnderstandingOperations = 0
        pendingUnderstandingCreation = nil
        state.isGeneratingUnderstanding = false
        state.understandingGenerationError = nil
        state.generatedUnderstandingID = nil
        pendingResponse = nil
        pendingRequestEnd = nil
        pendingRecallContinuation = nil
        endRequestWaitingNotice()
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
    }

    private func startTask(entry: String, initialText: String, attemptID: UUID,
                           automaticallyOpenReview: Bool) async -> ReviewOpening? {
        do {
            await lessonFeedbackTask?.value
            await benefitFeedbackTask?.value
            await readingPositionTask?.value
            try Task.checkCancellation()
            // Process recovery belongs to application bootstrap, never a new
            // session: other stores may still own active requests.
            if entry == "listen", initialText.isEmpty,
               let saved = try await repository.listeningResume(at: now(), timeZone: timeZone) {
                try Task.checkCancellation()
                guard let session = try await repository.session(id: saved.sessionID) else { throw MentorFeatureError.missingSession }
                var restored = try await restoredState(session: session, lesson: saved)
                try Task.checkCancellation()
                try await suspendPreviousSession(destinationID: session.id, destinationEntry: entry)
                switch session.lifecycle {
                case .ended:
                    restored.phase = .ended
                    restored.isViewingHistory = true
                case .paused: restored.phase = .paused
                default: restored.phase = restored.response == nil ? .reading : .showingResponse
                }
                resetSessionBuffers()
                state = restored
                activeAttemptID = attemptID
                restoreUsagePath(attemptID: attemptID, from: restored)
                await attachActiveAttempt(to: session.id)
                return nil
            }
            try Task.checkCancellation()
            if entry == "listen", catalog == nil {
                state.actionError = "当前版本没有可用的已审核教材。你可以先输入一件事，或从最近交流中查看已经保存的内容。"
                if state.session == nil { state.phase = .idle }
                return nil
            }
            try await suspendPreviousSession(destinationID: nil, destinationEntry: entry)
            let id = UUID()
            if entry == "discuss" && initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingSession = PendingSession(id: id, entry: entry, attemptID: attemptID)
                resetSessionBuffers()
                activeAttemptID = attemptID
                await activeAttemptEventTask?.value
                state = MentorFeatureState(
                    phase: .editing,
                    session: MentorSession(id: id, initialEntry: entry, lifecycle: .draft,
                        draftText: "", draftRevision: 0, activityAt: now()))
                return nil
            }
            try await repository.createSession(MentorSession(id: id, initialEntry: entry, lifecycle: .draft,
                draftText: initialText, draftRevision: initialText.isEmpty ? 0 : 1, activityAt: now()))
            guard let session = try await repository.session(id: id) else { throw MentorFeatureError.missingSession }
            try Task.checkCancellation()
            activeAttemptID = attemptID
            await attachActiveAttempt(to: session.id)
            resetSessionBuffers()
            state = MentorFeatureState(phase: .editing, session: session, inputText: initialText,
                draftRevision: session.draftRevision)
            state.isTransitioningSession = sessionTransitionID != nil
            if entry == "listen" {
                guard let catalog else { throw MentorFeatureError.lessonCatalogUnavailable }
                guard let lesson = try await repository.selectNextLesson(sessionID: id, itemID: UUID(), expectedEpoch: session.requestEpoch,
                    catalog: catalog, at: now(), timeZone: timeZone) else { state.phase = .failed("no_lesson"); return nil }
                state.lesson = lesson
                state.timeline = try await repository.items(sessionID: id)
                state.phase = .reading
            }
            guard entry == "review", automaticallyOpenReview, initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return ReviewOpening(session: session, attemptID: attemptID)
        } catch is CancellationError { return nil }
        catch {
            guard !Task.isCancelled else { return nil }
            state.phase = .failed(String(describing: error))
            return nil
        }
    }

    /// Opens a zero-material review with one model turn. The request is kept
    /// on the same foreground task as later replies, but starts only after the
    /// session transition has finished so the user sees the actual invitation.
    private func startReviewOpening(_ opening: ReviewOpening) async {
        guard state.session?.id == opening.session.id, !state.isViewingHistory,
              state.phase == .editing else { return }
        state.phase = .submitting
        let waitingGeneration = beginRequestWaitingNotice()
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        let generation = dependencyGeneration
        let startedAt = ContinuousClock().now
        await submitTask(session: opening.session, intent: "review", text: "",
            transport: transport, prompt: prompt, startedAt: startedAt,
            generation: generation, operationGeneration: waitingGeneration)
        endRequestWaitingNotice(generation: waitingGeneration)
    }

    private func submitTask(session: MentorSession, intent: String, text: String,
                            transport: MentorTransport, prompt: PromptTemplate, startedAt: ContinuousClock.Instant,
                            retry: MentorRetryableRequest? = nil, generation: UUID,
                            operationGeneration: UUID,
                            selectedMaterialFragments: [MentorMaterialFragment] = []) async {
        guard requestWaitingGeneration == operationGeneration, let policy = activeRequestPolicy else { return }
        state.requestFailureMessage = nil
        let requestAttemptID = activeAttemptID
        let requestStartedAt = waitingStartedAt ?? uptime()
        if let requestAttemptID { usageAttempts[requestAttemptID]?.pendingOperations += 1 }
        var foregroundAcquired = false
        defer {
            if foregroundAcquired { releaseForegroundAIActivity() }
            if let requestAttemptID { usageAttempts[requestAttemptID]?.pendingOperations -= 1 }
            pruneUsageAttempts()
        }
        var submittedRequestID: UUID?
        let consumedDraft = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state.inputText == text
            ? MentorConsumedDraft(revision: state.draftRevision, text: text) : nil
        var prospectiveItems: [MentorTimelineItem] = []
        let prospectiveUserID = pendingMaterialSubmission?.userItemID ?? UUID()
        do {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard await flushPendingEdits() else { throw MentorFeatureError.draftSaveFailed }
            try Task.checkCancellation()
            guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
            let items = try await repository.items(sessionID: session.id)
            prospectiveItems = items
            if retry == nil, !trimmed.isEmpty {
                let payload = String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self)
                prospectiveItems.append(MentorTimelineItem(id: prospectiveUserID, sessionID: session.id,
                    sequence: (items.map(\.sequence).max() ?? 0) + 1, kind: .user, payloadJSON: payload))
            }
            let built: MentorBuiltContext
            if let retry, retry.contextSnapshotJSON != "{}" {
                built = try MentorContextBuilder().replay(json: retry.contextSnapshotJSON, session: current)
            } else {
                built = try MentorContextBuilder().build(session: current, items: prospectiveItems, intent: intent,
                    responseIntent: intent == "explain" ? .directTeaching : .discuss,
                    currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [],
                    selectedMaterialFragments: selectedMaterialFragments,
                    suppressCurrentUserAnchor: trimmed.isEmpty)
            }
            if let requestAttemptID { usageAttempts[requestAttemptID]?.pendingOperations += 0 }
            guard acquireForegroundAIActivity() else {
                state.phase = state.response == nil ? .editing : .showingResponse
                state.actionError = "今日整理正在处理中，完成后再开始导师交流。"
                return
            }
            foregroundAcquired = true
            let requestID = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: current.id,
                text: trimmed.isEmpty ? nil : text,
                intent: intent, contextSnapshotJSON: retry?.contextSnapshotJSON ?? built.json, retryOf: retry?.id,
                userItemID: retry == nil && !trimmed.isEmpty ? prospectiveUserID : nil))
            submittedRequestID = requestID
            state.timeline = try await repository.items(sessionID: current.id)
            let switchedEntry = intent == "reply" && !trimmed.isEmpty &&
                requestAttemptID.flatMap { usageAttempts[$0]?.currentEntry } == "listen" ? "discuss" : nil
            trackUsageRequest(requestID, sessionID: session.id, attemptID: requestAttemptID,
                startedAt: requestStartedAt, switchedEntry: switchedEntry)
            guard dependencyGeneration == generation, requestWaitingGeneration == operationGeneration else { throw CancellationError() }
            activeRequestID = requestID
            activeRequestGeneration = operationGeneration
            let progress = makeStreamProgress(generation: operationGeneration, startedAt: startedAt, field: "body")
            armRequestDeadline(generation: operationGeneration, policy: policy, startedAt: startedAt)
            state.retryableRequest = nil
            state.retryError = nil
            var request = LLMRequest(prompt: prompt,
                inputSummary: built.json, sourceRecordIDs: built.payload.sources.map { $0.ref.value }, contextVersion: 1,
                contextRecordIDs: built.payload.sources.map { $0.ref.value })
            request.mentorExecutionPolicy = policy
            request.mentorStartedAt = startedAt
            request.mentorStreamProgress = progress
            let token = LLMRequest.MentorAuditToken(sessionID: current.id, requestID: requestID,
                requestEpoch: current.requestEpoch, semanticRevision: current.semanticRevision)
            request.mentorAuditToken = token
            try await repository.prepareRequestContext(token: token, json: built.json)
            try Task.checkCancellation()
            let data = try await transport.complete(request)
            markUsageRequestEnded(requestID)
            try Task.checkCancellation()
            guard dependencyGeneration == generation, requestWaitingGeneration == operationGeneration else { throw CancellationError() }
            let parsed = try MentorResponseParser().parseTurn(data, context: built.validation)
            try MentorResponseQualityPolicy.validate(parsed.response, context: built.validation,
                initialEntry: built.payload.initialEntry, intent: intent)
            let validated = supportedSuggestions(parsed)
            let pending = PendingResponse(sessionID: current.id, requestID: requestID,
                payload: String(decoding: try JSONEncoder().encode(validated.response), as: UTF8.self), validated: validated,
                consumedDraft: consumedDraft)
            pendingResponse = pending
            try await saveResponse(pending)
            state.streamingPreview = ""
        } catch let error as MentorContextError {
            if case let .requiresMaterialSelection(characterCount, limit) = error,
               submittedRequestID == nil {
                let currentUserID = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : prospectiveUserID
                let candidates = MentorContextBuilder.materialSelectionCandidates(items: prospectiveItems, currentUserSourceID: currentUserID)
                pendingMaterialSubmission = PendingMaterialSubmission(sessionID: session.id, intent: intent, text: text,
                    restorePhase: state.response == nil ? .editing : .showingResponse, userItemID: prospectiveUserID)
                state.materialSelection = MentorMaterialSelectionState(characterCount: characterCount, limit: limit,
                    candidates: candidates, currentUserSourceID: currentUserID)
                state.phase = pendingMaterialSubmission?.restorePhase ?? .editing
                state.actionError = nil
                return
            }
            await handleSubmitError(error, submittedRequestID: submittedRequestID, sessionID: session.id,
                operationGeneration: operationGeneration)
        } catch {
            await handleSubmitError(error, submittedRequestID: submittedRequestID, sessionID: session.id,
                operationGeneration: operationGeneration)
        }
    }

    private func handleSubmitError(_ error: Error, submittedRequestID: UUID?, sessionID: UUID,
                                   operationGeneration: UUID) async {
            if let submittedRequestID { markUsageRequestEnded(submittedRequestID) }
            guard !Task.isCancelled, requestWaitingGeneration == operationGeneration else {
                if let submittedRequestID { await reconcileAbandonedUsageRequest(sessionID: sessionID, requestID: submittedRequestID) }
                return
            }
            if pendingResponse == nil, let requestID = submittedRequestID {
                let reason: MentorRequestEndReason
                switch error {
                case MentorRequestExecutionError.timedOut: reason = .timedOut
                case is CancellationError, MentorRequestExecutionError.cancelled: reason = .cancelled
                default: reason = .failed
                }
                let end = PendingRequestEnd(sessionID: sessionID, requestID: requestID, reason: reason)
                pendingRequestEnd = end
                await persistRequestEnd(end)
                guard !Task.isCancelled else { return }
            }
            state.canRetryResponseSave = pendingResponse != nil
            state.requestFailureMessage = (error as? LLMClientError)?.userFacingMessage
            state.phase = .failed(String(describing: error))
    }

    /// Retries only the terminal database write; never invokes transport.
    func retryRequestFinalization() {
        guard state.canRetryRequestFinalization, let end = pendingRequestEnd,
              state.session?.id == end.sessionID else { return }
        state.canRetryRequestFinalization = false
        requestTask = Task { [weak self] in await self?.persistRequestEnd(end) }
    }

    private func persistRequestEnd(_ end: PendingRequestEnd) async {
        do {
            try await repository.finishRequest(sessionID: end.sessionID, requestID: end.requestID, reason: end.reason)
            recordUsageEvent(.requestFinished, sessionID: end.sessionID,
                attributes: ["reason": end.reason.rawValue], requestID: end.requestID)
            guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
            pendingRequestEnd = nil
            state.canRetryRequestFinalization = false
            state.requestFinalizationError = nil
            do {
                let candidate = try await repository.retryableRequest(sessionID: end.sessionID)
                guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
                state.retryableRequest = candidate
                state.retryError = nil
            } catch {
                guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
                state.retryError = String(describing: error)
            }
        } catch {
            guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
            state.canRetryRequestFinalization = true
            state.requestFinalizationError = String(describing: error)
        }
    }

    func retryResponseSave() {
        guard state.canRetryResponseSave, let pending = pendingResponse,
              pending.sessionID == state.session?.id else { return }
        state.canRetryResponseSave = false
        state.phase = .submitting
        requestTask = Task { [weak self] in
            guard let self else { return }
            do { try await saveResponse(pending) }
            catch {
                guard !Task.isCancelled else { return }
                state.canRetryResponseSave = pendingResponse != nil
                state.phase = .failed(String(describing: error))
            }
        }
    }

    private func applyConsumedDraft(_ pending: PendingResponse, session: MentorSession) {
        guard state.session?.id == pending.sessionID,
              let draft = pending.consumedDraft, state.draftRevision == draft.revision, state.inputText == draft.text,
              session.draftRevision == draft.revision, session.draftText.isEmpty else { return }
        draftDebounceTask?.cancel()
        draftDebounceTask = nil
        state.inputText = ""
        state.hasUnsavedDraft = false
        state.draftSaveError = nil
    }

    private func saveResponse(_ pending: PendingResponse) async throws {
        try Task.checkCancellation()
        let item = try await repository.commitResponse(sessionID: pending.sessionID,
            requestID: pending.requestID, payloadJSON: pending.payload, consumingDraft: pending.consumedDraft)
        recordUsageEvent(.requestFinished, sessionID: pending.sessionID,
            attributes: ["reason": "succeeded"], requestID: pending.requestID)
        let timeline = try await repository.items(sessionID: pending.sessionID)
        let session = try await repository.session(id: pending.sessionID)
        guard state.session?.id == pending.sessionID, let session else { return }
        applyConsumedDraft(pending, session: session)
        try Task.checkCancellation()
        state.timeline = timeline
        state.session = session
        state.retryableRequest = nil
        state.retryError = nil
        state.response = pending.validated
        state.responseItemID = item.id
        state.acknowledgedResponseItemID = nil
        state.canRetryResponseSave = false
        pendingResponse = nil
        pendingMaterialSubmission = nil
        state.materialSelection = nil
        state.phase = .showingResponse
        if state.session?.initialEntry == "review", pending.validated.response.materialStatus == .usable,
           !pending.validated.response.requiresMaterial, pending.validated.response.action != .clarify {
            let superseded = Set(timeline.compactMap(\.supersedesItemID))
            let events = timeline.filter { $0.kind == .user && !superseded.contains($0.id) }.compactMap { item -> LifeGuidanceEvent? in
                guard let text = (try? JSONDecoder().decode([String: String].self, from: Data(item.payloadJSON.utf8)))?["text"] else { return nil }
                return LifeGuidanceEvent(id: "item:" + item.id.uuidString, text: text)
            }
            if !events.isEmpty {
                onReviewReady?(pending.sessionID, events)
            }
        }
    }
}

enum MentorFeatureError: Error { case missingSession, lessonCatalogUnavailable, missingSavedLesson, draftSaveFailed }
