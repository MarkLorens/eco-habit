//
//  CategoryDetailView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Activity, Category+Presentation, ActivityRow, Tokens,
//            MockActivityRepository (Repositories/)
//  Dipakai : DailyPracticesView
//
//  Satu view untuk keenam kategori. "Energy List", "Waste List", dan
//  "Consumption" di Sketch adalah layar yang sama dengan data berbeda.
//

import SwiftUI

struct CategoryDetailView: View {

    let category: Category

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    /// Pesan singkat saat pencatatan ditolak — sudah tercatat, kena cooldown,
    /// atau cap harian tercapai.
    @State private var notice: String?

    @State private var activities: [Activity] = []

    // Status selesai disimpan di `lastCompletedDate` milik Activity, bukan di
    // Set<String> terpisah. Dengan begitu `isCompletedToday` — yang sudah
    // membandingkan tanggal — yang menentukan centangnya, sehingga aturan
    // "reset tiap hari" berlaku otomatis termasuk saat app dibiarkan terbuka
    // melewati tengah malam.
    //
    // Yang BELUM ada: penyimpanan. Status ini hilang saat layar ditutup karena
    // mencatat aksi sungguhan butuh perhitungan poin, streak, cap harian, dan
    // dedup — semuanya ada di layer Service yang belum dibuat.

    @State private var searchQuery: String = ""

    @FocusState private var isSearchFocused: Bool

    /// Hasil pencarian. Kosongkan kolom cari untuk kembali ke daftar penuh.
    ///
    /// Dicocokkan ke nama aksi saja, tanpa `localizedCaseInsensitiveContains`
    /// pada kategori atau poin — mencari "10" lalu mendapat semua aksi F2 bukan
    /// yang diharapkan user saat mengetik di kolom bernama "Search".
    private var filteredActivities: [Activity] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activities }
        return activities.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Hasil akhir yang ditampilkan: yang belum dikerjakan di atas, yang sudah
    /// selesai hari ini turun ke bawah.
    ///
    /// Diurutkan lewat `enumerated()` dengan indeks asli sebagai penentu saat
    /// seri. `sorted(by:)` di Swift TIDAK dijamin stabil, jadi tanpa penentu itu
    /// aksi-aksi yang statusnya sama bisa bertukar tempat sendiri setiap kali
    /// daftar dihitung ulang — daftar akan terlihat "gelisah" tanpa sebab.
    private var displayedActivities: [Activity] {
        filteredActivities
            .enumerated()
            .sorted { lhs, rhs in
                let lhsDone = store.isCompletedToday(lhs.element.id)
                let rhsDone = store.isCompletedToday(rhs.element.id)
                if lhsDone != rhsDone { return !lhsDone }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Repository, bukan `MockActivityData` langsung — supaya saat ditukar
    /// Firebase, view ini tidak perlu disentuh.
    private let repository: ActivityRepositoryProtocol = MockActivityRepository()

    var body: some View {
        // Susunan lapisan mengikuti Sketch: warna kategori jadi latar seluruh
        // halaman, lalu lembar PUTIH di DEPAN menutupi area header dengan dua
        // sudut bawah membulat.
        ZStack(alignment: .top) {
            category.cardBackground
                .ignoresSafeArea()

            // Spasi NEGATIF: kartu pertama ditarik naik sehingga tepi atasnya
            // menyusup ke dalam lembar putih, seperti di Sketch. Kartu digambar
            // setelah header, jadi kartu ada di depan lembar putih itu.
            VStack(spacing: -Self.firstCardOverlap) {
                header
                    .padding(.horizontal, Tokens.Spacing.lg)
                    // Padding atas ditaruh DI DALAM, sebelum .background —
                    // kalau di luar, lembar putihnya ikut terdorong turun dan
                    // area status bar jadi berwarna.
                    .padding(.top, Tokens.Spacing.sm)
                    .padding(.bottom, Self.headerBottomInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(whiteHeaderSheet)

                ScrollView {
                    LazyVStack(spacing: Tokens.Spacing.md) {
                        ForEach(displayedActivities) { activity in
                            ActivityRow(
                                activity: activity,
                                isCompleted: store.isCompletedToday(activity.id),
                                onToggle: { logActivity(activity) }
                            )
                        }

                        if displayedActivities.isEmpty && !searchQuery.isEmpty {
                            emptySearchState
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.bottom, Tokens.Spacing.xxl)
                    // Urutan berubah ketika store mencatat aksi baru, jadi
                    // animasinya diikatkan ke sumber perubahannya.
                    .animation(.easeInOut(duration: 0.32), value: store.completedTodayIDs)
                }
                .scrollIndicators(.hidden)
                // Dipasang di ScrollView, BUKAN di view terluar: hanya di sini
                // inset-nya benar-benar menambah ruang di ujung daftar, sehingga
                // baris terakhir tidak tertutup kolom cari.
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: Tokens.Spacing.sm) {
                        if let notice {
                            Text(notice)
                                .textStyle(Tokens.Typography.footnote)
                                .foregroundStyle(Tokens.Palette.white)
                                .padding(.horizontal, Tokens.Spacing.lg)
                                .padding(.vertical, Tokens.Spacing.sm)
                                .background(Capsule().fill(Tokens.Semantic.text))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        searchBar
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadActivities()
        }
    }

    // MARK: - Bagian

    /// Lembar putih di depan yang menutupi area header, dengan dua sudut bawah
    /// membulat sehingga warna kategori di belakangnya mengintip di kiri-kanan.
    private var whiteHeaderSheet: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: Self.headerSheetRadius,
            bottomTrailingRadius: Self.headerSheetRadius,
            style: .continuous
        )
        .fill(Tokens.Palette.white)
        // Diteruskan ke atas supaya area status bar ikut putih.
        .ignoresSafeArea(edges: .top)
    }

    /// Diukur dari Sketch: warna mulai di y=258pt pada tepi kiri dan y=269pt pada
    /// 10,6pt ke dalam — lengkungnya sekitar 11pt yang terlihat sebelum tertutup
    /// kartu pertama. Nilai di bawah mendekati itu dengan gaya sudut continuous.
    private static let headerSheetRadius: CGFloat = 28

    /// Jarak dari akhir subjudul sampai tepi bawah lembar putih.
    /// Sketch: subjudul berakhir ~215pt, lembar putih berakhir ~265pt.
    private static let headerBottomInset: CGFloat = 50

    /// Seberapa jauh kartu pertama menyusup ke dalam lembar putih.
    /// Sketch: kartu mulai ~246pt sementara lembar putih baru berakhir ~265pt.
    private static let firstCardOverlap: CGFloat = 19

    // MARK: - Pencarian

    /// Kolom cari melayang di bawah, mengikuti Sketch.
    ///
    /// Dibuat sendiri, bukan `.searchable()`, karena dua alasan: layar ini
    /// menyembunyikan navigation bar demi header kustom sehingga `.searchable`
    /// tidak punya tempat untuk tampil, dan Sketch menempatkannya melayang di
    /// bawah — bukan menempel di bawah judul seperti perilaku bawaannya.
    /// Latarnya `.regularMaterial` supaya tetap terasa seperti komponen sistem.
    private var searchBar: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tokens.Semantic.footnote)

            TextField("Search", text: $searchQuery)
                .textFieldStyle(.plain)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { isSearchFocused = false }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Tokens.Semantic.footnote)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.md)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.bottom, Tokens.Spacing.sm)
        .padding(.top, Tokens.Spacing.md)
        .background(scrollFadeBackdrop)
        .animation(.easeInOut(duration: 0.15), value: searchQuery.isEmpty)
    }

    /// Kabut buram selebar layar di belakang kolom cari.
    ///
    /// Menjawab pilihan "tembus pandang vs blur": blur lebih baik. Kartu yang
    /// lewat di belakang kolom cari tetap terbaca sebagai bentuk, tapi teksnya
    /// tidak lagi bertabrakan dengan tulisan "Search" — itu sebabnya iOS memakai
    /// material, bukan transparansi biasa, di tab bar dan toolbar-nya.
    ///
    /// Masknya bergradasi supaya batas atasnya tidak terlihat sebagai garis:
    /// bening di atas, pekat di bawah, jadi kartu tampak memudar saat digulung
    /// alih-alih tiba-tiba terpotong.
    private var scrollFadeBackdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.7), location: 0.35),
                        .init(color: .black, location: 0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(edges: .bottom)
    }

    private var emptySearchState: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Text("Tidak ada aksi yang cocok")
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)

            Text("Coba kata lain, atau kosongkan kolom cari")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.xxl)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            backButton

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(category.shortTitle)
                        .textStyle(Tokens.Typography.hero)
                        .foregroundStyle(Tokens.Semantic.text)

                    Text(category.detailSubtitle)
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Tokens.Spacing.md)

                Image(category.mascotName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
            }
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Tokens.Semantic.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Tokens.Palette.white))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func loadActivities() async {
        do {
            let all = try await repository.fetchAllActivities()
            activities = all.filter { $0.category == category }
        } catch {
            // Mock repository tidak pernah gagal; blok ini ada untuk implementasi
            // Firebase nanti, yang bisa gagal karena jaringan.
            activities = []
        }
    }

    /// Mencatat aksi lewat AppStore. View tidak menghitung poin sendiri —
    /// seluruh aturan (dedup, cooldown, cap harian, streak, badge) ada di
    /// ActivityLoggingService, dan hasilnya tersimpan ke disk.
    ///
    /// Satu arah: aksi yang sudah tercatat hari ini tidak bisa dibatalkan,
    /// sesuai spec §3.3 — entry point lain cukup menampilkan "sudah tercatat".
    private func logActivity(_ activity: Activity) {
        guard !store.isCompletedToday(activity.id) else {
            showNotice("Sudah tercatat hari ini")
            return
        }

        Task {
            let result = await store.logActivity(activity)

            switch result {
            case .success(let outcome):
                if outcome.breakdown.wasCappedByDailyLimit {
                    showNotice("Cap harian tercapai — +\(outcome.breakdown.finalPoints) pts")
                } else if let badge = outcome.unlockedBadges.first {
                    showNotice("Badge terbuka: \(badge.name)")
                } else {
                    showNotice("+\(outcome.breakdown.finalPoints) pts")
                }

            case .alreadyLoggedToday:
                showNotice("Sudah tercatat hari ini")

            case .onCooldown(let remainingDays):
                showNotice("Bisa dicatat lagi dalam \(remainingDays) hari")

            case .activityNotFound:
                showNotice("Aksi tidak ditemukan")
            }
        }
    }

    private func showNotice(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { notice = text }

        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.2)) { notice = nil }
        }
    }
}

#Preview("Consumption") {
    NavigationStack {
        CategoryDetailView(category: .foodConsumption)
    }
    .environment(AppStore(store: InMemoryKeyValueStore()))
}

#Preview("Energy") {
    NavigationStack {
        CategoryDetailView(category: .energy)
    }
    .environment(AppStore(store: InMemoryKeyValueStore()))
}
