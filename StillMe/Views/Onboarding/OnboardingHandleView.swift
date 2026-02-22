import SwiftUI

struct OnboardingHandleView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var draft: OnboardingDraft
    @State private var handle: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    var onNext: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.dsForeground)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 0) {
                    // Centered Header
                    VStack(spacing: 8) {
                        Text("choose_handle_title")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.dsForeground)
                        
                        Text("choose_handle_hint")
                            .font(.callout)
                            .foregroundColor(.dsMuted.opacity(0.6))
                            .lineSpacing(2)
                    }
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                    
                    // Centered Minimalist Input
                    GeometryReader { geo in
                        VStack(spacing: 8) {
                            HStack(spacing: 0) {
                                Text("@")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.dsMutedDeep)
                                
                                TextField("", text: $handle, prompt: Text("username_placeholder").foregroundColor(.dsMutedDeep))
                                    .font(.system(size: 17, weight: .medium))
                                    .keyboardType(.asciiCapable)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .submitLabel(.next)
                                    .foregroundColor(.dsForeground)
                                    .tint(.white)
                                    .onChange(of: handle) { _, newValue in
                                        let filtered = newValue.replacingOccurrences(of: "@", with: "")
                                            .lowercased()
                                            .filter { "abcdefghijklmnopqrstuvwxyz0123456789_".contains($0) }
                                            .prefix(20)
                                        
                                        if String(filtered) != newValue {
                                            handle = String(filtered)
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                            }
                            .multilineTextAlignment(.center)
                            
                            // Thin Underline
                            Rectangle()
                                .fill(Color.white.opacity(handle.isEmpty ? 0.2 : 0.4))
                                .frame(height: 1)
                                .animation(.easeInOut, value: handle.isEmpty)
                            
                            // Helper Hints
                            VStack(alignment: .center, spacing: 4) {
                                Text("handle_chars_hint")
                                    .font(Typography.extraSmall)
                                    .foregroundColor(.dsMuted)
                                
                                Text("handle_change_limit_hint")
                                    .font(Typography.extraSmall)
                                    .foregroundColor(.dsMuted.opacity(0.7))
                            }
                            .padding(.top, 8)
                        }
                        .frame(width: geo.size.width * 0.75)
                        .position(x: geo.size.width / 2, y: 30)
                    }
                    .frame(height: 80)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(Typography.extraSmall)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 20)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                Spacer()
                
                // CTA Button (High Contrast)
                Button {
                    submit()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("next_label")
                                .font(Typography.small.bold())
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(isInvalid || isLoading ? Color.white.opacity(0.2) : Color.white)
                    .cornerRadius(Radius.lg)
                }
                .disabled(isInvalid || isLoading)
                .buttonStyle(AppButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            
            if isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !draft.handle.isEmpty {
                handle = draft.handle
            }
        }
    }
    
    private var isInvalid: Bool {
        let trimmed = handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 || trimmed.count > 20 { return true }
        let regex = try? NSRegularExpression(pattern: "^[a-z0-9_]{3,20}$")
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        return regex?.firstMatch(in: trimmed, options: [], range: range) == nil
    }
    
    private func submit() {
        let trimmed = handle.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check if handle is available
                let available = try await viewModel.pairStore.checkHandleAvailability(trimmed)
                
                await MainActor.run {
                    isLoading = false
                    if available {
                        draft.handle = trimmed
                        onNext()
                    } else {
                        errorMessage = NSLocalizedString("error_handle_taken", comment: "")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
