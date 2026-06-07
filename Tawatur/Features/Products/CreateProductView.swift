// CreateProductView.swift — Form to register a new product on the platform.

import SwiftUI
import Combine

final class CreateProductViewModel: ObservableObject {
    @Published var category = "smartphone"
    @Published var brand = ""
    @Published var model = ""
    @Published var condition = "good"
    @Published var imei1 = ""
    @Published var imei2 = ""
    @Published var serial = ""
    @Published var notes = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success = false

    var hasIdentifier: Bool { !imei1.isEmpty || !imei2.isEmpty || !serial.isEmpty }

    func submit() async {
        guard hasIdentifier else {
            errorMessage = "يجب إدخال رقم IMEI أو الرقم التسلسلي واحد على الأقل."
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.request(
                .createProduct(
                    category: category, brand: brand, model: model,
                    condition: condition,
                    imei1: imei1.isEmpty ? nil : imei1,
                    imei2: imei2.isEmpty ? nil : imei2,
                    serial: serial.isEmpty ? nil : serial,
                    notes: notes.isEmpty ? nil : notes
                ),
                as: Product.self
            )
            success = true
        } catch { errorMessage = error.localizedDescription }
    }
}

struct CreateProductView: View {

    @StateObject private var vm = CreateProductViewModel()
    @Environment(\.dismiss) private var dismiss

    let categories = [
        ("smartphone", "هاتف ذكي"),
        ("tablet", "جهاز لوحي"),
        ("laptop", "حاسوب محمول"),
        ("smartwatch", "ساعة ذكية"),
        ("gaming_console", "جهاز ألعاب"),
        ("camera", "كاميرا"),
    ]
    let conditions = [
        ("new", "جديد"), ("excellent", "ممتاز"),
        ("good", "جيد"), ("fair", "مقبول"), ("poor", "ضعيف"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("الفئة").font(.tCaption).foregroundColor(.tSubtext)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.0) { cat in
                                        Button { vm.category = cat.0 } label: {
                                            Text(cat.1)
                                                .font(.tCaption)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(vm.category == cat.0 ? Color.tPrimary : Color.tSurface)
                                                .foregroundColor(vm.category == cat.0 ? .white : .tText)
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }

                        TField(label: "الماركة", placeholder: "مثال: Apple", text: $vm.brand)
                        TField(label: "الموديل", placeholder: "مثال: iPhone 16 Pro", text: $vm.model)

                        // Condition picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("الحالة").font(.tCaption).foregroundColor(.tSubtext)
                            Picker("الحالة", selection: $vm.condition) {
                                ForEach(conditions, id: \.0) { c in Text(c.1).tag(c.0) }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Identifiers section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("المعرّفات (مطلوب واحد على الأقل)")
                                .font(.tCaption).foregroundColor(.tSubtext)
                            Text("تُستخدم للتحقق من هوية الجهاز ومنع التكرار")
                                .font(.tSmall).foregroundColor(.tSubtext.opacity(0.7))
                        }

                        TField(label: "IMEI 1 (للهواتف والأجهزة اللوحية)", placeholder: "15 رقم", text: $vm.imei1)
                            .keyboardType(.numberPad)
                        TField(label: "IMEI 2 (الشريحة الثانية - اختياري)", placeholder: "15 رقم", text: $vm.imei2)
                            .keyboardType(.numberPad)
                        TField(label: "الرقم التسلسلي", placeholder: "Serial Number", text: $vm.serial)

                        // Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ملاحظات (اختياري)").font(.tCaption).foregroundColor(.tSubtext)
                            TextEditor(text: $vm.notes)
                                .font(.tBody).frame(height: 80)
                                .padding(10).background(Color.tSurface).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                        }

                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger)
                                .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                        }

                        Button {
                            Task { await vm.submit() }
                        } label: {
                            if vm.isLoading {
                                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.tPrimary).cornerRadius(10)
                            } else { Text("تسجيل المنتج").tPrimaryButton() }
                        }
                        .disabled(vm.isLoading || vm.brand.isEmpty || vm.model.isEmpty || !vm.hasIdentifier)
                        .opacity((vm.brand.isEmpty || vm.model.isEmpty || !vm.hasIdentifier) ? 0.6 : 1)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                }
            }
            .navigationTitle("تسجيل منتج جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .onChange(of: vm.success) { if $0 { dismiss() } }
        }
    }
}
