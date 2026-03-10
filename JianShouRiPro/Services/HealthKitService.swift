import Foundation
import HealthKit

@Observable
@MainActor
final class HealthKitService {
    var metrics = HealthMetrics.empty
    var isAuthorized = false
    var authorizationError: String?
    var onStepCountUpdated: ((Int) -> Void)?
    var onSteadinessUpdated: ((Double) -> Void)?

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var isObserving = false

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else {
            authorizationError = "このデバイスではヘルスデータを利用できません"
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.walkingSpeed),
            HKQuantityType(.walkingStepLength),
            HKQuantityType(.walkingAsymmetryPercentage),
            HKQuantityType(.walkingDoubleSupportPercentage),
            HKQuantityType(.appleWalkingSteadiness),
            HKQuantityType(.stepCount),
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchLatestMetrics()
        } catch {
            authorizationError = error.localizedDescription
        }
    }

    func startBackgroundObservers() {
        guard isAuthorized, !isObserving else { return }
        isObserving = true

        setupObserverQuery(for: .stepCount, frequency: .hourly)
        setupObserverQuery(for: .appleWalkingSteadiness, frequency: .immediate)
        setupObserverQuery(for: .walkingSpeed, frequency: .hourly)
        setupObserverQuery(for: .walkingAsymmetryPercentage, frequency: .hourly)
        setupObserverQuery(for: .walkingDoubleSupportPercentage, frequency: .hourly)
    }

    func stopBackgroundObservers() {
        for query in observerQueries {
            store.stop(query)
        }
        observerQueries.removeAll()
        isObserving = false
    }

    private func setupObserverQuery(for identifier: HKQuantityTypeIdentifier, frequency: HKUpdateFrequency) {
        let sampleType = HKQuantityType(identifier)

        store.enableBackgroundDelivery(for: sampleType, frequency: frequency) { _, _ in }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    completionHandler()
                    return
                }

                switch identifier {
                case .stepCount:
                    let steps = await self.fetchStepCount(for: Date())
                    self.onStepCountUpdated?(steps)
                case .appleWalkingSteadiness:
                    let steadiness = await self.fetchLatestQuantity(.appleWalkingSteadiness, unit: .percent())
                    if let steadiness {
                        self.metrics.walkingSteadiness = steadiness
                        self.onSteadinessUpdated?(steadiness)
                    }
                default:
                    await self.fetchLatestMetrics()
                }

                completionHandler()
            }
        }

        store.execute(query)
        observerQueries.append(query)
    }

    func fetchLatestMetrics() async {
        async let speed = fetchLatestQuantity(.walkingSpeed, unit: .meter().unitDivided(by: .second()))
        async let stepLength = fetchLatestQuantity(.walkingStepLength, unit: .meter())
        async let asymmetry = fetchLatestQuantity(.walkingAsymmetryPercentage, unit: .percent())
        async let doubleSupport = fetchLatestQuantity(.walkingDoubleSupportPercentage, unit: .percent())
        async let steadiness = fetchLatestQuantity(.appleWalkingSteadiness, unit: .percent())

        let (s, sl, a, ds, st) = await (speed, stepLength, asymmetry, doubleSupport, steadiness)

        metrics = HealthMetrics(
            walkingSpeed: s,
            stepLength: sl,
            walkingAsymmetry: a,
            doubleSupport: ds,
            walkingSteadiness: st,
            lastUpdated: Date()
        )
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()), end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func fetchStepCount(for date: Date) async -> Int {
        let type = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            store.execute(query)
        }
    }
}
