// BarcodeScannerSheet.swift — Native barcode/QR scanner using VisionKit DataScannerViewController.
// Presented as a sheet. On detection, fills the bound string and dismisses automatically.

import SwiftUI
import VisionKit
import AVFoundation

// ── Public sheet entry point ──────────────────────────────────────────────────

struct BarcodeScannerSheet: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannerError: String?

    var body: some View {
        NavigationStack {
            Group {
                if !DataScannerViewController.isSupported {
                    unavailableView(message: "جهازك لا يدعم مسح الباركود.")
                } else if cameraPermission == .denied || cameraPermission == .restricted {
                    deniedView
                } else if scannerError != nil {
                    unavailableView(message: scannerError!)
                } else {
                    scannerContent
                }
            }
            .navigationTitle("مسح الباركود")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                        .foregroundColor(.tSubtext)
                }
            }
        }
        .task { await requestCameraPermissionIfNeeded() }
    }

    // ── Scanner content ───────────────────────────────────────────────────────

    private var scannerContent: some View {
        ZStack {
            DataScannerRepresentable(
                onScanned: { code in
                    scannedCode = code
                    dismiss()
                },
                onError: { msg in
                    scannerError = msg
                }
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()
                Text("وجّه الكاميرا نحو الباركود أو رمز QR")
                    .font(.tCaption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(10)
                    .padding(.bottom, 40)
            }
        }
    }

    // ── Camera denied view ────────────────────────────────────────────────────

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 48)).foregroundColor(.tSubtext)
            Text("لا يمكن الوصول إلى الكاميرا")
                .font(.tTitle2).foregroundColor(.tText)
            Text("يرجى السماح للتطبيق باستخدام الكاميرا من الإعدادات لمسح الباركود.")
                .font(.tBody).foregroundColor(.tSubtext).multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("فتح الإعدادات").tPrimaryButton()
            }
            .padding(.horizontal, 40)
        }
        .padding(32)
    }

    // ── Generic error view ────────────────────────────────────────────────────

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48)).foregroundColor(.tWarning)
            Text(message)
                .font(.tBody).foregroundColor(.tSubtext).multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // ── Permission helper ─────────────────────────────────────────────────────

    private func requestCameraPermissionIfNeeded() async {
        guard cameraPermission == .notDetermined else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermission = granted ? .authorized : .denied
        }
    }
}

// ── UIViewControllerRepresentable wrapper ─────────────────────────────────────

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        // Start scanning once after the view controller is placed in the hierarchy.
        guard !context.coordinator.hasStarted else { return }
        context.coordinator.hasStarted = true
        do {
            try vc.startScanning()
        } catch {
            onError("تعذّر تشغيل الكاميرا. حاول مرة أخرى.")
        }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController,
                                          coordinator: Coordinator) {
        vc.stopScanning()
    }

    // ── Coordinator ───────────────────────────────────────────────────────────

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let parent: DataScannerRepresentable
        var hasStarted = false
        private var didScan = false

        init(_ parent: DataScannerRepresentable) { self.parent = parent }

        // Auto-fill on first recognized item (no tap required)
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue, !value.isEmpty {
                    didScan = true
                    parent.onScanned(value)
                    return
                }
            }
        }

        // Also support tap-to-scan when highlighting is enabled
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            guard !didScan else { return }
            if case .barcode(let barcode) = item,
               let value = barcode.payloadStringValue, !value.isEmpty {
                didScan = true
                parent.onScanned(value)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            let msg: String
            switch error {
            case .unsupported:
                msg = "جهازك لا يدعم مسح الباركود."
            case .cameraRestricted:
                msg = "الكاميرا مقيّدة على هذا الجهاز."
            @unknown default:
                msg = "تعذّر تشغيل الكاميرا. حاول مرة أخرى."
            }
            parent.onError(msg)
        }
    }
}
