import SwiftUI
import UIKit
import FirebaseFirestore

struct PairListView: View {
  @EnvironmentObject var store: PairStore
  @State private var showInviteSheet: Bool = false
  @State private var unpairingPairIds: Set<String> = []
  @State private var lastPreviews: [String: (text: String, createdAt: Date?)] = [:]
  @State private var lastMessageListeners: [String: ListenerRegistration] = [:]
  
  var body: some View {
    NavigationStack {
      Group {
        ZStack {
          LinearGradient(
            colors: [Color.dsBackground, Color.dsBackgroundOuter],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .ignoresSafeArea()
          if store.pairRefs.isEmpty {
            VStack {
              Spacer()
              Text("No pairs yet")
                .foregroundStyle(.secondary)
                .padding()
              Spacer()
            }
          } else {
            List {
              ForEach(store.pairRefs) { ref in
                ZStack {
                  // Visible glass card
                  PairRowView(
                    name: ref.partnerDisplayName ?? ref.partnerUid,
                    lastMessage: lastMessagePreview(for: ref),
                    time: timeString(for: ref)
                  )
                  // Invisible full-row NavigationLink for tap
                  NavigationLink(destination: PairDetailView(pairId: ref.id).environmentObject(store)) { EmptyView() }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .labelsHidden()
                    .opacity(0.001)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
                .swipeActions(allowsFullSwipe: true) {
                  Button(role: .destructive) {
                    guard !unpairingPairIds.contains(ref.id) else { return }
                    unpairingPairIds.insert(ref.id)
                    Task { @MainActor in
                      defer { unpairingPairIds.remove(ref.id) }
                      do {
                        try await store.unpair(pairId: ref.id)
                        store.invalidatePairRefsFillToken()
                        store.pairRefs.removeAll { $0.id == ref.id }
                        store.postNotice("Unpaired successfully")
                      } catch let e as PairStore.PairError {
                        switch e {
                        case .alreadyProcessed:
                          store.invalidatePairRefsFillToken()
                          store.pairRefs.removeAll { $0.id == ref.id }
                          store.postNotice("Already unpaired")
                        case .forbidden:
                          store.postNotice("No permission to unpair")
                        default:
                          store.postNotice("Failed to unpair")
                        }
                      } catch {
                        store.postNotice("Unpairing failed: \(error.localizedDescription)")
                      }
                    }
                  } label: { Text("Unpair") }
                }
              }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
          }
        }
      }
      .navigationTitle("Pair")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showInviteSheet = true
          } label: {
            Image(systemName: "person.badge.plus")
          }
        }
      }
      .sheet(isPresented: $showInviteSheet) {
        InviteSheetView(onClose: { showInviteSheet = false })
          .environmentObject(store)
      }
      .onAppear {
        startAllLastMessageListeners()
      }
      .onDisappear {
        stopAllLastMessageListeners()
      }
      .onChange(of: store.pairRefs.map { $0.id }.joined(separator: ",")) { _, _ in
        stopAllLastMessageListeners()
        startAllLastMessageListeners()
      }
    }
  }
  
  private func lastMessagePreview(for ref: PairStore.PairRefItem) -> String {
    if let p = lastPreviews[ref.id], !p.text.isEmpty { return p.text }
    return "Sent a photo"
  }
  
  private func timeString(for ref: PairStore.PairRefItem) -> String {
    let dt = lastPreviews[ref.id]?.createdAt ?? ref.createdAt
    guard let dt else { return "" }
    let cal = Calendar.current
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US")
    if cal.isDateInToday(dt) {
      df.dateFormat = "HH:mm"
    } else {
      df.dateFormat = "MM/dd"
    }
    return df.string(from: dt)
  }
  
  private func unreadCount(for ref: PairStore.PairRefItem) -> Int { 0 }
  
  private func startLastMessageListener(for pairId: String) {
    let db = Firestore.firestore()
    if let l = lastMessageListeners[pairId] {
      l.remove()
      lastMessageListeners.removeValue(forKey: pairId)
    }
    let listener = db.collection("pairs").document(pairId).collection("messages")
      .order(by: "createdAt", descending: true)
      .limit(to: 1)
      .addSnapshotListener { snap, err in
        if let err = err {
          print("[PairView] last message listen error pairId=\(pairId) err=\(err)")
          return
        }
        guard let doc = snap?.documents.first else { return }
        let data = doc.data()
        let text = (data["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ts = (data["createdAt"] as? Timestamp)?.dateValue()
        DispatchQueue.main.async {
          self.lastPreviews[pairId] = (text: text, createdAt: ts)
        }
      }
    lastMessageListeners[pairId] = listener
  }
  
  private func stopAllLastMessageListeners() {
    for (_, l) in lastMessageListeners {
      l.remove()
    }
    lastMessageListeners.removeAll()
  }
  
  private func startAllLastMessageListeners() {
    let ids = store.pairRefs.map { $0.id }
    for id in ids {
      startLastMessageListener(for: id)
    }
  }
}

#Preview {
  NavigationStack { PairListView() }
    .environmentObject(PairStore.shared)
}

