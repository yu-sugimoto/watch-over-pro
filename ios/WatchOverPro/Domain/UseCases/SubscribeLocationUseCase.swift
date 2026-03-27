import Foundation

struct SubscribeLocationUseCase: Sendable {
    private let repository: any LocationRepositoryProtocol

    init(repository: any LocationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(trackedUserId: String) -> AsyncThrowingStream<CurrentLocation, Error> {
        repository.subscribeLocationUpdates(trackedUserId: trackedUserId)
    }
}
