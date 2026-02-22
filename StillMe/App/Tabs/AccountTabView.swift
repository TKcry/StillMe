import SwiftUI
import FirebaseAuth
import Combine

struct AccountTabView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    @State private var showingEditProfile = false
    @State private var showingAddPair = false
    @State private var showingSignOutAlert = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Section
                        VStack(spacing: Spacing.md) {
                            // Avatar Display
                            AvatarSection()
                            
                            // Name & Handle Display
                            VStack(spacing: 4) {
                                Text(self.appViewModel.profile.name)
                                    .font(Typography.h2)
                                    .foregroundColor(.dsForeground)
                                
                                let handle = self.appViewModel.profile.handle
                                Text(handle.isEmpty || handle == "unassigned" ? NSLocalizedString("choose_handle_hint", comment: "") : "@\(handle)")
                                    .font(Typography.small)
                                    .foregroundColor(.dsMuted)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.bottom, 32)
                        
                        // General Section
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("account_section_general")
                                .font(Typography.bodyBold)
                                .foregroundColor(.dsForeground)
                                .padding(.horizontal, 24)
                            
                            AppCard(padding: 0, cornerRadius: Radius.lg) {
                                VStack(spacing: 0) {
                                    // Profile Row
                                    NavigationLink(destination: EditProfileView().environmentObject(appViewModel)) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "person.circle")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsForeground)
                                                .frame(width: 24)
                                            
                                            Text("account_profile_edit")
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
                                    
                                    // Account Management Row
                                    NavigationLink(destination: AccountManagementView().environmentObject(appViewModel)) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "gearshape")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsForeground)
                                                .frame(width: 24)
                                            
                                            Text("account_management_title")
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
                                    
                                    // Privacy Row
                                    NavigationLink(destination: PrivacySettingsView().environmentObject(appViewModel)) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "eye.slash")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsForeground)
                                                .frame(width: 24)
                                            
                                            Text("account_section_privacy")
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
                                    
                                    // Notifications Row
                                    NavigationLink(destination: NotificationSettingsView().environmentObject(appViewModel)) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "bell")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsForeground)
                                                .frame(width: 24)
                                            
                                            Text("account_notification_settings")
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
                        }
                        .padding(.bottom, 24)
                        
                        // About App Section
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("account_section_about")
                                .font(Typography.bodyBold)
                                .foregroundColor(.dsForeground)
                                .padding(.horizontal, 24)
                            
                            AppCard(padding: 0, cornerRadius: Radius.lg) {
                                VStack(spacing: 0) {
                                    NavigationLink(destination: HelpSupportView()) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsForeground)
                                                .frame(width: 24)
                                            
                                            Text("account_help_support")
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
                                    
                                    // Sign Out in "About App" or as the last item in a group
                                    Button(action: {
                                        showingSignOutAlert = true
                                    }) {
                                        HStack(spacing: Spacing.md) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 18))
                                                .foregroundColor(.dsError)
                                                .frame(width: 24)
                                            
                                            Text("account_sign_out")
                                                .font(Typography.bodyBold)
                                                .foregroundColor(.dsError)
                                            
                                            Spacer()
                                        }
                                        .padding(16)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 32)
                        
                        // App Info
                        Text("StillMe v1.0.0")
                            .font(Typography.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                    }
                    .frame(maxWidth: 600) // Phase 257: Limit content width on iPad
                    .frame(maxWidth: .infinity) // Center the bounded content
                }
            }
            .navigationTitle("account_title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("account_sign_out_confirm_title", isPresented: $showingSignOutAlert) {
            Button("cancel", role: .cancel) { }
            Button("account_sign_out", role: .destructive) {
                appViewModel.signOut()
            }
        } message: {
            Text("account_sign_out_confirm_message")
        }
    }
    
    @ViewBuilder
    private func AvatarSection() -> some View {
        let uid = Auth.auth().currentUser?.uid ?? ""
        let updatedAt = self.appViewModel.profile.avatarUpdatedAt
        
        ZStack {
            if let image = self.appViewModel.loadAvatar(uid: uid, updatedAt: updatedAt) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.dsMutedDeep)
                }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.top, Spacing.xxxl)
    }
}

// MARK: - Components

