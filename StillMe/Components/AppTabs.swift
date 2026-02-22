import SwiftUI

struct AppTabs<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selected: T
    let items: [T]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(Motion.standard) {
                        selected = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(Typography.small)
                        .foregroundColor(selected == item ? .white : .dsMuted)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selected == item {
                                    RoundedRectangle(cornerRadius: Radius.md)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Radius.md)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                        .matchedGeometryEffect(id: "tab", in: tabNamespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .cornerRadius(Radius.lg)
    }
    
    @Namespace private var tabNamespace
}
