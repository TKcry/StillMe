import SwiftUI
import PhotosUI

struct OnboardingIconView: View {
    @EnvironmentObject var draft: OnboardingDraft
    var onNext: () -> Void
    var onBack: () -> Void
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showingCropView = false
    @State private var selectedImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header with Back Button
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.dsForeground.opacity(0.8))
                            .padding(12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Spacer()
                
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Text("icon_step_title")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.dsForeground)
                        
                        Text("icon_step_hint")
                            .font(.body)
                            .foregroundColor(.dsMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    
                    // Avatar Preview
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 160, height: 160)
                        
                        if let image = draft.avatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.dsMutedDeep)
                        }
                        
                        // Edit Overlay
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.dsBackground)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.2), radius: 4)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.dsForeground)
                            }
                        }
                        .offset(x: 55, y: 55)
                    }
                    
                    // Choose Photo Button (Visible if no photo yet)
                    if draft.avatarImage == nil {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("button_select_photo")
                                .font(Typography.bodyMedium.bold())
                                .foregroundColor(.dsForeground)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(100)
                        }
                    }
                }
                
                Spacer()
                
                // CTA Button
                Button {
                    onNext()
                } label: {
                    HStack {
                        Text(draft.avatarImage == nil ? "skip_label" : "next_label")
                            .font(Typography.small.bold())
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(draft.avatarImage == nil ? .dsMuted : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(draft.avatarImage == nil ? Color.white.opacity(0.1) : Color.white)
                    .cornerRadius(Radius.lg)
                }
                .buttonStyle(AppButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = image
                        self.showingCropView = true
                    }
                }
                selectedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showingCropView) {
            if let image = selectedImage {
                AvatarCropView(image: image) {
                    showingCropView = false
                } onDone: { cropped in
                    draft.avatarImage = cropped
                    showingCropView = false
                }
            }
        }
    }
}
