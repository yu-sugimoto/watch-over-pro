import SwiftUI

struct AppModeSelectionView: View {
    let appModeManager: AppModeManager
    @State private var showWatchedSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    Image(systemName: "shield.checkered")
                        .font(.system(size: 64))
                        .foregroundStyle(.teal)
                        .symbolEffect(.pulse, options: .repeating.speed(0.3))

                    VStack(spacing: 8) {
                        Text("見守り Pro")
                            .font(.largeTitle.bold())
                        Text("このアプリの使い方を選んでください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        Button {
                            appModeManager.setMode(.watcher)
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(.blue.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "eye.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("見守る側")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("招待コードを入力して\n家族の位置情報を確認します")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showWatchedSetup = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(.orange.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "location.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("見守られる側")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("招待コードを発行して\n見守る側に共有します")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.secondary)
                        Text("すべてのデータは安全に暗号化されて送信されます。\n位置情報は見守り側のみが閲覧できます。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showWatchedSetup) {
                WatchedSetupView(appModeManager: appModeManager)
            }
        }
    }
}
