import Foundation
import SwiftData
import Observation
import LoseWeightCore
#if os(iOS)
import HealthKit
#endif

/// Reads workouts and weigh-ins from Apple Health and writes weigh-ins back.
/// Health data lives on iPhone/iPad; the Mac gets everything through iCloud sync instead.
@MainActor
@Observable
final class HealthKitService {
    private(set) var isAvailable: Bool
    private(set) var lastSync: Date?
    private(set) var lastError: String?

    #if os(iOS)
    private let store = HKHealthStore()
    private let kg = HKUnit.gramUnit(with: .kilo)
    #endif

    init() {
        #if os(iOS)
        isAvailable = HKHealthStore.isHealthDataAvailable()
        #else
        isAvailable = false
        #endif
    }

    func requestAuthorization() async -> Bool {
        #if os(iOS)
        guard isAvailable else { return false }
        let mass = HKQuantityType(.bodyMass)
        let read: Set<HKObjectType> = [mass, HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        do {
            try await store.requestAuthorization(toShare: [mass], read: read)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
    }

    /// Returns the Health sample ID so we never import our own reading back.
    func saveWeight(kg value: Double, date: Date) async -> String? {
        #if os(iOS)
        guard isAvailable else { return nil }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: kg, doubleValue: value),
            start: date,
            end: date
        )
        do {
            try await store.save(sample)
            return sample.uuid.uuidString
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        #else
        return nil
        #endif
    }

    func sync(into context: ModelContext, profile: UserProfile, days: Int = 30) async {
        #if os(iOS)
        guard isAvailable,
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return }
        let window = HKQuery.predicateForSamples(withStart: start, end: nil)
        do {
            try await importWeights(window: window, context: context)
            try await importWorkouts(window: window, context: context, profile: profile)
            lastSync = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    #if os(iOS)
    private func importWeights(window: NSPredicate, context: ModelContext) async throws {
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass), predicate: window)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await query.result(for: store)
        let known = Set(try context.fetch(FetchDescriptor<WeightEntry>()).compactMap(\.healthKitID))
        let ownBundle = Bundle.main.bundleIdentifier
        for s in samples where !known.contains(s.uuid.uuidString) {
            // Our own writes are already in the app.
            if s.sourceRevision.source.bundleIdentifier == ownBundle { continue }
            context.insert(WeightEntry(
                timestamp: s.startDate,
                kg: s.quantity.doubleValue(for: kg),
                healthKitID: s.uuid.uuidString,
                isImported: true
            ))
        }
    }

    private func importWorkouts(window: NSPredicate, context: ModelContext, profile: UserProfile) async throws {
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(window)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let workouts = try await query.result(for: store)
        let known = Set(try context.fetch(FetchDescriptor<ExerciseEntry>()).compactMap(\.healthKitID))
        var latestWeight = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        latestWeight.fetchLimit = 1
        let weightKg = try context.fetch(latestWeight).first?.kg ?? profile.startWeightKg

        for w in workouts where !known.contains(w.uuid.uuidString) {
            let minutes = (w.duration / 60).rounded()
            guard minutes >= 5 else { continue }
            let type = Self.exerciseType(for: w.workoutActivityType)
            context.insert(ExerciseEntry(
                timestamp: w.startDate,
                type: type,
                intensity: intensity(for: w, type: type, weightKg: weightKg),
                minutes: minutes,
                weightKg: weightKg,
                healthKitID: w.uuid.uuidString
            ))
        }
    }

    /// Picks the intensity whose MET value is closest to what the workout's active energy implies.
    private func intensity(for workout: HKWorkout, type: ExerciseType, weightKg: Double) -> Intensity {
        let hours = workout.duration / 3600
        guard hours > 0, weightKg > 0,
              let active = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        else { return .moderate }
        let impliedMET = active / (weightKg * hours) + 1
        return Intensity.allCases.min { abs(type.met(for: $0) - impliedMET) < abs(type.met(for: $1) - impliedMET) } ?? .moderate
    }

    private static func exerciseType(for activity: HKWorkoutActivityType) -> ExerciseType {
        switch activity {
        case .walking, .hiking, .stairs, .stairClimbing: .walk
        case .running: .run
        case .cycling, .handCycling: .cycle
        case .swimming, .waterFitness: .swim
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: .strength
        case .yoga, .pilates, .flexibility, .mindAndBody, .cooldown, .taiChi: .yoga
        case .soccer, .basketball, .tennis, .pickleball, .golf, .americanFootball, .baseball, .softball,
             .volleyball, .racquetball, .badminton, .hockey, .squash, .tableTennis, .rugby, .cricket:
            .sports
        default: .other
        }
    }
    #endif
}
