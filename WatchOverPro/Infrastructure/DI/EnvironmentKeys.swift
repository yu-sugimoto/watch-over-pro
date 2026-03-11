import SwiftUI

// MARK: - Location Repository

struct LocationRepositoryKey: EnvironmentKey {
    static let defaultValue: any LocationRepositoryProtocol = AppSyncLocationRepository()
}

extension EnvironmentValues {
    var locationRepository: any LocationRepositoryProtocol {
        get { self[LocationRepositoryKey.self] }
        set { self[LocationRepositoryKey.self] = newValue }
    }
}

// MARK: - Family Repository

struct FamilyRepositoryKey: EnvironmentKey {
    static let defaultValue: any FamilyRepositoryProtocol = AppSyncFamilyRepository()
}

extension EnvironmentValues {
    var familyRepository: any FamilyRepositoryProtocol {
        get { self[FamilyRepositoryKey.self] }
        set { self[FamilyRepositoryKey.self] = newValue }
    }
}

// MARK: - Pairing Repository

struct PairingRepositoryKey: EnvironmentKey {
    static let defaultValue: any PairingRepositoryProtocol = AppSyncPairingRepository()
}

extension EnvironmentValues {
    var pairingRepository: any PairingRepositoryProtocol {
        get { self[PairingRepositoryKey.self] }
        set { self[PairingRepositoryKey.self] = newValue }
    }
}

// MARK: - Auth Repository

struct AuthRepositoryKey: EnvironmentKey {
    static let defaultValue: any AuthRepositoryProtocol = CognitoAuthRepository()
}

extension EnvironmentValues {
    var authRepository: any AuthRepositoryProtocol {
        get { self[AuthRepositoryKey.self] }
        set { self[AuthRepositoryKey.self] = newValue }
    }
}
