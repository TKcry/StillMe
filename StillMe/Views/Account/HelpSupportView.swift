import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    AppCard(padding: 0, cornerRadius: Radius.lg) {
                        VStack(spacing: 0) {
                            // Help Center
                            Link(destination: URL(string: "https://stillme-legal-docs--stillme-6db26.us-east4.hosted.app/help")!) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 24)
                                    
                                    Text("help_faq_label")
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.dsMuted)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            
                            // Terms of Service
                            Link(destination: URL(string: "https://stillme-legal-docs--stillme-6db26.us-east4.hosted.app/terms")!) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 24)
                                    
                                    Text("help_terms_label")
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.dsMuted)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            
                            // Privacy Policy
                            Link(destination: URL(string: "https://stillme-legal-docs--stillme-6db26.us-east4.hosted.app/privacy")!) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "hand.raised")
                                        .font(.system(size: 18))
                                        .foregroundColor(.dsForeground)
                                        .frame(width: 24)
                                    
                                    Text("help_privacy_label")
                                        .font(Typography.bodyBold)
                                        .foregroundColor(.dsForeground)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
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
                    
                    Text("help_contact_hint")
                        .font(Typography.caption)
                        .foregroundColor(.dsMuted)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle("account_help_support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
