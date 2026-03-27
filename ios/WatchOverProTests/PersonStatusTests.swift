import Testing
@testable import WatchOverPro

struct PersonStatusTests {
    // MARK: - label

    @Test func onlineLabel() {
        #expect(PersonStatus.online.label == "オンライン")
    }

    @Test func offlineLabel() {
        #expect(PersonStatus.offline.label == "オフライン")
    }

    @Test func pausedLabel() {
        #expect(PersonStatus.paused.label == "共有停止中")
    }

    // MARK: - icon

    @Test func onlineIcon() {
        #expect(PersonStatus.online.icon == "checkmark.circle.fill")
    }

    @Test func offlineIcon() {
        #expect(PersonStatus.offline.icon == "wifi.slash")
    }

    @Test func pausedIcon() {
        #expect(PersonStatus.paused.icon == "pause.circle.fill")
    }
}
