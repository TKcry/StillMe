import SwiftUI

struct DayDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel // Phase 212.1
    @EnvironmentObject var records: RecordsStore
    let recordDateString: String
    private let imageStore = ImageStore()

    @State private var selection: String = ""
    private var dateIDs: [String] { records.allDatesSorted() }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selection) {
                ForEach(dateIDs, id: \.self) { id in
                    ZStack {
                        GeometryReader { geo in
                            VStack {
                                Spacer(minLength: 0)
                                // Photo card centered
                                if let record = records.records[id], let date = DateFormatter.yyyyMMdd.date(from: id) {
                                    if let path = record.windowImagePath, let image = imageStore.loadImage(at: path) {
                                        DetailImageCard(
                                            date: date,
                                            uiImage: image,
                                            momentPath: record.momentPath,
                                            overrideCaptureId: record.selectedCaptureId 
                                        )
                                            .padding(.horizontal)
                                    } else {
                                        Text("error_no_record_found")
                                            .foregroundStyle(.secondary)
                                            .padding()
                                    }
                                } else {
                                    Text("No record found")
                                        .foregroundStyle(.secondary)
                                        .padding()
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea(.container, edges: [])
                        }
                    }
                    .tag(id)
                    // MARK: - compareBlock (temporarily removed)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear {
                selection = dateIDs.contains(recordDateString) ? recordDateString : (dateIDs.first ?? recordDateString)
            }

            // Overlay header
            VStack(spacing: 4) {
                let dateStr = selection.isEmpty ? recordDateString : selection
                if let date = DateFormatter.yyyyMMdd.date(from: dateStr) {
                    Text(DateFormatter.displayDateJST.string(from: date))
                        .font(.title3.weight(.semibold))
                } else {
                    Text(dateStr)
                        .font(.title2.weight(.semibold))
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - baseImageForComparison(id:) temporarily retained for future use
    private func baseImageForComparison(id: String) -> UIImage? {
        guard let record = records.records[id] else { return nil }
        if let windowPath = record.windowImagePath, let image = imageStore.loadImage(at: windowPath) { return image }
        return nil
    }
}

struct DetailImageView: View {
    let title: String
    let uiImage: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).bold()
            FlexibleImage(image: uiImage)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 4)
    }
}

struct DetailImageCard: View {
    @EnvironmentObject var viewModel: AppViewModel 
    let date: Date
    let uiImage: UIImage
    var momentPath: String? = nil
    var overrideCaptureId: String? = nil 
    
    var body: some View {
        MomentPressPlayer(
            date: date,
            image: uiImage,
            momentPath: momentPath,
            cornerRadius: 12,
            overrideCaptureId: overrideCaptureId,
            exportState: viewModel.exportState 
        )
        .id(date.yyyyMMdd)
        .padding(.vertical, 4)
    }
}

struct CompareView: View {
    @EnvironmentObject var records: RecordsStore
    let baseDate: String
    let baseImage: UIImage
    @State private var compareDate: String?
    private let imageStore = ImageStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("compare_date_label", selection: Binding(get: {
                compareDate ?? baseDate
            }, set: { compareDate = $0 })) {
                ForEach(records.allDatesSorted(), id: \.self) { date in
                    Text(date).tag(date)
                }
            }
            .pickerStyle(.menu)

            HStack(alignment: .top) {
                VStack { Text(baseDate).font(.headline); FlexibleImage(image: baseImage) }
                if let compareDate, let compareImage = imageFor(dateString: compareDate) {
                    VStack { Text(compareDate).font(.headline); FlexibleImage(image: compareImage) }
                }
            }
        }
    }

    private func imageFor(dateString: String) -> UIImage? {
        guard let record = records.records[dateString] else { return nil }
        if let path = record.windowImagePath, let image = imageStore.loadImage(at: path) { return image }
        return nil
    }
}

struct FlexibleImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
    }
}
