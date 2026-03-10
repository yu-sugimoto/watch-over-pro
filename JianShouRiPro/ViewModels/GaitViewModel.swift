import Foundation

@Observable
@MainActor
final class GaitViewModel {
    var motionService = MotionService()
    var healthService = HealthKitService()
    var analysisEngine = GaitAnalysisEngine()

    var currentSession: GaitSession?
    var sessions: [GaitSession] = []
    var dailySummaries: [DailyGaitSummary] = []
    var isMonitoring = false
    var currentRiskLevel: GaitRiskLevel = .normal
    var todaySteps: Int = 0
    var showAlert = false
    var alertMessage = ""

    private let persistence = PersistenceService.shared
    private var sampleTimer: Timer?

    private let maxStoredSessions = 200
    private let maxSamplesPerSession = 7200

    init() {
        var loaded = persistence.loadSessions()
        if loaded.count > maxStoredSessions {
            loaded = Array(loaded.prefix(maxStoredSessions))
            persistence.saveSessions(loaded)
        }
        sessions = loaded
        dailySummaries = persistence.loadSummaries()
        updateTodaySteps()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        currentSession = GaitSession()
        analysisEngine.reset()
        motionService.startMonitoring()
        startSampling()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        motionService.stopMonitoring()
        sampleTimer?.invalidate()
        sampleTimer = nil

        if var session = currentSession {
            session.endDate = Date()
            session.riskLevel = analysisEngine.assessRisk(for: session)
            if !session.samples.isEmpty {
                session.averageCadence = session.samples.map(\.cadence).reduce(0, +) / Double(session.samples.count)
                session.averagePace = session.samples.filter { $0.pace > 0 }.map(\.pace).reduce(0, +) / Double(max(session.samples.filter { $0.pace > 0 }.count, 1))
            }
            session.stepCount = motionService.stepCount
            sessions.insert(session, at: 0)
            if sessions.count > maxStoredSessions {
                sessions = Array(sessions.prefix(maxStoredSessions))
            }
            persistence.saveSessions(sessions)
            updateDailySummary(for: session)
            currentRiskLevel = session.riskLevel
            currentSession = nil
        }
    }

    func requestHealthAuthorization() async {
        await healthService.requestAuthorization()
        await refreshHealthMetrics()
    }

    func refreshHealthMetrics() async {
        await healthService.fetchLatestMetrics()
        todaySteps = await healthService.fetchStepCount(for: Date())
    }

    func deleteSession(_ session: GaitSession) {
        sessions.removeAll { $0.id == session.id }
        persistence.saveSessions(sessions)
    }

    func clearAllData() {
        sessions.removeAll()
        dailySummaries.removeAll()
        persistence.saveSessions(sessions)
        persistence.saveSummaries(dailySummaries)
        currentRiskLevel = .normal
    }

    func cleanup() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        motionService.stopMonitoring()
        isMonitoring = false
        currentSession = nil
    }

    var recentSessions: [GaitSession] {
        Array(sessions.prefix(10))
    }

    var todaySessionCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.startDate >= startOfDay }.count
    }

    var todayAnomalyCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.startDate >= startOfDay }.flatMap(\.anomalies).count
    }

    var weeklyRiskTrend: [DailyGaitSummary] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        return dailySummaries.filter { $0.date >= startOfWeek }.sorted { $0.date < $1.date }
    }

    private func startSampling() {
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.collectSample()
            }
        }
    }

    private func collectSample() {
        guard isMonitoring, var session = currentSession else { return }

        let acc = motionService.latestAcceleration
        let rot = motionService.latestRotation
        let accMag = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        let rotMag = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)

        let sample = GaitSample(
            cadence: motionService.currentCadence,
            pace: motionService.currentPace,
            accelerationMagnitude: accMag,
            rotationMagnitude: rotMag
        )
        if session.samples.count >= maxSamplesPerSession {
            session.samples.removeFirst(session.samples.count - maxSamplesPerSession + 1)
        }
        session.samples.append(sample)
        session.stepCount = motionService.stepCount

        if let anomaly = analysisEngine.analyzeSample(
            cadence: sample.cadence,
            pace: sample.pace,
            accelerationMag: accMag,
            rotationMag: rotMag
        ) {
            session.anomalies.append(anomaly)
        }

        session.riskLevel = analysisEngine.assessRisk(for: session)
        currentRiskLevel = session.riskLevel
        currentSession = session
    }

    private func updateTodaySteps() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        todaySteps = sessions.filter { $0.startDate >= startOfDay }.map(\.stepCount).reduce(0, +)
    }

    private func updateDailySummary(for session: GaitSession) {
        let calendar = Calendar.current
        let sessionDay = calendar.startOfDay(for: session.startDate)

        if let index = dailySummaries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: sessionDay) }) {
            var summary = dailySummaries[index]
            summary.totalSteps += session.stepCount
            summary.anomalyCount += session.anomalies.count
            summary.sessionCount += 1
            let allDaySessions = sessions.filter { calendar.isDate($0.startDate, inSameDayAs: sessionDay) }
            let allCadences = allDaySessions.flatMap(\.samples).map(\.cadence).filter { $0 > 0 }
            if !allCadences.isEmpty {
                summary.averageCadence = allCadences.reduce(0, +) / Double(allCadences.count)
            }
            summary.riskLevel = allDaySessions.map(\.riskLevel).max(by: { a, b in
                (GaitRiskLevel.allCases.firstIndex(of: a) ?? 0) < (GaitRiskLevel.allCases.firstIndex(of: b) ?? 0)
            }) ?? .normal
            dailySummaries[index] = summary
        } else {
            let summary = DailyGaitSummary(
                date: sessionDay,
                totalSteps: session.stepCount,
                averageCadence: session.averageCadence,
                averagePace: session.averagePace,
                anomalyCount: session.anomalies.count,
                riskLevel: session.riskLevel,
                sessionCount: 1
            )
            dailySummaries.append(summary)
        }

        dailySummaries.sort { $0.date > $1.date }
        persistence.saveSummaries(dailySummaries)
        updateTodaySteps()
    }
}
