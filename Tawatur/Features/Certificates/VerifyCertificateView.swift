// VerifyCertificateView.swift — Result of scanning a certificate QR code (or
// typing its number): is it a real Tawatur certificate, for which device, and
// how many owners it has had. Design: "نتيجة التحقق" in UIDesign/gallery.html.

import SwiftUI

struct VerifyCertificateView: View {
    let number: String
    var onDocumentPurchase: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var result: CertificateVerification?
    @State private var errorMessage: String?

    /// The QR holds ".../api/v1/verify/TWR-000128/" — accept that or a bare number.
    static func certificateNumber(from code: String) -> String {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: text),
           let i = url.pathComponents.firstIndex(of: "verify"),
           i + 1 < url.pathComponents.count {
            return url.pathComponents[i + 1]
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.tText)
                        .frame(width: 40, height: 40)
                        .background(Color.tSurface).clipShape(Circle())
                }
                .accessibilityLabel("إغلاق")
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16)

            ScrollView {
                VStack(spacing: 18) {
                    if let result {
                        hero(valid: result.isValid,
                             title: result.isValid ? "الشهادة صحيحة" : "الشهادة غير صالحة",
                             subtitle: result.verificationMessage)
                        details(result)
                        if result.isValid {
                            note("إذا كنت ستشتري هذا الجهاز، اطلب من البائع إثبات أنه المالك الحالي قبل الدفع.")
                        }
                    } else if let errorMessage {
                        hero(valid: false, title: "لم نتمكن من التحقق", subtitle: errorMessage)
                    } else {
                        ProgressView().tint(.tGreenDeep).padding(.top, 80)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }

            VStack(spacing: 8) {
                if result?.isValid == true, let onDocumentPurchase {
                    Button {
                        dismiss()
                        onDocumentPurchase()
                    } label: { Text("وثّق شراءك لهذا الجهاز").tPrimaryButton() }
                }
                Button("تم") { dismiss() }
                    .font(.tBodyBold).foregroundColor(.tGreenDeep)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(Color.tBackground)
        .task { await load() }
    }

    private func load() async {
        do {
            result = try await APIClient.shared.request(.verifyCertificate(number: number), as: CertificateVerification.self)
        } catch {
            errorMessage = "لا توجد شهادة صالحة بالرقم \(number). تأكد من الرمز وحاول مرة أخرى."
        }
    }

    private func hero(valid: Bool, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: valid ? "checkmark" : "xmark")
                .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(valid ? Color.tGreen : Color.tDanger).clipShape(Circle())
                .padding(12)
                .background(valid ? Color.tMint : Color.tDangerBg).clipShape(Circle())
            Text(title).font(.tTitle).foregroundColor(.tText).padding(.top, 8)
            Text(subtitle).font(.tBody).foregroundColor(.tSubtext).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func details(_ r: CertificateVerification) -> some View {
        let date = DateFormatter()
        date.locale = TFormat.locale
        date.dateFormat = "d MMMM yyyy"
        let rows: [(String, String)] = [
            ("رقم الشهادة", r.certificateNumber),
            ("الجهاز", "\(r.product.brand) \(r.product.model)"),
            ("الفئة", r.product.categoryDisplay),
            ("تاريخ الإصدار", date.string(from: r.issuedAt)),
            ("عدد الملاك", "\(r.product.totalOwners)"),
            ("سلامة سجل الملكية", "\(r.product.chainIntegrity)%"),
        ]
        return VStack(spacing: 0) {
            ForEach(rows, id: \.0) { key, value in
                HStack {
                    Text(key).foregroundColor(.tSubtext)
                    Spacer()
                    Text(verbatim: value).font(.tBodyBold).foregroundColor(.tText)
                }
                .font(.tBody)
                .padding(.vertical, 11)
                if key != rows.last?.0 { Divider().overlay(Color.tBorder) }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.tSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(.tGreenDeep)
            Text(text).font(.tCaption).foregroundColor(.tForest)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.tMint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
