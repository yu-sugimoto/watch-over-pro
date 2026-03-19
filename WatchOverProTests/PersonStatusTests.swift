import Testing
@testable import WatchOverPro

struct PersonStatusTests {
    // MARK: - label

    @Test func onlineLabel() {
        #expect(PersonStatus.online.label == "オンライン")
    }

    @Test func staleLabel() {
        #expect(PersonStatus.stale.label == "更新なし")
    }

    @Test func offlineLabel() {
        #expect(PersonStatus.offline.label == "オフライン")
    }

    // MARK: - icon

    @Test func onlineIcon() {
        #expect(PersonStatus.online.icon == "checkmark.circle.fill")
    }

    @Test func staleIcon() {
        #expect(PersonStatus.stale.icon == "exclamationmark.triangle.fill")
    }

    @Test func offlineIcon() {
        #expect(PersonStatus.offline.icon == "wifi.slash")
    }
}
