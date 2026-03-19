import Testing
import Foundation
@testable import WatchOverPro

struct AlertTypeTests {
    @Test func knownRawValues_decodeCorrectly() {
        #expect(AlertType(rawValue: "location_stale") == .locationStale)
        #expect(AlertType(rawValue: "offline") == .offline)
        #expect(AlertType(rawValue: "stop_detected") == .stopDetected)
        #expect(AlertType(rawValue: "unknown") == .unknown)
    }

    @Test func unknownRawValue_decodesAsUnknown() throws {
        let json = #""some_future_alert""#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AlertType.self, from: data)
        #expect(decoded == .unknown)
    }

    @Test func validRawValue_decodesFromJSON() throws {
        let json = #""location_stale""#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AlertType.self, from: data)
        #expect(decoded == .locationStale)
    }
}
