import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("section_capture") {
                Text("capture_info_text")
                    .font(.subheadline)
            }

            Section("section_data_storage") {
                Text("data_storage_info_text")
                    .font(.footnote)
            }
        }
        .navigationTitle("settings_title")
    }
}
