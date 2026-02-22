import SwiftUI
import FirebaseAuth

struct AccountManagementView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                AppCard(padding: 0, cornerRadius: Radius.lg) {
                    VStack(spacing: 0) {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "person.badge.minus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.dsError)
                                    .frame(width: 24)
                                
                                Text("account_delete_account")
                                    .font(Typography.bodyBold)
                                    .foregroundColor(.dsError)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.dsMuted)
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer()
            }
        }
        .navigationTitle("account_management_title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("account_delete_confirm_title", isPresented: $showingDeleteAlert) {
            Button("cancel", role: .cancel) { }
            Button("account_delete_button", role: .destructive) {
                appViewModel.deleteAccount()
            }
        } message: {
            Text("account_delete_confirm_message")
        }
    }
}

#Preview {
    NavigationStack {
        AccountManagementView()
            .environmentObject(AppViewModel())
    }
}
