// ProfileView.swift — User profile, verification status, and logout.

import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var authState: AuthState
    @State private var showLogoutAlert = false
    @State private var showServerIPAlert = false
    @State private var pendingIP = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // ── Profile header ────────────────────────────────────
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.tPrimary.opacity(0.1))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: authState.user?.isBusiness == true
                                          ? "building.2.fill" : "person.fill")
                                    .font(.title).foregroundColor(.tPrimary)
                                )

                            Text(authState.user?.businessName ?? "مستخدم تواتر")
                                .font(.tTitle2).foregroundColor(.tText)

                            Text(authState.user?.userTypeLabel ?? "")
                                .font(.tCaption).foregroundColor(.tSubtext)

                            VerificationBadge(status: authState.user?.verificationStatus ?? "unverified")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20).background(Color.tBackground).cornerRadius(16)

                        // ── Account info ──────────────────────────────────────
                        VStack(spacing: 0) {
                            ProfileRow(icon: "calendar", label: "تاريخ الانضمام",
                                       value: authState.user?.dateJoined.formatted(date: .long, time: .omitted) ?? "—")
                            Divider().padding(.leading, 52)
                            ProfileRow(icon: "shield.checkered", label: "حالة التحقق",
                                       value: authState.user?.verificationBadge ?? "—")
                            Divider().padding(.leading, 52)
                            ProfileRow(icon: "tag", label: "نوع الحساب",
                                       value: authState.user?.userTypeLabel ?? "—")
                        }
                        .background(Color.tBackground).cornerRadius(12)

                        // ── About ─────────────────────────────────────────────
                        VStack(spacing: 0) {
                            ProfileRow(icon: "info.circle", label: "عن تواتر", value: "")
                            Divider().padding(.leading, 52)
                            ProfileRow(icon: "lock.shield", label: "سياسة الخصوصية", value: "")
                            Divider().padding(.leading, 52)
                            ProfileRow(icon: "doc.text", label: "الشروط والأحكام", value: "")
                        }
                        .background(Color.tBackground).cornerRadius(12)

                        // ── Developer settings ────────────────────────────────
                        VStack(spacing: 0) {
                            Button {
                                pendingIP = ServerConfig.shared.serverIP
                                showServerIPAlert = true
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "network")
                                        .font(.body).foregroundColor(.tPrimary)
                                        .frame(width: 22)
                                        .padding(.leading, 16)
                                    Text("عنوان الخادم").font(.tBody).foregroundColor(.tText)
                                    Spacer()
                                    Text(ServerConfig.shared.serverIP)
                                        .font(.tCaption).foregroundColor(.tSubtext)
                                    Image(systemName: "pencil").font(.tSmall).foregroundColor(.tSubtext.opacity(0.5))
                                        .padding(.trailing, 14)
                                }
                                .padding(.vertical, 14)
                            }
                        }
                        .background(Color.tBackground).cornerRadius(12)

                        // ── Logout ────────────────────────────────────────────
                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("تسجيل الخروج")
                            }
                            .font(.tBodyBold)
                            .foregroundColor(.tDanger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.tDanger.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("حسابي")
            .alert("تسجيل الخروج", isPresented: $showLogoutAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("تسجيل الخروج", role: .destructive) {
                    Task { await authState.logout() }
                }
            } message: {
                Text("هل أنت متأكد من تسجيل الخروج؟")
            }
            .alert("عنوان الخادم", isPresented: $showServerIPAlert) {
                TextField("مثال: 192.168.1.5", text: $pendingIP)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("حفظ") {
                    ServerConfig.shared.serverIP = pendingIP
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("أدخل IP الجهاز الذي يعمل عليه الخادم (نفس شبكة الواي فاي)")
            }
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body).foregroundColor(.tPrimary)
                .frame(width: 22)
                .padding(.leading, 16)
            Text(label).font(.tBody).foregroundColor(.tText)
            Spacer()
            if !value.isEmpty {
                Text(value).font(.tCaption).foregroundColor(.tSubtext)
            }
            Image(systemName: "chevron.left").font(.tSmall).foregroundColor(.tSubtext.opacity(0.4))
                .padding(.trailing, 14)
        }
        .padding(.vertical, 14)
    }
}
