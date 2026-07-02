import SwiftUI

struct RoomFilterView: View {
    @Binding var selectedRoom: String?
    let rooms: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    selectedRoom = nil
                } label: {
                    Text("All")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedRoom == nil ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(selectedRoom == nil ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(rooms, id: \.self) { room in
                    Button {
                        selectedRoom = room
                    } label: {
                        Text(room)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedRoom == room ? Color.accentColor : Color.secondary.opacity(0.15))
                            .foregroundStyle(selectedRoom == room ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}
