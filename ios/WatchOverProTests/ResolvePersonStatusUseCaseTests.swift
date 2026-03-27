import Testing
import Foundation
@testable import WatchOverPro

struct ResolvePersonStatusUseCaseTests {
    let sut = ResolvePersonStatusUseCase()

    @Test func nilLastUpdated_returnsOffline() {
        let result = sut.execute(lastUpdated: nil)
        #expect(result == .offline)
    }

    @Test func recentUpdate_returnsOnline() {
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let result = sut.execute(lastUpdated: twoMinutesAgo)
        #expect(result == .online)
    }

    @Test func oldUpdate_returnsOffline() {
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let result = sut.execute(lastUpdated: tenMinutesAgo)
        #expect(result == .offline)
    }

    @Test func exactlyFiveMinutes_returnsOffline() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let result = sut.execute(lastUpdated: fiveMinutesAgo)
        #expect(result == .offline)
    }

    @Test func justUnderFiveMinutes_returnsOnline() {
        let justUnder = Date().addingTimeInterval(-299)
        let result = sut.execute(lastUpdated: justUnder)
        #expect(result == .online)
    }

    @Test func inactiveUser_returnsPaused() {
        let recentDate = Date().addingTimeInterval(-60)
        let result = sut.execute(lastUpdated: recentDate, isActive: false)
        #expect(result == .paused)
    }
}
