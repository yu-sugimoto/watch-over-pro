import Foundation

@Observable
@MainActor
final class GaitAnalysisEngine {
    var baselineCadence: Double = 110.0
    var baselinePace: Double = 0.8
    var cadenceStdDev: Double = 8.0
    var paceStdDev: Double = 0.12

    private var cadenceHistory: [Double] = []
    private var paceHistory: [Double] = []
    private let windowSize = 50
    private let anomalyThreshold: Double = 2.8

    func analyzeSample(cadence: Double, pace: Double, accelerationMag: Double, rotationMag: Double) -> AnomalyEvent? {
        updateBaseline(cadence: cadence, pace: pace)

        if cadence > 0 {
            let cadenceZScore = abs(cadence - baselineCadence) / max(cadenceStdDev, 1.0)
            if cadenceZScore > anomalyThreshold {
                let severity = min(cadenceZScore / 5.0, 1.0)
                return AnomalyEvent(
                    type: .cadenceIrregularity,
                    severity: severity,
                    description: "ケイデンス偏差: \(Int(cadence)) 歩/分 (基準値: \(Int(baselineCadence)) 歩/分)"
                )
            }
        }

        if pace > 0 {
            let paceZScore = abs(pace - baselinePace) / max(paceStdDev, 0.01)
            if paceZScore > anomalyThreshold {
                let severity = min(paceZScore / 5.0, 1.0)
                return AnomalyEvent(
                    type: .paceFluctuation,
                    severity: severity,
                    description: "ペース偏差: \(String(format: "%.2f", pace)) s/m (基準値: \(String(format: "%.2f", baselinePace)) s/m)"
                )
            }
        }

        let accelThreshold = 3.5
        if accelerationMag > accelThreshold {
            let severity = min((accelerationMag - accelThreshold) / 4.0, 1.0)
            return AnomalyEvent(
                type: .instability,
                severity: severity,
                description: "高加速度を検出: \(String(format: "%.1f", accelerationMag))g"
            )
        }

        return nil
    }

    func assessRisk(for session: GaitSession) -> GaitRiskLevel {
        guard !session.samples.isEmpty else { return .normal }

        let anomalyRate = Double(session.anomalies.count) / Double(max(session.samples.count, 1))
        let avgSeverity = session.anomalies.isEmpty ? 0 : session.anomalies.map(\.severity).reduce(0, +) / Double(session.anomalies.count)

        if anomalyRate > 0.25 || avgSeverity > 0.8 {
            return .high
        } else if anomalyRate > 0.10 || avgSeverity > 0.55 {
            return .elevated
        }
        return .normal
    }

    func reset() {
        cadenceHistory.removeAll()
        paceHistory.removeAll()
    }

    private func updateBaseline(cadence: Double, pace: Double) {
        if cadence > 0 {
            cadenceHistory.append(cadence)
            if cadenceHistory.count > windowSize {
                cadenceHistory.removeFirst()
            }
            if cadenceHistory.count >= 10 {
                baselineCadence = cadenceHistory.reduce(0, +) / Double(cadenceHistory.count)
                cadenceStdDev = standardDeviation(cadenceHistory)
            }
        }

        if pace > 0 {
            paceHistory.append(pace)
            if paceHistory.count > windowSize {
                paceHistory.removeFirst()
            }
            if paceHistory.count >= 10 {
                baselinePace = paceHistory.reduce(0, +) / Double(paceHistory.count)
                paceStdDev = standardDeviation(paceHistory)
            }
        }
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        let count = Double(values.count)
        guard count > 1 else { return 0 }
        let mean = values.reduce(0, +) / count
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / (count - 1)
        return sqrt(variance)
    }
}
