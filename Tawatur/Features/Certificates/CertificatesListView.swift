// CertificatesListView.swift — List of user's certificates + detail/PDF view.

import SwiftUI
import PDFKit

struct CertificatesListView: View {

    @State private var certificates: [Certificate] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tSurface.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.tPrimary)
                } else if certificates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 48)).foregroundColor(.tSubtext.opacity(0.3))
                        Text("لا توجد شهادات بعد").font(.tBodyBold).foregroundColor(.tSubtext)
                        Text("ستظهر شهاداتك هنا بعد اكتمال أول معاملة توثيق")
                            .font(.tCaption).foregroundColor(.tSubtext).multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List(certificates) { cert in
                        NavigationLink(destination: CertificateDetailView(certificate: cert)) {
                            CertificateRow(certificate: cert)
                        }
                        .listRowBackground(Color.tBackground)
                        .listRowSeparatorTint(Color.tBorder)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("شهاداتي")
            .task {
                isLoading = true
                certificates = (try? await APIClient.shared.request(.myCertificates, as: [Certificate].self)) ?? []
                isLoading = false
            }
            .refreshable {
                certificates = (try? await APIClient.shared.request(.myCertificates, as: [Certificate].self)) ?? []
            }
        }
    }
}

struct CertificateRow: View {
    let certificate: Certificate
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: certificate.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title2)
                .foregroundColor(certificate.isValid ? .tSuccess : .tDanger)
                .frame(width: 44, height: 44)
                .background((certificate.isValid ? Color.tSuccess : Color.tDanger).opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(certificate.certificateNumber)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundColor(.tText)
                Text(certificate.certificateTypeDisplay)
                    .font(.tCaption).foregroundColor(.tSubtext)
                Text("\(certificate.productSummary.brand) \(certificate.productSummary.model)")
                    .font(.tSmall).foregroundColor(.tSubtext)
            }
            Spacer()
            Text(certificate.issuedAt, style: .date)
                .font(.tSmall).foregroundColor(.tSubtext)
        }
        .padding(.vertical, 6)
    }
}

// ── Certificate Detail ────────────────────────────────────────────────────────

struct CertificateDetailView: View {

    let certificate: Certificate
    @State private var showPDFSheet = false

    var body: some View {
        ZStack {
            Color.tSurface.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {

                    // Status icon
                    VStack(spacing: 10) {
                        Image(systemName: certificate.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundColor(certificate.isValid ? .tSuccess : .tDanger)

                        Text(certificate.isValid ? "شهادة صالحة" : "شهادة ملغاة")
                            .font(.tTitle2)
                            .foregroundColor(certificate.isValid ? .tSuccess : .tDanger)

                        Text(certificate.certificateTypeDisplay)
                            .font(.tBody).foregroundColor(.tSubtext)

                        // Certificate number badge
                        Text(certificate.certificateNumber)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.tPrimary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.tPrimary.opacity(0.08)).cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20).background(Color.tBackground).cornerRadius(16)

                    // Product details
                    VStack(spacing: 0) {
                        DetailRow(label: "المنتج", value: "\(certificate.productSummary.brand) \(certificate.productSummary.model)")
                        Divider().padding(.leading, 16)
                        DetailRow(label: "الفئة", value: certificate.productSummary.categoryDisplay)
                        Divider().padding(.leading, 16)
                        DetailRow(label: "درجة الثقة", value: "\(certificate.productSummary.trustScore)/100")
                        Divider().padding(.leading, 16)
                        DetailRow(label: "تاريخ الإصدار", value: certificate.issuedAt.formatted(date: .long, time: .shortened))
                    }
                    .background(Color.tBackground).cornerRadius(12)

                    // Actions
                    VStack(spacing: 10) {
                        if !certificate.pdfUrl.isEmpty {
                            Button { showPDFSheet = true } label: {
                                Label("عرض الشهادة PDF", systemImage: "doc.text.magnifyingglass")
                                    .tPrimaryButton()
                            }
                        }

                        ShareLink(item: certificate.verificationUrl) {
                            Label("مشاركة رابط التحقق", systemImage: "square.and.arrow.up")
                                .tSecondaryButton()
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("الشهادة")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPDFSheet) {
            PDFViewerSheet(urlString: certificate.pdfUrl, certificateNumber: certificate.certificateNumber)
        }
    }
}

// ── In-App PDF Viewer ─────────────────────────────────────────────────────────

struct PDFViewerSheet: View {
    let urlString: String
    let certificateNumber: String

    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?
    @State private var pdfData: Data?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(.tPrimary).scaleEffect(1.3)
                        Text("جاري تحميل الشهادة…")
                            .font(.tBody).foregroundColor(.tSubtext)
                    }
                } else if let doc = pdfDocument {
                    PDFKitView(document: doc)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48)).foregroundColor(.tDanger)
                        Text(loadError ?? "تعذّر تحميل الشهادة")
                            .font(.tBody).foregroundColor(.tSubtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                }
            }
            .navigationTitle(certificateNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }.foregroundColor(.tSubtext)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if pdfData != nil {
                        Button {
                            showingShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.tPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let url = tempPDFFileURL() {
                    ActivityShareSheet(items: [url])
                }
            }
            .task { await loadPDF() }
        }
    }

    private func loadPDF() async {
        guard let url = URL(string: urlString) else {
            loadError = "رابط الشهادة غير صالح"
            isLoading = false
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        if let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            pdfData = data
            pdfDocument = PDFDocument(data: data)
            if pdfDocument == nil {
                loadError = "الملف المستلم ليس PDF صالحاً"
            }
        } catch {
            loadError = "تعذّر تحميل الشهادة. تحقق من الاتصال بالشبكة."
        }
        isLoading = false
    }

    private func tempPDFFileURL() -> URL? {
        guard let data = pdfData else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(certificateNumber).pdf")
        try? data.write(to: url)
        return url
    }
}

// UIViewRepresentable wrapper so PDFView renders inside SwiftUI
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Color.tBackground)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// UIActivityViewController wrapper for sharing local files
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {}
}
