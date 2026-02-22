import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appViewModel: AppViewModel
    
    // In a real app, these would be synced with a backend
    @AppStorage("notif_partner_capture") private var partnerCapture = true
    @AppStorage("notif_partner_request") private var partnerRequest = true
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    AppCard(padding: 0, cornerRadius: Radius.lg) {
                        VStack(spacing: 0) {
                            // Partner Capture Notification
                            Toggle(isOn: $partnerCapture) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 24)
                                    
                                    Text("account_notification_partner_capture")
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .dsSuccess))
                            .padding(16)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            
                            // Partner Request Notification
                            Toggle(isOn: $partnerRequest) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "person.badge.plus.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 24)
                                    
                                    Text("account_notification_partner_request")
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .dsSuccess))
                            .padding(16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
        }
        .navigationTitle("account_notification_settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
