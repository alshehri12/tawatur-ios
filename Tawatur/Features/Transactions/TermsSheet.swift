// TermsSheet.swift — "الشروط والأحكام" popup: loads the same /terms/ page
// served to sellers on the public confirmation link, so there's one source
// of truth for the legal text instead of a second copy baked into the app.

import SwiftUI
import WebKit

struct TermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TermsWebView(url: ServerConfig.shared.rootURL.appendingPathComponent("terms/"))
                .navigationTitle("الشروط والأحكام")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.tSubtext)
                        }
                    }
                }
        }
    }
}

private struct TermsWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
