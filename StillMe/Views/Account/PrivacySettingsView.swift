import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        ZStack {
            // Background
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        Text("account_privacy_hint")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.dsMuted)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        
                        AppCard(padding: 16, cornerRadius: Radius.lg) {
                            Toggle(isOn: Binding(
                                get: { appViewModel.profile.isPrivate },
                                set: { _ in appViewModel.togglePrivacy() }
                            )) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: appViewModel.profile.isPrivate ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 28)
                                    
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(appViewModel.profile.isPrivate ? "account_privacy_private" : "account_privacy_public")
                                                .font(Typography.bodyBold)
                                                .foregroundColor(.dsForeground)
                                            
                                            Text(appViewModel.profile.isPrivate ? "account_privacy_private_desc" : "account_privacy_public_desc")
                                                .font(Typography.caption)
                                                .foregroundColor(.dsMuted)
                                        }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .dsSuccess))
                        }
                        .padding(.horizontal, 24)
                        
                        Text("account_privacy_management")
                            .font(Typography.bodyBold)
                            .foregroundColor(.dsForeground)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                        
                        AppCard(padding: 0, cornerRadius: Radius.lg) {
                            VStack(spacing: 0) {
                                // Blocked Users
                                NavigationLink(destination: BlockedUsersView().environmentObject(appViewModel)) {
                                    HStack(spacing: Spacing.md) {
                                        Image(systemName: "person.slash")
                                            .font(.system(size: 18))
                                            .foregroundColor(.dsForeground)
                                            .frame(width: 24)
                                        
                                        Text("account_privacy_blocked_users")
                                            .font(Typography.bodyBold)
                                            .foregroundColor(.dsForeground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.dsMuted)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal, 16)
                                
                                // Hidden Pairs
                                NavigationLink(destination: HiddenPairsView().environmentObject(appViewModel)) {
                                    HStack(spacing: Spacing.md) {
                                        Image(systemName: "eye.slash")
                                            .font(.system(size: 18))
                                            .foregroundColor(.dsForeground)
                                            .frame(width: 24)
                                        
                                        Text("account_privacy_hidden_pairs")
                                            .font(Typography.bodyBold)
                                            .foregroundColor(.dsForeground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.dsMuted)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("account_section_privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PrivacySettingsView()
                .environmentObject(AppViewModel())
        }
    }
}
