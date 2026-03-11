import SwiftUI
import MapKit

struct PersonDetailMapCard: View {
    let member: FamilyMember
    let location: CurrentLocation?
    @Binding var mapPosition: MapCameraPosition

    var body: some View {
        if let loc = location {
            Map(position: $mapPosition) {
                Annotation(member.displayName, coordinate: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: member.colorHex))
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: member.colorHex).opacity(0.4), radius: 8, y: 2)
                        Image(systemName: member.relationship.icon)
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
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(loc.updatedAt, style: .relative)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: member.colorHex))
                        .frame(width: 10, height: 10)
                    Text(member.displayName)
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
