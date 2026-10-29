// HomeView.swift — Dashboard. Order matters: what needs my reply first (buy
// requests naming me as the seller), then my purchases waiting for the seller,
// then recent completed operations. Design: "الرئيسية" in UIDesign/gallery.html
// — sizes and colours below follow that file's CSS.

import SwiftUI
import Combine
import UIKit

final class HomeViewModel: ObservableObject {
    @Published var pendingTransactions: [Transaction] = []
    @Published var completedTransactions: [Transaction] = []
    @Published var sellerRequests: [Transaction] = []
    @Published var devicesCount = 0
    @Published var certificatesCount = 0
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String?
    @Published var copiedId: String?

    var isEmpty: Bool { pendingTransactions.isEmpty && completedTransactions.isEmpty && sellerRequests.isEmpty }

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        async let txnsCall = APIClient.shared.request(.myTransactions, as: [Transaction].self)
        async let requestsCall = APIClient.shared.request(.pendingSellerRequests, as: [Transaction].self)
        async let productsCall = APIClient.shared.request(.myProducts, as: [Product].self)
        async let certificatesCall = APIClient.shared.request(.myCertificates, as: [Certificate].self)
        do {
            let txns = try await txnsCall
            // myTransactions includes both roles — pending-as-seller already has
            // its own card (sellerRequests), so exclude it to avoid duplicates.
            pendingTransactions   = txns.filter { $0.isPending && !$0.isSellerRole }
            completedTransactions = txns.filter { $0.isApproved }
                .sorted { ($0.approvedAt ?? $0.createdAt) > ($1.approvedAt ?? $1.createdAt) }
        } catch { errorMessage = error.localizedDescription }
        sellerRequests    = (try? await requestsCall) ?? []
        devicesCount      = (try? await productsCall)?.count ?? 0
        certificatesCount = (try? await certificatesCall)?.count ?? 0
    }

    /// The list endpoint doesn't carry the confirm link, so fetch the detail on demand.
    func copyConfirmLink(for txn: Transaction) async {
        do {
            let detail = try await APIClient.shared.request(.transactionDetail(id: txn.id), as: Transaction.self)
            guard let url = detail.confirmUrl else { errorMessage = "تعذّر جلب رابط التأكيد"; return }
            UIPasteboard.general.string = url
            copiedId = txn.id
            try? await Task.sleep(for: .seconds(2))
            if copiedId == txn.id { copiedId = nil }
        } catch { errorMessage = error.localizedDescription }
    }

    func reject(_ txn: Transaction) async {
        do {
            _ = try await APIClient.shared.request(.sellerRespond(id: txn.id, accept: false), as: Transaction.self)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct HomeView: View {

    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var router: TabRouter
    @StateObject private var vm: HomeViewModel
    private let loadsOnAppear: Bool

    @State private var path: [String] = []
    @State private var showNewPurchase = false
    @State private var openAfterPurchase: String?
    @State private var showNotifications = false
    @State private var rejecting: Transaction?
    @State private var showScanner = false
    @State private var scannedCode = ""
    @State private var verifyNumber: String?
    @State private var topInset: CGFloat = 0

    /// `loadsOnAppear: false` keeps injected sample data (Xcode previews).
    init(viewModel: HomeViewModel = HomeViewModel(), loadsOnAppear: Bool = true) {
        _vm = StateObject(wrappedValue: viewModel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 24) {
                        sellerRequestsSection
                        pendingSection
                        recentSection

                        if vm.hasLoaded && vm.isEmpty && vm.errorMessage == nil {
                            HomeEmptyState { showNewPurchase = true }
                        }
                        if vm.isLoading && !vm.hasLoaded {
                            ProgressView().tint(.tGreenDeep).padding(40)
                        }
                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color.tSurface)
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
            .refreshable { await vm.load() }
            .tTabRoot(TabRouter.home)
            .toolbar(.hidden, for: .navigationBar)
            .scrollEdgeEffectHidden(true, for: .top)
            .tStatusBar(.lightContent)   // white clock/battery over the forest band
            .navigationDestination(for: String.self) { id in
                TransactionDetailView(transactionId: id)
            }
            .fullScreenCover(isPresented: $showNewPurchase, onDismiss: {
                UIApplication.shared.statusBarStyle = .lightContent   // back on the forest band
                if let id = openAfterPurchase { openAfterPurchase = nil; path.append(id) }
                Task { await vm.load() }
            }) {
                NewPurchaseView { openAfterPurchase = $0 }
            }
            .sheet(isPresented: $showNotifications) {
                HomeNotificationsSheet(requests: vm.sellerRequests,
                                       completed: Array(vm.completedTransactions.prefix(5))) { id in
                    showNotifications = false
                    path.append(id)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showScanner, onDismiss: {
                guard !scannedCode.isEmpty else { return }
                verifyNumber = VerifyCertificateView.certificateNumber(from: scannedCode)
                scannedCode = ""
            }) {
                BarcodeScannerSheet(scannedCode: $scannedCode)
            }
            .sheet(isPresented: Binding(get: { verifyNumber != nil }, set: { if !$0 { verifyNumber = nil } })) {
                if let number = verifyNumber {
                    VerifyCertificateView(number: number) {
                        Task { try? await Task.sleep(for: .milliseconds(400)); showNewPurchase = true }
                    }
                }
            }
            .confirmationDialog("رفض طلب الشراء؟", isPresented: Binding(
                get: { rejecting != nil }, set: { if !$0 { rejecting = nil } }
            ), titleVisibility: .visible, presenting: rejecting) { txn in
                Button("رفض الطلب", role: .destructive) { Task { await vm.reject(txn) } }
                Button("رجوع", role: .cancel) {}
            } message: { txn in
                Text("لن تُنقل ملكية \(txn.productSummary.brand) \(txn.productSummary.model) ولن تصدر شهادة.")
            }
            .task { if loadsOnAppear { await vm.load() } }
        }
    }

    // ── Forest header band ───────────────────────────────────────────────────

    private var header: some View {
        let user = authState.user
        let hour = Calendar.current.component(.hour, from: .now)

        return VStack(alignment: .leading, spacing: 0) {
            // Avatar + greeting · bell
            HStack(spacing: 12) {
                Text(String(user?.firstName.prefix(1) ?? "ت"))
                    .font(.custom("ReadexPro-SemiBold", size: 18, relativeTo: .headline))
                    .foregroundColor(.tSandInk)
                    .frame(width: 46, height: 46)
                    .background(Color.tSand).clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) {
                        if user?.verificationStatus == "verified" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black)).foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.tGreen).clipShape(Circle())
                                .overlay(Circle().stroke(Color.tForest2, lineWidth: 2))
                        }
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(hour < 12 ? "صباح الخير" : "مساء الخير")
                        .font(.tCaption).foregroundColor(.tBandText)
                    Text(user?.firstName ?? "مستخدم تواتر")
                        .font(.custom("ReadexPro-SemiBold", size: 19, relativeTo: .title3))
                        .foregroundColor(.white)
                }
                Spacer()
                Button { showNotifications = true } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.1)).clipShape(Circle())
                        .overlay(alignment: .topLeading) {
                            if !vm.sellerRequests.isEmpty {
                                Circle().fill(Color(hex: "#FFB547"))
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Color.tForest2, lineWidth: 2))
                                    .padding(.top, 10).padding(.leading, 11)
                            }
                        }
                }
                .accessibilityLabel(vm.sellerRequests.isEmpty ? "الإشعارات" : "الإشعارات، يوجد طلب بانتظار ردّك")
            }
            .padding(.top, 8)

            // Stats
            HStack(alignment: .top, spacing: 0) {
                HomeStat(value: vm.devicesCount, label: "أجهزة باسمك")
                HomeStatDivider()
                HomeStat(value: vm.completedTransactions.count, label: "معاملات موثّقة")
                HomeStatDivider()
                HomeStat(value: vm.certificatesCount, label: "شهادات")
                Spacer(minLength: 0)
            }
            .padding(.top, 24)

            // Document a purchase · scan a certificate
            HStack(spacing: 10) {
                Button { showNewPurchase = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.tGreen).clipShape(Circle())
                        Text("وثّق عملية شراء")
                    }
                    .font(.tButton).foregroundColor(.tForest)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button { showScanner = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20, weight: .regular)).foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .accessibilityLabel("تحقق من شهادة")
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        // 64 leaves room for the first request card to overlap the band by 44.
        .padding(.bottom, vm.sellerRequests.isEmpty ? 28 : 64)
        // The band's gradient starts behind the status bar, like the design.
        .background(alignment: .top) { HomeBand(overscroll: 600 - topInset).padding(.top, -600) }
    }

    // ── Sections ─────────────────────────────────────────────────────────────

    @ViewBuilder private var sellerRequestsSection: some View {
        if !vm.sellerRequests.isEmpty {
            VStack(spacing: 12) {
                ForEach(Array(vm.sellerRequests.enumerated()), id: \.element.id) { index, txn in
                    SellerRequestHomeCard(
                        transaction: txn,
                        onReview: { path.append(txn.id) },
                        onReject: { rejecting = txn }
                    )
                    .shadow(color: index == 0 ? Color.tForest.opacity(0.12) : .clear, radius: 15, y: 12)
                }
            }
            .padding(.top, -44 - 24)   // overlap the band by 44 (24 is the stack spacing)
        }
    }

    @ViewBuilder private var pendingSection: some View {
        if !vm.pendingTransactions.isEmpty {
            VStack(spacing: 10) {
                TSectionTitle(title: "بانتظار البائع", count: vm.pendingTransactions.count)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.pendingTransactions) { txn in
                            PendingPurchaseCard(
                                transaction: txn,
                                isCopied: vm.copiedId == txn.id,
                                onCopy: { Task { await vm.copyConfirmLink(for: txn) } }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { path.append(txn.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2).padding(.bottom, 6)
                }
                .padding(.horizontal, -16)
            }
        }
    }

    @ViewBuilder private var recentSection: some View {
        if !vm.completedTransactions.isEmpty {
            let groups = recentGroups
            let lastId = groups.last?.items.last?.id
            VStack(spacing: 10) {
                TSectionTitle(title: "آخر المعاملات", actionTitle: "عرض الكل") {
                    router.selectedTab = TabRouter.transactions
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.title) { group in
                        Text(group.title)
                            .font(.tSmall.weight(.semibold)).foregroundColor(.tFaint)
                            .padding(.top, 12)
                        ForEach(group.items) { txn in
                            Button { path.append(txn.id) } label: {
                                RecentTransactionRow(transaction: txn)
                            }
                            .buttonStyle(.plain)
                            if txn.id != lastId { Rectangle().fill(Color.tBorder).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
                .tCard()
            }
        }
    }

    /// Latest operations grouped as "هذا الأسبوع" / month name.
    private var recentGroups: [(title: String, items: [Transaction])] {
        let monthFormatter = DateFormatter()
        monthFormatter.locale = TFormat.locale
        let calendar = Calendar.current
        var groups: [(title: String, items: [Transaction])] = []
        for txn in vm.completedTransactions.prefix(5) {
            let date = txn.approvedAt ?? txn.createdAt
            let title: String
            if calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear) {
                title = "هذا الأسبوع"
            } else {
                monthFormatter.dateFormat = calendar.isDate(date, equalTo: .now, toGranularity: .year) ? "MMMM" : "MMMM yyyy"
                title = monthFormatter.string(from: date)
            }
            if groups.last?.title == title { groups[groups.count - 1].items.append(txn) }
            else { groups.append((title, [txn])) }
        }
        return groups
    }
}

// ── Band background ───────────────────────────────────────────────────────────
// CSS: radial(120% 90% at top-left, green .32 → transparent 55%),
//      radial(80% 60% at bottom-right, green .14 → transparent 60%),
//      linear(160deg, forest-2 → forest). Drawn in physical coordinates.

private struct HomeBand: View {
    /// Extra height drawn above the screen (pull-to-refresh); the gradients are
    /// laid out over the visible part only, like the CSS box.
    let overscroll: CGFloat

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous)
        GeometryReader { geo in
            let w = geo.size.width
            let visible = max(geo.size.height - overscroll, 1)
            ZStack(alignment: .top) {
                Color.tForest2
                ZStack {
                    LinearGradient(colors: [.tForest2, .tForest],
                                   startPoint: UnitPoint(x: 0.33, y: 0), endPoint: UnitPoint(x: 0.67, y: 1))
                    // radial 120%×90% at top-left, fading out at 55% of the radius
                    EllipticalGradient(colors: [Color.tGreen.opacity(0.32), .clear],
                                       center: .center, startRadiusFraction: 0, endRadiusFraction: 0.55)
                        .frame(width: w * 2.4, height: visible * 1.8)
                        .position(x: 0, y: 0)
                    // radial 80%×60% at bottom-right, fading out at 60%
                    EllipticalGradient(colors: [Color.tGreen.opacity(0.14), .clear],
                                       center: .center, startRadiusFraction: 0, endRadiusFraction: 0.6)
                        .frame(width: w * 1.6, height: visible * 1.2)
                        .position(x: w, y: visible)
                }
                .frame(width: w, height: visible)
                .clipped()
                .offset(y: overscroll)
            }
        }
        .clipShape(shape)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// ── Sub-components ────────────────────────────────────────────────────────────

private struct HomeStat: View {
    let value: Int
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(value)")
                .font(.tNumber).foregroundColor(.white)
            Text(label).font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                .foregroundColor(.tBandText)
        }
    }
}

private struct HomeStatDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 56)
            .padding(.leading, 22).padding(.trailing, 22)
    }
}

private struct SellerRequestHomeCard: View {
    let transaction: Transaction
    let onReview: () -> Void
    let onReject: () -> Void

    private var device: String { "\(transaction.productSummary.brand) \(transaction.productSummary.model)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StatusFlag(text: "يحتاج ردّك")
                Spacer()
                Text(TFormat.relative(transaction.createdAt))
                    .font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                    .foregroundColor(.tFaint)
            }
            HStack(spacing: 12) {
                DeviceIcon(category: transaction.productSummary.categoryDisplay)
                Text("\(Text(transaction.counterpartyName ?? "مشترٍ").font(.custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline)).foregroundStyle(Color.tText)) يريد توثيق شرائه جهازك \(Text(device).font(.custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline)).foregroundStyle(Color.tText))")
                    .font(.custom("IBMPlexSansArabic-Regular", size: 14, relativeTo: .subheadline))
                    .foregroundColor(.tSubtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let price = transaction.price { PriceText(value: price, font: .custom("ReadexPro-SemiBold", size: 17, relativeTo: .body)) }
            }
            HStack(spacing: 8) {
                Button(action: onReview) {
                    Text("مراجعة وتأكيد البيع")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.tForest).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button(action: onReject) {
                    Text("رفض")
                        .padding(.horizontal, 18)
                        .frame(minHeight: 46)
                        .background(Color.tSurface).foregroundColor(.tText)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .font(.custom("IBMPlexSansArabic-SemiBold", size: 15, relativeTo: .body))
        }
        .padding(16)
        .tCard()
    }
}

private struct PendingPurchaseCard: View {
    let transaction: Transaction
    let isCopied: Bool
    let onCopy: () -> Void

    private var fractionLeft: Double {
        let total = transaction.expiresAt.timeIntervalSince(transaction.createdAt)
        guard total > 0 else { return 0 }
        return transaction.expiresAt.timeIntervalSinceNow / total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(transaction.productSummary.brand) \(transaction.productSummary.model)")
                        .font(.tBodyBold).foregroundColor(.tText).lineLimit(1)
                    Text("البائع: \(transaction.counterpartyName ?? "—")")
                        .font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.tFaint).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let price = transaction.price { PriceText(value: price, font: .custom("ReadexPro-SemiBold", size: 17, relativeTo: .body)) }
            }
            VStack(spacing: 6) {
                HStack {
                    Text("صلاحية الرابط")
                    Spacer()
                    Text(TFormat.remaining(until: transaction.expiresAt))
                        .font(.custom("ReadexPro-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundColor(.tWarning)
                }
                .font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                .foregroundColor(.tSubtext)
                TProgressBar(fraction: fractionLeft)
            }
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark" : "link").font(.system(size: 15, weight: .medium))
                    Text(isCopied ? "تم النسخ" : "نسخ رابط التأكيد")
                }
                .font(.custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isCopied ? Color.tGreen : Color.tMint)
                .foregroundColor(isCopied ? .white : .tGreenDeep)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .animation(.easeOut(duration: 0.15), value: isCopied)
        }
        .padding(16)
        .frame(width: 250)
        .tCard()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.tBorder, lineWidth: 1))
    }
}

private struct RecentTransactionRow: View {
    let transaction: Transaction

    private var subtitle: String {
        let name = transaction.counterpartyName ?? ""
        let who = name.isEmpty ? transaction.roleLabel
            : transaction.isSellerRole ? "بيع إلى \(name)" : "شراء من \(name)"
        return "\(who) · \(TFormat.day(transaction.approvedAt ?? transaction.createdAt))"
    }

    var body: some View {
        HStack(spacing: 12) {
            DeviceIcon(category: transaction.productSummary.categoryDisplay,
                       sold: transaction.isSellerRole, size: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(transaction.productSummary.brand) \(transaction.productSummary.model)")
                    .font(.tBodyBold).foregroundColor(.tText).lineLimit(1)
                Text(subtitle)
                    .font(.custom("IBMPlexSansArabic-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundColor(.tSubtext).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let price = transaction.price { PriceText(value: price, font: .custom("ReadexPro-SemiBold", size: 15, relativeTo: .body)) }
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal").font(.system(size: 11, weight: .semibold))
                    Text("شهادة")
                }
                .font(.custom("IBMPlexSansArabic-SemiBold", size: 11, relativeTo: .caption2))
                .foregroundColor(.tGreenDeep)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

private struct HomeEmptyState: View {
    let onCreate: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30)).foregroundColor(.tGreenDeep)
                .frame(width: 72, height: 72)
                .background(Color.tMint).clipShape(Circle())
            Text("لا توجد معاملات بعد").font(.tHeadline).foregroundColor(.tText)
            Text("وثّق أول جهاز تشتريه ليبدأ سجل ملكيتك الموثّق.")
                .font(.tCaption).foregroundColor(.tSubtext).multilineTextAlignment(.center)
            Button("وثّق عملية شراء", action: onCreate)
                .tPrimaryButton()
                .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .tCard()
    }
}

// ── Notifications (bell) ──────────────────────────────────────────────────────
// No notifications service yet, so the bell shows what already needs
// attention: buy requests waiting for my reply, then recently completed deals.

private struct HomeNotificationsSheet: View {
    let requests: [Transaction]
    let completed: [Transaction]
    let onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("الإشعارات").font(.tTitle2).foregroundColor(.tText)
                .padding(.top, 24)
            if requests.isEmpty && completed.isEmpty {
                Text("لا توجد إشعارات جديدة").font(.tBody).foregroundColor(.tSubtext)
                    .frame(maxWidth: .infinity).padding(.top, 40)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(requests) { txn in
                        row(txn, icon: "bell.badge", tint: .tWarning, bg: .tWarningBg,
                            title: "\(txn.counterpartyName ?? "مشترٍ") يريد توثيق شرائه جهازك \(txn.productSummary.model)",
                            time: txn.createdAt)
                    }
                    ForEach(completed) { txn in
                        row(txn, icon: "checkmark.seal", tint: .tGreenDeep, bg: .tMint,
                            title: "اكتمل توثيق \(txn.productSummary.brand) \(txn.productSummary.model) وصدرت الشهادة",
                            time: txn.approvedAt ?? txn.createdAt)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Color.tBackground)
    }

    private func row(_ txn: Transaction, icon: String, tint: Color, bg: Color, title: String, time: Date) -> some View {
        Button { onOpen(txn.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(tint)
                    .frame(width: 40, height: 40).background(bg).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.tBody).foregroundColor(.tText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(TFormat.relative(time)).font(.tSmall).foregroundColor(.tFaint)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
