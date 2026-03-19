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

    @Test func staleUpdate_returnsStale() {
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let result = sut.execute(lastUpdated: tenMinutesAgo)
        #expect(result == .stale)
    }

    @Test func oldUpdate_returnsOffline() {
        let twentyMinutesAgo = Date().addingTimeInterval(-1200)
        let result = sut.execute(lastUpdated: twentyMinutesAgo)
        #expect(result == .offline)
    }

    @Test func exactlyFiveMinutes_returnsStale() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let result = sut.execute(lastUpdated: fiveMinutesAgo)
        #expect(result == .stale)
    }

    @Test func exactlyFifteenMinutes_returnsOffline() {
        let fifteenMinutesAgo = Date().addingTimeInterval(-900)
        let result = sut.execute(lastUpdated: fifteenMinutesAgo)
        #expect(result == .offline)
    }

    @Test func justUnderFiveMinutes_returnsOnline() {
        let justUnder = Date().addingTimeInterval(-299)
        let result = sut.execute(lastUpdated: justUnder)
        #expect(result == .online)
    }

    @Test func justUnderFifteenMinutes_returnsStale() {
        let justUnder = Date().addingTimeInterval(-899)
        let result = sut.execute(lastUpdated: justUnder)
        #expect(result == .stale)
    }
}
