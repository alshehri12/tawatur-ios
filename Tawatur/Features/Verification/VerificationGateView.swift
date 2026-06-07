// VerificationGateView.swift — Shown when a user is authenticated but has not
// yet submitted identity / CR data. Blocks access to the main app until done.

import SwiftUI
import Combine

struct VerificationGateView: View {

    @EnvironmentObject var authState: AuthState
    @StateObject private var vm = VerificationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(.tPrimary)

                    Text("التحقق من الهوية")
                        .font(.tTitle)
                        .foregroundColor(.tText)

                    Text("يجب إكمال التحقق من هويتك قبل البدء باستخدام المنصة")
                        .font(.tBody)
                        .foregroundColor(.tSubtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Show pending badge if already submitted
                    if authState.user?.identitySubmitted == true ||
                       authState.user?.crSubmitted == true {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.checkmark")
                            Text("بياناتك قيد المراجعة")
                        }
                        .font(.tBodyBold)
                        .foregroundColor(.tWarning)
                        .padding(14)
                        .background(Color.tWarning.opacity(0.1))
                        .cornerRadius(10)
                    }

                    Spacer()

                    if authState.user?.canTransact == false &&
                       authState.user?.identitySubmitted == false &&
                       authState.user?.crSubmitted == false {
                        NavigationLink(destination: VerificationView()) {
                            Text("ابدأ التحقق الآن").tPrimaryButton()
                        }
                        .padding(.horizontal, 24)
                    }

                    Button {
                        Task { await authState.logout() }
                    } label: {
                        Text("تسجيل الخروج")
                            .font(.tCaption)
                            .foregroundColor(.tSubtext)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// ── Verification form ─────────────────────────────────────────────────────────

final class VerificationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var success = false

    func submitIndividual(nationalId: String?, iqama: String?, authState: AuthState) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            struct R: Decodable { let verificationStatus: String }
            _ = try await APIClient.shared.request(
                .verifyIndividual(nationalId: nationalId, iqama: iqama), as: R.self)
            await authState.refreshProfile()
            success = true
        } catch { errorMessage = error.localizedDescription }
    }

    func submitBusiness(crNumber: String, businessName: String, authState: AuthState) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            struct R: Decodable { let verificationStatus: String }
            _ = try await APIClient.shared.request(
                .verifyBusiness(crNumber: crNumber, businessName: businessName), as: R.self)
            await authState.refreshProfile()
            success = true
        } catch { errorMessage = error.localizedDescription }
    }
}

struct VerificationView: View {
    @EnvironmentObject var authState: AuthState
    @StateObject private var vm = VerificationViewModel()
    @State private var nationalId = ""
    @State private var iqama = ""
    @State private var crNumber = ""
    @State private var businessName = ""

    var isIndividual: Bool { authState.user?.isIndividual ?? true }

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(isIndividual ? "التحقق من هويتك" : "التحقق من منشأتك")
                        .font(.tTitle).foregroundColor(.tText).padding(.top, 8)

                    if isIndividual {
                        TField(label: "رقم الهوية الوطنية", placeholder: "10 أرقام", text: $nationalId)
                            .keyboardType(.numberPad)
                        Text("أو").font(.tCaption).foregroundColor(.tSubtext).frame(maxWidth: .infinity)
                        TField(label: "رقم الإقامة", placeholder: "10 أرقام", text: $iqama)
                            .keyboardType(.numberPad)
                    } else {
                        TField(label: "رقم السجل التجاري", placeholder: "رقم السجل", text: $crNumber)
                        TField(label: "اسم المنشأة", placeholder: "اسم المنشأة", text: $businessName)
                    }

                    if let e = vm.errorMessage {
                        Text(e).font(.tCaption).foregroundColor(.tDanger)
                            .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                    }

                    Button {
                        Task {
                            if isIndividual {
                                await vm.submitIndividual(
                                    nationalId: nationalId.isEmpty ? nil : nationalId,
                                    iqama: iqama.isEmpty ? nil : iqama,
                                    authState: authState)
                            } else {
                                await vm.submitBusiness(crNumber: crNumber, businessName: businessName, authState: authState)
                            }
                        }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.tPrimary).cornerRadius(10)
                        } else { Text("تقديم البيانات").tPrimaryButton() }
                    }
                    .disabled(vm.isLoading)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("التحقق من الهوية")
        .navigationBarTitleDisplayMode(.inline)
    }
}
