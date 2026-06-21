// CreateProductView.swift — Form to register a new product on the platform.

import SwiftUI
import Combine

final class CreateProductViewModel: ObservableObject {
    @Published var category = "smartphone"
    @Published var brand = ""
    @Published var model = ""
    @Published var condition = "new"
    @Published var identifier = ""
    @Published var notes = ""
    @Published var hasTerms = false
    @Published var purchaseTerms = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success = false
    @Published var showScanner = false

    var canSubmit: Bool { !brand.isEmpty && !model.isEmpty && !identifier.isEmpty }

    func submit() async {
        guard !identifier.isEmpty else {
            errorMessage = "يجب إدخال رقم IMEI أو الرقم التسلسلي."
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.request(
                .createProduct(
                    category: category, brand: brand, model: model,
                    condition: condition,
                    identifier: identifier,
                    notes: notes.isEmpty ? nil : notes,
                    purchaseTerms: (hasTerms && !purchaseTerms.isEmpty) ? purchaseTerms : nil
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
        ("new", "جديد"), ("used", "مستعمل"),
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

                        // Single identifier field + barcode scanner
                        VStack(alignment: .leading, spacing: 8) {
                            Text("معرّف الجهاز (مطلوب)").font(.tCaption).foregroundColor(.tSubtext)
                            Text("IMEI أو الرقم التسلسلي — حتى 25 حرفاً")
                                .font(.tSmall).foregroundColor(.tSubtext.opacity(0.7))

                            HStack(spacing: 10) {
                                TField(label: "", placeholder: "أدخل IMEI أو الرقم التسلسلي", text: $vm.identifier)
                                    .onChange(of: vm.identifier) { newVal in
                                        if newVal.count > 25 {
                                            vm.identifier = String(newVal.prefix(25))
                                        }
                                    }

                                Button {
                                    vm.showScanner = true
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "barcode.viewfinder")
                                            .font(.system(size: 22))
                                        Text("مسح").font(.tSmall)
                                    }
                                    .foregroundColor(.tPrimary)
                                    .frame(width: 64, height: 56)
                                    .background(Color.tPrimary.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tPrimary.opacity(0.3), lineWidth: 1))
                                }
                            }

                            if !vm.identifier.isEmpty {
                                Text("\(vm.identifier.count) / 25")
                                    .font(.tSmall)
                                    .foregroundColor(vm.identifier.count > 20 ? .tWarning : .tSubtext)
                            }
                        }

                        // Notes (optional)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ملاحظات (اختياري)").font(.tCaption).foregroundColor(.tSubtext)
                            ZStack(alignment: .topLeading) {
                                if vm.notes.isEmpty {
                                    Text("أي ملاحظات إضافية عن الجهاز...")
                                        .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                        .padding(.horizontal, 14).padding(.top, 18)
                                }
                                TextEditor(text: $vm.notes)
                                    .font(.tBody).frame(height: 80)
                                    .padding(10).background(Color.clear)
                                    .scrollContentBackground(.hidden)
                            }
                            .background(Color.tSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                        }

                        // Purchase terms
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                vm.hasTerms.toggle()
                                if !vm.hasTerms { vm.purchaseTerms = "" }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: vm.hasTerms ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundColor(vm.hasTerms ? .tPrimary : .tSubtext)
                                    Text("يوجد شروط للشراء").font(.tBody).foregroundColor(.tText)
                                }
                            }

                            if vm.hasTerms {
                                ZStack(alignment: .topLeading) {
                                    if vm.purchaseTerms.isEmpty {
                                        Text("اكتب شروط الشراء هنا...")
                                            .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                            .padding(.horizontal, 14).padding(.top, 18)
                                    }
                                    TextEditor(text: $vm.purchaseTerms)
                                        .font(.tBody).frame(height: 110)
                                        .padding(10).background(Color.clear)
                                        .scrollContentBackground(.hidden)
                                }
                                .background(Color.tSurface).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                            }
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
                        .disabled(vm.isLoading || !vm.canSubmit)
                        .opacity(!vm.canSubmit ? 0.6 : 1)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                }
            }
            .navigationTitle("تسجيل شراء منتج جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .onChange(of: vm.success) { if $0 { dismiss() } }
            .sheet(isPresented: $vm.showScanner) {
                BarcodeScannerSheet(scannedCode: $vm.identifier)
            }
        }
    }
}
