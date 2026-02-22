import SwiftUI

struct PairRowView: View {
    let name: String
    let lastMessage: String
    let time: String

    var body: some View {
        AppCard(padding: 16, cornerRadius: 22, backgroundColor: .black, borderColor: .black) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()

                Text(time)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.dsBackground.ignoresSafeArea()
        VStack(spacing: 12) {
            PairRowView(name: "Alex", lastMessage: "Sent a photo", time: "15:42")
            PairRowView(name: "Taylor", lastMessage: "Will it work tomorrow? Long messages are truncated at two lines with ellipsis when they overflow.", time: "01/12")
        }
        .padding()
    }
}
