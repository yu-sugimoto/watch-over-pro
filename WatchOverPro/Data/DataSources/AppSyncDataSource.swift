import Foundation
import Amplify

final class AppSyncDataSource: Sendable {
    static let shared = AppSyncDataSource()

    private init() {}

    func query<T: Decodable>(
        _ document: String,
        variables: [String: Any] = [:]
    ) async throws -> T {
        let operationName = Self.extractOperationName(from: document)
        let request = GraphQLRequest<JSONValue>(
            document: document,
            variables: variables,
            responseType: JSONValue.self,
            decodePath: operationName
        )
        let result = try await Amplify.API.query(request: request)
        switch result {
        case .success(let jsonValue):
            let data = try JSONEncoder().encode(jsonValue)
            return try JSONDecoder().decode(T.self, from: data)
        case .failure(let error):
            throw AppSyncError.queryFailed(error.localizedDescription)
        }
    }

    func mutate<T: Decodable>(
        _ document: String,
        variables: [String: Any] = [:]
    ) async throws -> T {
        let operationName = Self.extractOperationName(from: document)
        let request = GraphQLRequest<JSONValue>(
            document: document,
            variables: variables,
            responseType: JSONValue.self,
            decodePath: operationName
        )
        let result = try await Amplify.API.mutate(request: request)
        switch result {
        case .success(let jsonValue):
            let data = try JSONEncoder().encode(jsonValue)
            return try JSONDecoder().decode(T.self, from: data)
        case .failure(let error):
            throw AppSyncError.mutationFailed(error.localizedDescription)
        }
    }

    func subscribe<T: Decodable & Sendable>(
        _ document: String,
        variables: [String: Any] = [:]
    ) -> AsyncThrowingStream<T, Error> {
        let operationName = Self.extractOperationName(from: document)
        let request = GraphQLRequest<JSONValue>(
            document: document,
            variables: variables,
            responseType: JSONValue.self,
            decodePath: operationName
        )
        nonisolated(unsafe) let sendableRequest = request
        return AsyncThrowingStream { continuation in
            let task = Task { @Sendable in
                let subscription = Amplify.API.subscribe(request: sendableRequest)
                do {
                    for try await event in subscription {
                        switch event {
                        case .connection:
                            break
                        case .data(let result):
                            switch result {
                            case .success(let jsonValue):
                                do {
                                    let data = try JSONEncoder().encode(jsonValue)
                                    let decoded = try JSONDecoder().decode(T.self, from: data)
                                    continuation.yield(decoded)
                                } catch {
                                    continuation.finish(throwing: error)
                                    return
                                }
                            case .failure(let error):
                                continuation.finish(throwing: AppSyncError.subscriptionFailed(error.localizedDescription))
                                return
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Extracts the GraphQL field name (e.g. "getFamily") from a document string.
    /// This is used as the `decodePath` so Amplify navigates into `data.<fieldName>`.
    static func extractOperationName(from document: String) -> String? {
        // Match pattern: `query|mutation|subscription Name(...) { fieldName(`
        // or simpler: first `{` followed by whitespace and the field name
        let pattern = #"\{\s*([a-zA-Z_]\w*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: document,
                range: NSRange(document.startIndex..., in: document)
              ),
              let range = Range(match.range(at: 1), in: document) else {
            return nil
        }
        return String(document[range])
    }
}

// MARK: - Errors

enum AppSyncError: Error, LocalizedError {
    case queryFailed(String)
    case mutationFailed(String)
    case subscriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .queryFailed(let msg): "Query failed: \(msg)"
        case .mutationFailed(let msg): "Mutation failed: \(msg)"
        case .subscriptionFailed(let msg): "Subscription failed: \(msg)"
        }
    }
}
