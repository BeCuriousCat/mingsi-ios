import Foundation

#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(EventKit)
import EventKit
#endif
#if canImport(HealthKit)
import HealthKit
#endif

enum SideQuestAuthorizationStatus: String, Hashable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case writeOnly
    case readAccessUnknown
    case unavailable

    var displayTitle: String {
        switch self {
        case .notDetermined: return "未请求"
        case .restricted: return "受限"
        case .denied: return "已拒绝"
        case .authorized: return "已允许"
        case .writeOnly: return "仅允许写入"
        case .readAccessUnknown: return "读取范围由系统管理"
        case .unavailable: return "不可用"
        }
    }
}

enum SideQuestPermissionKind: String, Hashable, Sendable {
    case location, calendar, health
}

enum SideQuestPermissionRequestResult: Sendable {
    case completed, denied, failed, unavailable

    func message(for kind: SideQuestPermissionKind) -> String {
        switch (kind, self) {
        case (.health, .completed): return "已完成授权选择。读取范围可在“健康”App或系统设置中查看。"
        case (.calendar, .completed): return "已完成日历授权选择，当前读取权限见上方状态。"
        case (.health, .denied): return "未完成健康授权选择，其他功能可以继续使用。"
        case (.calendar, .denied): return "未允许读取日历，其他功能可以继续使用。"
        case (.health, .failed): return "健康连接未完成，请稍后重试。其他功能可以继续使用。"
        case (.calendar, .failed): return "日历授权未完成，请稍后重试。"
        case (_, .unavailable): return "此设备暂时无法使用这项系统数据。"
        default: return "系统权限选择已结束，请查看当前状态。"
        }
    }
}

protocol SideQuestContextProviding: AnyObject {
    var locationAuthorizationStatus: SideQuestAuthorizationStatus { get }
    var calendarAuthorizationStatus: SideQuestAuthorizationStatus { get }
    var healthAuthorizationStatus: SideQuestAuthorizationStatus { get }
    func snapshot(now: Date) async -> SideQuestContextSnapshot
    func requestLocationAuthorization()
    func requestCalendarAuthorization() async -> SideQuestPermissionRequestResult
    func requestHealthAuthorization() async -> SideQuestPermissionRequestResult
}

enum SideQuestHealthMetric: String, CaseIterable {
    case steps
    case activeEnergy
    case sleepDuration
}

protocol SideQuestHealthQuerying {
    func aggregate(metric: SideQuestHealthMetric, start: Date, end: Date) async -> Double?
}

struct AggregatingSideQuestHealthSummaryProvider {
    let query: SideQuestHealthQuerying
    var calendar: Calendar = .current

    func summary(now: Date = .now) async -> [String] {
        let start = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: now)) ?? now
        var tokens: [String] = []
        if let value = await query.aggregate(metric: .steps, start: start, end: now), value >= 0 {
            let dailyAverage = value / 3
            tokens.append(dailyAverage < 3_000 ? "health_steps_low" : dailyAverage < 8_000 ? "health_steps_moderate" : "health_steps_high")
        }
        if let value = await query.aggregate(metric: .activeEnergy, start: start, end: now), value >= 0 {
            let dailyAverage = value / 3
            tokens.append(dailyAverage < 100 ? "health_activity_low" : dailyAverage < 300 ? "health_activity_moderate" : "health_activity_high")
        }
        if let value = await query.aggregate(metric: .sleepDuration, start: start, end: now), value >= 0 {
            let averageHours = value / 3 / 3_600
            tokens.append(averageHours < 6 ? "health_sleep_short" : averageHours < 8 ? "health_sleep_typical" : "health_sleep_long")
        }
        return tokens.sorted()
    }
}

#if canImport(HealthKit)
private struct HealthKitSideQuestHealthQuery: SideQuestHealthQuerying {
    let store: HKHealthStore
    func aggregate(metric: SideQuestHealthMetric, start: Date, end: Date) async -> Double? {
        switch metric {
        case .steps: return await quantitySum(identifier: .stepCount, unit: HKUnit.count(), start: start, end: end)
        case .activeEnergy: return await quantitySum(identifier: .activeEnergyBurned, unit: HKUnit.kilocalorie(), start: start, end: end)
        case .sleepDuration:
            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
            let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            return await withCheckedContinuation { c in
                let q = HKSampleQuery(sampleType: type, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                    let intervals = (samples as? [HKCategorySample] ?? []).compactMap { sample -> DateInterval? in
                        guard Self.isAsleep(sample) else { return nil }
                        return DateInterval(start: max(sample.startDate, start), end: min(sample.endDate, end))
                    }
                    c.resume(returning: Self.mergedDuration(intervals))
                }
                store.execute(q)
            }
        }
    }
    private func quantitySum(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let p = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { c in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: p, options: .cumulativeSum) { _, stats, _ in c.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit)) }
            store.execute(q)
        }
    }

    private static func isAsleep(_ sample: HKCategorySample) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
        return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
    }

    private static func mergedDuration(_ intervals: [DateInterval]) -> Double? {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var merged = sorted.first else { return nil }
        var duration: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= merged.end {
                merged = DateInterval(start: merged.start, end: max(merged.end, interval.end))
            } else {
                duration += merged.duration
                merged = interval
            }
        }
        return duration + merged.duration
    }
}
#endif

final class SystemSideQuestContextProvider: NSObject, SideQuestContextProviding {
    #if canImport(CoreLocation)
    private let locationManager = CLLocationManager()
    #endif
    #if canImport(EventKit)
    private let eventStore = EKEventStore()
    #endif
    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    private let locationSceneProvider: () -> SideQuestContextSnapshot.Scene
    private let calendarAvailabilityProvider: (Date) -> SideQuestContextSnapshot.Availability
    private let healthSummaryProvider: () async -> [String]

    init(
        locationSceneProvider: (() -> SideQuestContextSnapshot.Scene?)? = nil,
        calendarAvailabilityProvider: ((Date) -> SideQuestContextSnapshot.Availability)? = nil,
        healthSummaryProvider: (() async -> [String])? = nil
    ) {
        self.locationSceneProvider = {
            if let locationSceneProvider { return locationSceneProvider() ?? .unknown }
            #if canImport(CoreLocation)
            return .familiarPlace
            #else
            return .unknown
            #endif
        }
        self.calendarAvailabilityProvider = calendarAvailabilityProvider ?? { _ in .unknown }
        self.healthSummaryProvider = healthSummaryProvider ?? Self.liveHealthSummaryProvider()
        super.init()
    }

    var locationAuthorizationStatus: SideQuestAuthorizationStatus {
        #if canImport(CoreLocation)
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    var calendarAuthorizationStatus: SideQuestAuthorizationStatus {
        #if canImport(EventKit)
        return Self.calendarReadAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
        #else
        return .unavailable
        #endif
    }

    #if canImport(EventKit)
    static func calendarReadAuthorizationStatus(_ status: EKAuthorizationStatus) -> SideQuestAuthorizationStatus {
        switch status {
        case .fullAccess, .authorized: return .authorized
        case .writeOnly: return .writeOnly
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }
    #endif

    static func healthReadAuthorizationStatus(isAvailable: Bool) -> SideQuestAuthorizationStatus {
        // Availability and successful prompting never reveal read permission.
        isAvailable ? .readAccessUnknown : .unavailable
    }

    var healthAuthorizationStatus: SideQuestAuthorizationStatus {
        #if canImport(HealthKit)
        return Self.healthReadAuthorizationStatus(isAvailable: HKHealthStore.isHealthDataAvailable())
        #else
        return .unavailable
        #endif
    }

    func snapshot(now: Date = .now) async -> SideQuestContextSnapshot {
        let scene = locationSceneProvider()
        let availability = calendarAvailabilityProvider(now)
        let health = await healthSummaryProvider()
        // System data is intentionally reduced to coarse, non-identifying values.
        return SideQuestContextSnapshot(
            scene: scene,
            availability: availability,
            knownContext: health,
            constraints: availability == .busy ? ["calendar_busy"] : []
        )
    }

    func requestLocationAuthorization() {
        #if canImport(CoreLocation)
        locationManager.requestWhenInUseAuthorization()
        #endif
    }

    func requestCalendarAuthorization() async -> SideQuestPermissionRequestResult {
        #if canImport(EventKit)
        do { return try await eventStore.requestFullAccessToEvents() ? .completed : .denied }
        catch { return calendarAuthorizationStatus == .denied ? .denied : .failed }
        #else
        return .unavailable
        #endif
    }

    func requestHealthAuthorization() async -> SideQuestPermissionRequestResult {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: Self.healthReadTypes())
            return .completed
        } catch { return .failed }
        #else
        return .unavailable
        #endif
    }
}

extension SystemSideQuestContextProvider {
    /// Constructs a provider backed by the system stores. The closures only
    /// return reduced values and never expose raw event, location, or sample data.
    static func system() -> SystemSideQuestContextProvider {
        SystemSideQuestContextProvider(
            locationSceneProvider: {
                #if canImport(CoreLocation)
                let manager = CLLocationManager()
                guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else {
                    return .unknown
                }
                return manager.location == nil ? .unknown : .familiarPlace
                #else
                return .unknown
                #endif
            },
            calendarAvailabilityProvider: { now in
                #if canImport(EventKit)
                let status = EKEventStore.authorizationStatus(for: .event)
                guard status == .fullAccess else { return .unknown }
                let store = EKEventStore()
                let start = Calendar.current.date(byAdding: .minute, value: -30, to: now) ?? now
                let end = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
                let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
                return events.isEmpty ? .openWindow : .busy
                #else
                return .unknown
                #endif
            },
            healthSummaryProvider: liveHealthSummaryProvider()
        )
    }

    private static func liveHealthSummaryProvider() -> () async -> [String] {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return { [] } }
        let aggregator = AggregatingSideQuestHealthSummaryProvider(query: HealthKitSideQuestHealthQuery(store: HKHealthStore()))
        return { await aggregator.summary() }
        #else
        return { [] }
        #endif
    }

    #if canImport(HealthKit)
    private static func healthReadTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let type = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(type) }
        if let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(type) }
        if let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(type) }
        return types
    }
    #endif
}

final class StaticSideQuestContextProvider: SideQuestContextProviding {
    var locationAuthorizationStatus: SideQuestAuthorizationStatus
    var calendarAuthorizationStatus: SideQuestAuthorizationStatus
    var healthAuthorizationStatus: SideQuestAuthorizationStatus
    var providedSnapshot: SideQuestContextSnapshot
    private(set) var locationRequestCount = 0
    private(set) var calendarRequestCount = 0
    private(set) var healthRequestCount = 0
    private(set) var snapshotRequestCount = 0
    var calendarRequestResult: SideQuestPermissionRequestResult = .completed
    var healthRequestResult: SideQuestPermissionRequestResult = .completed

    init(
        snapshot: SideQuestContextSnapshot = .empty,
        location: SideQuestAuthorizationStatus = .notDetermined,
        calendar: SideQuestAuthorizationStatus = .notDetermined,
        health: SideQuestAuthorizationStatus = .notDetermined
    ) {
        providedSnapshot = snapshot
        locationAuthorizationStatus = location
        calendarAuthorizationStatus = calendar
        healthAuthorizationStatus = health
    }

    func snapshot(now: Date = .now) async -> SideQuestContextSnapshot {
        snapshotRequestCount += 1
        return providedSnapshot
    }
    func requestLocationAuthorization() { locationRequestCount += 1 }
    func requestCalendarAuthorization() async -> SideQuestPermissionRequestResult {
        calendarRequestCount += 1
        return calendarRequestResult
    }
    func requestHealthAuthorization() async -> SideQuestPermissionRequestResult {
        healthRequestCount += 1
        return healthRequestResult
    }
}
