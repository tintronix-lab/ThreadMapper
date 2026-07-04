import SwiftUI

struct RoomFilterView: View {
    @Binding var selectedRoom: String?
    let rooms: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", selected: selectedRoom == nil) {
                    selectedRoom = nil
                }
                ForEach(rooms, id: \.self) { room in
                    chip(title: room, selected: selectedRoom == room) {
                        selectedRoom = room
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
