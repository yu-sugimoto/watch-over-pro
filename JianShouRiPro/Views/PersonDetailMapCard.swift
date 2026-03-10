import SwiftUI
import MapKit

struct PersonDetailMapCard: View {
    let person: WatchPerson
    let remoteData: RemoteGaitData?
    @Binding var mapPosition: MapCameraPosition

    private var latitude: Double? { remoteData?.latitude ?? person.latitude }
    private var longitude: Double? { remoteData?.longitude ?? person.longitude }

    var body: some View {
        if let lat = latitude, let lon = longitude {
            Map(position: $mapPosition) {
                Annotation(person.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: person.colorHex))
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: person.colorHex).opacity(0.4), radius: 8, y: 2)
                        Image(systemName: person.relationship.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text("現在地")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .padding(14)
            }
            .overlay(alignment: .bottomTrailing) {
                if let timestamp = remoteData?.timestamp {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(timestamp, style: .relative)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(14)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: person.colorHex))
                        .frame(width: 10, height: 10)
                    Text(person.name)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .padding(14)
            }
        } else {
            Color(.secondarySystemGroupedBackground)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundStyle(.quaternary)
                        Text("位置情報がありません")
                            .font(.subheadline.weight(.medium))
                        Text("見守られる側のアプリがペアリングされると\n位置情報がここに表示されます")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
        }
    }
}
