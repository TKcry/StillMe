import SwiftUI
import PhotosUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appViewModel: AppViewModel
    
    @State private var showingCropView = false
    @State private var imageToCrop: UIImage? = nil
    
    @State private var nickname: String = ""
    @State private var handle: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var uiImage: UIImage? = nil
    @State private var showingSourcePicker = false
    @State private var showingCamera = false
    @State private var cameraImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                
                VStack(spacing: Spacing.xxl) {
                    // 1. Avatar Section
                    Button {
                        showingSourcePicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            // Avatar Image
                            ZStack {
                                if let img = uiImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let img = appViewModel.loadAvatar(uid: Auth.auth().currentUser?.uid ?? "", updatedAt: appViewModel.profile.avatarUpdatedAt) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    ZStack {
                                        Circle().fill(Color.white.opacity(0.1))
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.dsMutedDeep)
                                    }
                                }
                            }
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            // Edit Icon
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                )
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.top, Spacing.xxl)
                    
                    // 2. Profile Section
                    VStack(spacing: Spacing.xl) {
                        // Nickname Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_profile_nickname")
                                .font(Typography.caption)
                                .foregroundColor(.dsMuted)
                                .padding(.leading, 4)
                            
                            TextField("", text: $nickname, prompt: Text("nickname_placeholder").foregroundColor(.dsMutedDeep))
                                .font(Typography.bodyMedium)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .foregroundColor(.dsForeground)
                        }
                        
                        // Handle Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_profile_handle")
                                .font(Typography.caption)
                                .foregroundColor(.dsMuted)
                                .padding(.leading, 4)
                            
                            let isCoolingDown = checkIsCoolingDown()
                            
                            HStack {
                                Text("@")
                                    .foregroundColor(.dsMuted)
                                TextField("", text: $handle, prompt: Text("username_placeholder").foregroundColor(.dsMutedDeep))
                                    .disabled(isCoolingDown)
                                    .keyboardType(.asciiCapable)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .submitLabel(.done)
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
                            .font(Typography.bodyMedium)
                            .padding()
                            .background(Color.white.opacity(isCoolingDown ? 0.02 : 0.05))
                            .cornerRadius(12)
                            .foregroundColor(isCoolingDown ? .dsMuted : .dsForeground)
                            
                            if isCoolingDown {
                                if let nextDate = nextChangeDate() {
                                    Text(String(format: NSLocalizedString("edit_profile_handle_cooldown_format", comment: ""), nextDate.formatted(date: .long, time: .omitted)))
                                        .font(Typography.extraSmall)
                                        .foregroundColor(.dsMuted)
                                        .padding(.leading, 4)
                                }
                            } else {
                                Text("edit_profile_handle_hint")
                                    .font(Typography.extraSmall)
                                    .foregroundColor(.dsMuted)
                                    .padding(.leading, 4)
                            }
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(Typography.extraSmall)
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.top, 4)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xxl)
                    
                    Spacer()
                }
                .padding(.top, Spacing.xl)
                .navigationTitle("edit_profile_title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("edit_profile_save") { saveProfile() }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.dsForeground)
                            .disabled(nickname.isEmpty)
                    }
                }
            }
            
            // Custom Action Sheet Overlay
            if showingSourcePicker {
                AvatarSourcePickerSheet(
                    isPresented: $showingSourcePicker,
                    onSelectCamera: {
                        showingSourcePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingCamera = true
                        }
                    },
                    onSelectLibrary: {
                        // Handled by PhotosPicker internally
                    },
                    pickedItem: $pickedItem
                )
            }
        }
        .onAppear {
            nickname = appViewModel.profile.name
            handle = appViewModel.profile.handle
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $cameraImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingCropView) {
            if let img = imageToCrop {
                AvatarCropView(image: img) {
                    showingCropView = false
                } onDone: { cropped in
                    uiImage = cropped
                    showingCropView = false
                }
            }
        }
        .onChange(of: pickedItem) { _, newItem in
            if let newItem = newItem {
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        imageToCrop = image
                        showingCropView = true
                        pickedItem = nil
                    }
                }
            }
        }
        .onChange(of: cameraImage) { _, newImage in
            if let newImage = newImage {
                imageToCrop = newImage
                showingCropView = true
                cameraImage = nil
            }
        }
    }
    
    private func checkIsCoolingDown() -> Bool {
        guard let lastUpdated = appViewModel.profile.handleUpdatedAt else { return false }
        let thirtyDays: TimeInterval = 30 * 24 * 3600
        return Date().timeIntervalSince(lastUpdated) < thirtyDays
    }
    
    private func nextChangeDate() -> Date? {
        guard let lastUpdated = appViewModel.profile.handleUpdatedAt else { return nil }
        return Calendar.current.date(byAdding: .day, value: 30, to: lastUpdated)
    }
    
    private func saveProfile() {
        errorMessage = nil
        isSaving = true
        
        Task {
            do {
                // 1. Update Profile (Nickname and Handle)
                try await appViewModel.pairStore.updateProfile(nickname: nickname, handle: handle)
                
                // 2. Update Avatar if changed
                if let newImg = uiImage {
                    appViewModel.uploadAvatar(newImg)
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch let error as PairStore.PairError {
                await MainActor.run {
                    isSaving = false
                    switch error {
                    case .invalidHandle:
                        errorMessage = NSLocalizedString("error_invalid_handle_detail", comment: "")
                    case .coolingDown:
                        errorMessage = NSLocalizedString("edit_profile_handle_cooldown_format", comment: "") // Note: format needs Date, but simplified here
                    case .handleTaken:
                        errorMessage = NSLocalizedString("error_handle_taken", comment: "")
                    default:
                        errorMessage = NSLocalizedString("failed_to_save_network", comment: "")
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Helper Views for the custom picker

struct AvatarSourcePickerSheet: View {
    @Binding var isPresented: Bool
    let onSelectCamera: () -> Void
    let onSelectLibrary: () -> Void
    @Binding var pickedItem: PhotosPickerItem?
    
    @State private var animate = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Dim
            Color.black.opacity(animate ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            // Content
            VStack(spacing: 8) {
                // Group 1: Actions
                VStack(spacing: 0) {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        PickerRow(title: NSLocalizedString("avatar_source_album", comment: "")) 
                    }
                    .buttonStyle(PickerButtonStyle())
                    .onChange(of: pickedItem) { _, _ in
                        dismiss()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button(action: onSelectCamera) {
                        PickerRow(title: NSLocalizedString("avatar_source_camera", comment: "")) 
                    }
                    .buttonStyle(PickerButtonStyle())
                }
                .background(Color.dsBackgroundLight)
                .cornerRadius(16)
                
                // Group 2: Cancel
                Button(action: dismiss) {
                    Text("edit_profile_cancel")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.dsBackgroundLight)
                        .cornerRadius(16)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .offset(y: animate ? 0 : 400)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                animate = true
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            animate = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

struct PickerRow: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
    }
}

struct PickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.white.opacity(0.1) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = img
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
