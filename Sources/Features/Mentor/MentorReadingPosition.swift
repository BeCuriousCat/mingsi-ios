import SwiftUI
import UIKit

struct MentorReadingAnchor: Hashable {
    let itemID: UUID
    let section: MentorReadingSection
}

struct MentorReadingSectionMarker: ViewModifier {
    let itemID: UUID
    let section: MentorReadingSection
    let geometry: MentorReadingGeometry
    func body(content: Content) -> some View {
        content.background(MentorReadingMarker(geometry: geometry, itemID: itemID, section: section))
    }
}

/// Geometry and timers deliberately do not publish view state. Publishing every
/// scroll sample would rebuild the same layout that produced the sample.
@MainActor
final class MentorReadingPositionCoordinator: ObservableObject {
    struct Position: Equatable {
        let itemID: UUID
        let section: MentorReadingSection
        let offset: Double
        let layoutKey: String
    }
    private struct Snapshot {
        let lesson: MentorSavedLesson
        let frames: [MentorReadingAnchor: CGRect]
        let viewport: CGRect
        let layoutKey: String
        let canSave: Bool
        let save: (Position) -> Void
    }
    private weak var scrollView: UIScrollView?
    private var snapshot: Snapshot?
    private var restoredKey: String?
    private var restoringKey: String?
    private var generation = UUID()
    private var restoreTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var pending: (Position, (Position) -> Void)?
    private var lastOffered: Position?
    private var restoredScrollOffset: CGPoint?

    func attach(_ scroll: UIScrollView) {
        guard scrollView !== scroll else { return }
        scrollView = scroll
        process()
    }

    func update(lesson: MentorSavedLesson, frames: [MentorReadingAnchor: CGRect], viewport: CGRect,
                layoutKey: String, canSave: Bool, save: @escaping (Position) -> Void) {
        snapshot = Snapshot(lesson: lesson, frames: frames, viewport: viewport,
                            layoutKey: layoutKey, canSave: canSave, save: save)
        process()
    }

    /// A lazy timeline has no geometry for a distant lesson until SwiftUI has
    /// materialized it. Bootstrap by item identity before restoring its section.
    func revealIfNeeded(itemID: UUID, reveal: () -> Void) {
        guard snapshot?.frames.contains(where: { $0.key.itemID == itemID && $0.value.height > 0 }) != true else {
            process()
            return
        }
        reveal()
    }

    private func process() {
        guard let snapshot, let scrollView, scrollView.window != nil else { return }
        let lesson = snapshot.lesson
        let key = "\(lesson.sessionID)/\(lesson.id)/\(snapshot.layoutKey)"
        let frames = snapshot.frames.filter { $0.key.itemID == lesson.id && $0.value.height > 0 }
        guard !frames.isEmpty else { return }
        if restoredKey != key {
            // A rotation or text-size change may arrive before debounce saves.
            // Keep the most recently read section, using its offset only when
            // the layout still matches.
            let local = pending?.0 ?? lastOffered
            let target: Position
            if let local, local.itemID == lesson.id { target = local }
            else {
                target = Position(itemID: lesson.id, section: lesson.readingSection,
                    offset: lesson.readingOffset, layoutKey: lesson.readingLayoutKey ?? "")
            }
            guard restoringKey != key,
                  frames[MentorReadingAnchor(itemID: lesson.id, section: target.section)] != nil else { return }
            flush()
            restoreTask?.cancel()
            restoringKey = key
            let token = generation
            restoreTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self else { return }
                defer {
                    if self.generation == token, self.restoringKey == key {
                        self.restoringKey = nil
                    }
                }
                guard !Task.isCancelled, generation == token,
                      let latest = self.snapshot, let scroll = self.scrollView,
                      latest.lesson.id == lesson.id, latest.layoutKey == snapshot.layoutKey,
                      let frame = latest.frames[MentorReadingAnchor(itemID: lesson.id, section: target.section)] else { return }
                let offset = target.layoutKey == latest.layoutKey ? target.offset : 0
                let delta = frame.minY - latest.viewport.minY + min(CGFloat(offset), frame.height)
                let minimum = -scroll.adjustedContentInset.top
                let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                let y = min(maximum, max(minimum, scroll.contentOffset.y + delta))
                // Mark this restoration before moving: layout callbacks caused by
                // setContentOffset must not schedule another restoration.
                restoredKey = key
                restoringKey = nil
                restoredScrollOffset = CGPoint(x: scroll.contentOffset.x, y: y)
                UIView.performWithoutAnimation { scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: false) }
            }
            return
        }
        guard snapshot.canSave, restoringKey == nil else { return }
        if let initial = restoredScrollOffset {
            guard abs(initial.y - scrollView.contentOffset.y) > 1 else { return }
            restoredScrollOffset = nil
        }
        let visible = frames.filter { $0.value.maxY > snapshot.viewport.minY && $0.value.minY < snapshot.viewport.maxY }
        guard let first = visible.min(by: { $0.value.minY < $1.value.minY }) else { return }
        let offset = Double(max(0, snapshot.viewport.minY - first.value.minY).rounded())
        let position = Position(itemID: lesson.id, section: first.key.section, offset: offset, layoutKey: snapshot.layoutKey)
        guard lastOffered != position else { return }
        lastOffered = position
        pending = (position, snapshot.save)
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard let (position, save) = pending else { return }
        pending = nil
        save(position)
    }

    func reset() {
        generation = UUID()
        restoreTask?.cancel()
        saveTask?.cancel()
        restoreTask = nil
        saveTask = nil
        pending = nil
        lastOffered = nil
        snapshot = nil
        restoredKey = nil
        restoringKey = nil
        restoredScrollOffset = nil
    }
}

/// Samples marker and viewport frames in the same UIKit coordinate space after
/// layout, including native scroll offset and sheet presentation changes.
@MainActor
final class MentorReadingGeometry: ObservableObject {
    private struct WeakMarker { weak var view: MentorReadingMarker.Marker? }
    private var markers: [ObjectIdentifier: WeakMarker] = [:]
    private weak var scroll: UIScrollView?
    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var sampleTask: Task<Void, Never>?
    private var sample: ((UIScrollView, [MentorReadingAnchor: CGRect], CGRect) -> Void)?
    private var presented: ((UUID) -> Void)?

    func configure(coordinator: MentorReadingPositionCoordinator, lesson: MentorSavedLesson?,
                   layoutKey: String, canSave: Bool,
                   save: @escaping (MentorReadingPositionCoordinator.Position) -> Void,
                   presented: @escaping (UUID) -> Void) {
        self.presented = presented
        sample = { [weak coordinator] scroll, frames, viewport in
            guard let coordinator, let lesson else { return }
            coordinator.attach(scroll)
            coordinator.update(lesson: lesson, frames: frames, viewport: viewport,
                               layoutKey: layoutKey, canSave: canSave, save: save)
        }
        scheduleSample()
    }

    fileprivate func register(_ marker: MentorReadingMarker.Marker) {
        markers[ObjectIdentifier(marker)] = WeakMarker(view: marker)
        var ancestor = marker.superview
        while let view = ancestor {
            if let enclosing = view as? UIScrollView {
                attach(enclosing)
                break
            }
            ancestor = view.superview
        }
        scheduleSample()
    }

    private func attach(_ view: UIScrollView) {
        guard scroll !== view else { return }
        scroll = view
        offsetObservation = view.observe(\.contentOffset) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.scheduleSample() }
        }
        sizeObservation = view.observe(\.contentSize) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.scheduleSample() }
        }
    }

    fileprivate func scheduleSample() {
        guard sampleTask == nil else { return }
        sampleTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        sampleTask?.cancel()
        sampleTask = nil
        guard let scroll, scroll.window != nil else { return }
        // SwiftUI extends the native scroll view beneath navigation bars. Only
        // the area inside its adjusted insets is actually readable.
        let viewport = scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: nil)
        guard viewport.width > 0, viewport.height > 0 else { return }
        var frames: [MentorReadingAnchor: CGRect] = [:]
        var visibleItems = Set<UUID>()
        markers = markers.filter { $0.value.view != nil }
        for marker in markers.values {
            guard let view = marker.view, view.window != nil, view.bounds.height > 0 else { continue }
            let frame = view.convert(view.bounds, to: nil)
            if let section = view.section {
                frames[MentorReadingAnchor(itemID: view.itemID, section: section)] = frame
            } else if frame.intersects(viewport) { visibleItems.insert(view.itemID) }
        }
        sample?(scroll, frames, viewport)
        for id in visibleItems { presented?(id) }
    }

    func reset() {
        sampleTask?.cancel()
        sampleTask = nil
        sample = nil
        presented = nil
        offsetObservation = nil
        sizeObservation = nil
        scroll = nil
        markers.removeAll()
    }
}

struct MentorReadingMarker: UIViewRepresentable {
    let geometry: MentorReadingGeometry
    let itemID: UUID
    var section: MentorReadingSection? = nil

    func makeUIView(context: Context) -> Marker {
        let view = Marker()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }
    func updateUIView(_ view: Marker, context: Context) {
        view.geometry = geometry
        view.itemID = itemID
        view.section = section
        geometry.register(view)
    }

    final class Marker: UIView {
        weak var geometry: MentorReadingGeometry?
        var itemID = UUID()
        var section: MentorReadingSection?
        override func didMoveToWindow() { super.didMoveToWindow(); geometry?.register(self) }
        override func layoutSubviews() { super.layoutSubviews(); geometry?.register(self) }
    }
}

struct MentorReadingScrollProbe: UIViewRepresentable {
    let geometry: MentorReadingGeometry
    let coordinator: MentorReadingPositionCoordinator
    let lesson: MentorSavedLesson?
    let layoutKey: String
    let canSave: Bool
    let save: (MentorReadingPositionCoordinator.Position) -> Void
    let presented: (UUID) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        geometry.configure(coordinator: coordinator, lesson: lesson, layoutKey: layoutKey,
                           canSave: canSave, save: save, presented: presented)
    }
}
