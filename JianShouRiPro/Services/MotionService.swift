import Foundation
import CoreMotion

@Observable
@MainActor
final class MotionService {
    var isMonitoring = false
    var isWalking = false
    var currentCadence: Double = 0
    var currentPace: Double = 0
    var stepCount: Int = 0
    var latestAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    var latestRotation: (x: Double, y: Double, z: Double) = (0, 0, 0)
    var isMotionAvailable = false
    var isPedometerAvailable = false

    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private let sensorQueue = OperationQueue()
    private var monitoringStartDate: Date?
    private var isDeviceMotionActive = false

    init() {
        sensorQueue.name = "com.gait.motion"
        sensorQueue.maxConcurrentOperationCount = 1
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        isPedometerAvailable = CMPedometer.isStepCountingAvailable()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitoringStartDate = Date()

        startActivityTracking()
        startPedometer()

        if motionManager.isDeviceMotionAvailable {
            startDeviceMotion()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        motionManager.stopDeviceMotionUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
        activityManager.stopActivityUpdates()
        currentCadence = 0
        currentPace = 0
        monitoringStartDate = nil
    }

    private func startActivityTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        let status = CMMotionActivityManager.authorizationStatus()
        guard status == .authorized else { return }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            Task { @MainActor in
                self?.isWalking = activity.walking && activity.confidence.rawValue >= CMMotionActivityConfidence.medium.rawValue
            }
        }
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        guard let startDate = monitoringStartDate else { return }

        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard let data, error == nil else { return }
            Task { @MainActor in
                self?.stepCount = data.numberOfSteps.intValue
                if let cadence = data.currentCadence {
                    self?.currentCadence = cadence.doubleValue * 60.0
                }
                if let pace = data.currentPace {
                    self?.currentPace = pace.doubleValue
                }
            }
        }
    }

    private func startDeviceMotion() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0

        motionManager.startDeviceMotionUpdates(to: sensorQueue) { [weak self] motion, error in
            guard let motion, error == nil else { return }
            let userAcc = motion.userAcceleration
            let rotation = motion.rotationRate

            Task { @MainActor in
                self?.latestAcceleration = (userAcc.x, userAcc.y, userAcc.z)
                self?.latestRotation = (rotation.x, rotation.y, rotation.z)
            }
        }
        isDeviceMotionActive = true
    }

    func pauseDeviceMotion() {
        guard isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
        isDeviceMotionActive = false
        latestAcceleration = (0, 0, 0)
        latestRotation = (0, 0, 0)
    }

    func resumeDeviceMotion() {
        guard isMonitoring, !isDeviceMotionActive, motionManager.isDeviceMotionAvailable else { return }
        startDeviceMotion()
    }
}
