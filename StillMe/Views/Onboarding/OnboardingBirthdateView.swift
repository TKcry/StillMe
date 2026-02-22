import SwiftUI

struct OnboardingBirthdateView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var draft: OnboardingDraft
    @State private var birthdate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var isLoading = false
    @State private var showingConfirmAlert = false
    var onNext: () -> Void
    
    @State private var showingDatePicker = false
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Right Skip Link
                HStack {
                    Spacer()
                    Button {
                        onNext()
                    } label: {
                        Text("skip_label")
                            .font(Typography.small)
                            .foregroundColor(.dsMuted.opacity(0.8))
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 24)
                }
                
                Spacer()
                
                VStack(spacing: 0) {
                    // Centered Header
                    VStack(spacing: 8) {
                        Text("birthdate_optional_title")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.dsForeground)
                        
                        Text("birthdate_hint")
                            .font(.callout)
                            .foregroundColor(.dsMuted.opacity(0.6))
                            .lineSpacing(2)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                    
                    // Date Display Button (Centered, Minimalist)
                    GeometryReader { geo in
                        VStack(spacing: 8) {
                            Button {
                                showingDatePicker = true
                            } label: {
                                VStack(spacing: 6) {
                                    Text(birthdate, style: .date)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.dsForeground)
                                        .environment(\.locale, Locale(identifier: "en_US"))
                                    
                                    // Thin Underline
                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 1)
                                }
                            }
                            
                            Text("cannot_change_later_hint")
                                .font(Typography.caption)
                                .foregroundColor(.dsMuted.opacity(0.6))
                                .padding(.top, 8)
                        }
                        .frame(width: geo.size.width * 0.75)
                        .position(x: geo.size.width / 2, y: 30)
                    }
                    .frame(height: 60)
                }
                
                Spacer()
                Spacer()
                
                // CTA Button
                Button {
                    showingConfirmAlert = true
                } label: {
                    HStack {
                        Text("register_next_label")
                            .font(Typography.small.bold())
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(Color.white)
                    .cornerRadius(Radius.lg)
                }
                .buttonStyle(AppButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            
            if isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .navigationBarHidden(true)
        .alert("confirm_birthdate_title", isPresented: $showingConfirmAlert) {
            Button("cancel_label", role: .cancel) {}
            Button("register_label") {
                saveAndNext()
            }
        } message: {
            Text("confirm_birthdate_message")
        }
        .sheet(isPresented: $showingDatePicker) {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button("done_label") {
                            showingDatePicker = false
                        }
                        .font(Typography.bodyMedium.bold())
                        .foregroundColor(.dsForeground)
                    }
                    .padding()
                    
                    CustomDatePicker(selection: $birthdate)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .presentationDetents([.height(340)])
        }
    }
    
    private func saveAndNext() {
        draft.birthday = birthdate
        onNext()
    }
}
