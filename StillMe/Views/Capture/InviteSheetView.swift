import SwiftUI

struct InviteSheetView: View {
    @EnvironmentObject var store: PairStore
    
    @State private var inviteInput: String = ""
    @State private var processingInvites: Set<String> = []
    
    var onClose: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 24) {
                        Button("button_create_invite_code") {
                            _ = store.createInvite()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        VStack(spacing: 8) {
                            HStack {
                                TextField("enter_code_placeholder", text: $inviteInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                Button("button_enter") {
                                    store.enterInviteCode(inviteInput)
                                    inviteInput = ""
                                }
                                .disabled(inviteInput.isEmpty)
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if !store.inbox.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("invites_section_title").font(.headline)
                                let sorted = store.inbox.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                                ForEach(sorted) { inv in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(String(format: NSLocalizedString("invite_from_format", comment: ""), inv.fromUid)).font(.subheadline)
                                        if let dt = inv.createdAt {
                                            Text(String(format: NSLocalizedString("created_at_format", comment: ""), dt.description)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                guard !processingInvites.contains(inv.id) else { return }
                                                processingInvites.insert(inv.id)
                                                Task {
                                                    defer { DispatchQueue.main.async { processingInvites.remove(inv.id) } }
                                                    do { try await store.acceptInvite(inv.id) } catch { /* optionally handle */ }
                                                }
                                            }) {
                                                if processingInvites.contains(inv.id) { ProgressView() } else { Text("button_accept") }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(processingInvites.contains(inv.id))

                                            Button(action: {
                                                guard !processingInvites.contains(inv.id) else { return }
                                                processingInvites.insert(inv.id)
                                                Task {
                                                    defer { DispatchQueue.main.async { processingInvites.remove(inv.id) } }
                                                    do { try await store.declineInvite(inv.id) } catch { /* optionally handle */ }
                                                }
                                            }) {
                                                if processingInvites.contains(inv.id) { ProgressView() } else { Text("button_decline") }
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(processingInvites.contains(inv.id))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("nav_title_invites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
