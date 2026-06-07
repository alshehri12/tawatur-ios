// CertificatesListView.swift — List of user's certificates + detail/PDF view.

import SwiftUI

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
                                Label("تحميل الشهادة PDF", systemImage: "arrow.down.doc.fill")
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
            PDFDownloadView(urlString: certificate.pdfUrl, title: certificate.certificateNumber)
        }
    }
}

// ── PDF Viewer ────────────────────────────────────────────────────────────────

struct PDFDownloadView: View {
    let urlString: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "doc.fill").font(.system(size: 60)).foregroundColor(.tPrimary)
                    Text("شهادة \(title)").font(.tHeadline).foregroundColor(.tText)
                    if let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            Label("فتح / مشاركة PDF", systemImage: "arrow.down.circle.fill")
                                .tPrimaryButton()
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle("تحميل PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }
}
