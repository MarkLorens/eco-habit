# Panduan Setup Firebase — Eco-Habbit

Panduan langkah demi langkah untuk memindahkan layer data dari file JSON lokal ke
Firebase, mengikuti persis struktur yang sudah ada di kode.

**Prinsip utama:** kamu **tidak akan menyentuh satu pun file di `Views/`, `Components/`,
atau `Services/`.** Yang ditulis hanya satu file baru — `FirebaseRepositories.swift` —
yang memenuhi 7 protocol di `Repositories/RepositoryProtocols.swift`. Itulah alasan
semua method repository dibuat `async throws` sejak awal.

Estimasi waktu: 2–3 jam untuk yang belum pernah pakai Firebase.

---

## Daftar Isi

1. [Yang perlu disiapkan](#1-yang-perlu-disiapkan)
2. [Membuat project Firebase](#2-membuat-project-firebase)
3. [Menghubungkan ke Xcode](#3-menghubungkan-ke-xcode)
4. [Menyalakan Firestore dan Auth](#4-menyalakan-firestore-dan-auth)
5. [Struktur koleksi Firestore](#5-struktur-koleksi-firestore)
6. [Mengisi katalog awal](#6-mengisi-katalog-awal)
7. [Security Rules](#7-security-rules)
8. [Menulis FirebaseRepositories.swift](#8-menulis-firebaserepositoriesswift)
9. [Tiga jebakan yang pasti kamu temui](#9-tiga-jebakan-yang-pasti-kamu-temui)
10. [Menukar implementasi di AppStore](#10-menukar-implementasi-di-appstore)
11. [Menguji hasilnya](#11-menguji-hasilnya)
12. [Remote Config untuk angka balancing](#12-remote-config-untuk-angka-balancing)
13. [Yang perlu dipikirkan sebelum rilis](#13-yang-perlu-dipikirkan-sebelum-rilis)

---

## 1. Yang perlu disiapkan

- Akun Google
- Xcode (yang sudah dipakai sekarang)
- Bundle ID app. Punya kita: **`Ardhana.Eco-Habbit`**

Cek ulang bundle ID kalau ragu:

```bash
cd ~/Documents/eco-habit
grep -m1 PRODUCT_BUNDLE_IDENTIFIER Eco-Habbit.xcodeproj/project.pbxproj
```

---

## 2. Membuat project Firebase

1. Buka <https://console.firebase.google.com> lalu **Add project**
2. Nama project: `eco-habbit` (bebas, ini nama internal)
3. Google Analytics **boleh dimatikan** untuk sekarang — bisa dinyalakan nanti dan
   tidak ada hubungannya dengan yang kita bangun
4. Tunggu sampai selesai, lalu **Continue**

---

## 3. Menghubungkan ke Xcode

### 3a. Daftarkan app iOS

1. Di halaman depan project, klik ikon **iOS** (atau **Add app → iOS**)
2. **Apple bundle ID**: `Ardhana.Eco-Habbit` — harus **persis sama**, huruf besar-kecil berpengaruh
3. App nickname: bebas, misal `Eco-Habbit iOS`
4. **Register app**

### 3b. Unduh dan taruh `GoogleService-Info.plist`

1. Unduh file yang muncul di layar
2. Taruh di folder source app:

```
eco-habit/Eco-Habbit/Eco-Habbit/GoogleService-Info.plist
```

Project ini memakai **synchronized folder**, jadi file yang ditaruh di folder itu
otomatis masuk ke target Xcode — kamu **tidak perlu** drag ke Xcode maupun menyunting
`project.pbxproj`.

Verifikasi:

```bash
ls ~/Documents/eco-habit/Eco-Habbit/Eco-Habbit/GoogleService-Info.plist
```

> **Penting:** file ini berisi identitas project, bukan rahasia berbahaya, tapi tetap
> sebaiknya **jangan di-commit ke repo publik**. Tambahkan ke `.gitignore` kalau repo
> kalian nanti dibuka untuk umum.

### 3c. Tambahkan SDK lewat Swift Package Manager

1. Xcode → **File → Add Package Dependencies…**
2. Tempel URL:

```
https://github.com/firebase/firebase-ios-sdk
```

3. Dependency Rule: **Up to Next Major Version**
4. Klik **Add Package**, tunggu (agak lama, wajar)
5. Saat muncul daftar produk, centang **hanya dua ini**:
   - `FirebaseFirestore`
   - `FirebaseAuth`

   Jangan centang semuanya — tiap produk menambah ukuran app.
6. Target: **Eco-Habbit**, lalu **Add Package**

### 3d. Nyalakan Firebase saat app start

Sunting `Eco_HabbitApp.swift`:

```swift
import SwiftUI
import FirebaseCore          // ← tambahkan

@main
struct Eco_HabbitApp: App {

    @State private var store = AppStore()

    init() {
        FirebaseApp.configure()          // ← tambahkan, HARUS paling awal
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.bootstrap() }
        }
    }
}
```

Build dan jalankan. Kalau tidak crash, koneksinya sudah benar.

---

## 4. Menyalakan Firestore dan Auth

### 4a. Firestore

1. Console → **Build → Firestore Database → Create database**
2. Pilih **Start in production mode** (rules-nya kita isi sendiri di langkah 7)
3. Location: **`asia-southeast2` (Jakarta)** — paling dekat dengan user Indonesia,
   dan **tidak bisa diubah setelah dipilih**

### 4b. Authentication

Kode kita butuh `userId`. Sekarang masih hardcode `"demo-user"`.

1. Console → **Build → Authentication → Get started**
2. Tab **Sign-in method** → aktifkan **Anonymous**

Anonymous dipilih karena user bisa langsung pakai app tanpa daftar, tapi datanya sudah
punya pemilik yang jelas. Nanti bisa di-upgrade ke Apple/Google Sign-In tanpa kehilangan
data.

Tambahkan helper ini di `Services/`:

```swift
//
//  AuthService.swift
//  Eco-Habbit
//

import FirebaseAuth

enum AuthService {
    /// Mengembalikan uid user saat ini, membuat akun anonim kalau belum ada.
    static func currentUserId() async throws -> String {
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}
```

---

## 5. Struktur koleksi Firestore

Ini pemetaan dari kode kita ke Firestore. **Ikuti persis** — nama field diambil langsung
dari property model, karena `Codable` yang akan memetakannya otomatis.

### Katalog (publik, read-only)

```
activities/{activityId}          ← activityId = slug, misal "water_shorter_shower"
events/{eventId}                 ← eventId = slug, misal "event_sanur_beach_cleanup"
badges/{badgeId}                 ← badgeId = slug, misal "badge_streak_7"
```

Contoh dokumen `activities/water_shorter_shower`:

```json
{
  "id": "water_shorter_shower",
  "name": "Shorter shower (< 5 min)",
  "category": "water",
  "frictionLevel": "F2",
  "basePoints": 10,
  "evidenceStrength": "contextual",
  "cooldownDays": null
}
```

### Data user (privat)

```
users/{uid}
users/{uid}/activityLogs/{dedupKey}      ← dedupKey = "uid_activityId_2026-08-12"
users/{uid}/eventLogs/{dedupKey}         ← dedupKey = "uid_eventId"
users/{uid}/badges/{badgeId}
```

**Kenapa `dedupKey` jadi document ID, bukan field biasa?**

Karena Firestore menolak dua dokumen dengan ID sama di koleksi yang sama. Jadi
pencatatan ganda **ditolak oleh database**, bukan cuma oleh pengecekan di app. Kalau
user menekan tombol dua kali sangat cepat, atau memakai dua HP sekaligus, duplikatnya
tetap tidak akan pernah terjadi.

Contoh dokumen `users/{uid}/activityLogs/{uid}_water_shorter_shower_2026-08-12`:

```json
{
  "id": "C3CBF922-...",
  "userId": "abc123",
  "activityId": "water_shorter_shower",
  "category": "water",
  "loggedAt": "<Timestamp>",
  "dayKey": "2026-08-12",
  "basePoints": 10,
  "countedBasePoints": 10,
  "evidenceBonus": 1.2,
  "streakMultiplier": 1.35,
  "priorityMultiplier": 1,
  "finalPoints": 16,
  "hasEvidence": true,
  "source": "manualChecklist",
  "provinceCode": null
}
```

---

## 6. Mengisi katalog awal

38 aktivitas, 7 event, dan 15 badge sudah ada di `MockData/`. Jangan ketik ulang di
Console — akan salah ketik dan melelahkan.

**Cara termudah:** buat tombol seeder sementara di app, jalankan sekali, lalu hapus.

```swift
//
//  FirestoreSeeder.swift  — HAPUS setelah dipakai sekali
//

import FirebaseFirestore

enum FirestoreSeeder {

    static func seedCatalog() async throws {
        let db = Firestore.firestore()
        let encoder = Firestore.Encoder()

        // Batch: 500 operasi per batch adalah batas Firestore.
        let batch = db.batch()

        for activity in MockActivityData.all {
            let ref = db.collection("activities").document(activity.id)
            try batch.setData(encoder.encode(activity), forDocument: ref)
        }
        for event in MockEventData.all {
            let ref = db.collection("events").document(event.id)
            try batch.setData(encoder.encode(event), forDocument: ref)
        }
        for badge in MockBadgeData.all {
            let ref = db.collection("badges").document(badge.id)
            try batch.setData(encoder.encode(badge), forDocument: ref)
        }

        try await batch.commit()
        print("Seed selesai: \(MockActivityData.all.count) aktivitas, "
            + "\(MockEventData.all.count) event, \(MockBadgeData.all.count) badge")
    }
}
```

Panggil sekali dari `bootstrap()`, jalankan app, lihat log, lalu **hapus filenya**.

> Saat seeding, Security Rules harus mengizinkan tulis ke katalog. Cara paling aman:
> jalankan seeder **sebelum** memasang rules langkah 7, atau sementara ubah `allow write`
> jadi `if request.auth != null`, lalu kembalikan ke `false` setelah selesai.

---

## 7. Security Rules

Console → **Firestore Database → Rules**, ganti isinya:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Katalog: semua user login boleh baca, tidak ada yang boleh tulis dari app.
    // Perubahan katalog dilakukan dari Console atau Admin SDK.
    match /activities/{activityId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    match /badges/{badgeId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // Data user: hanya pemiliknya.
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /{subcollection=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

Klik **Publish**.

Baris `request.auth.uid == userId` itu yang mencegah user A membaca poin user B.
Tanpa itu, siapa pun yang tahu uid orang lain bisa membaca seluruh riwayatnya.

---

## 8. Menulis FirebaseRepositories.swift

Buat file baru di `Repositories/`. Ini contoh untuk tiga protocol; sisanya polanya sama.

```swift
//
//  FirebaseRepositories.swift
//  Eco-Habbit
//
//  Butuh   : RepositoryProtocols, FirebaseFirestore
//  Dipakai : AppStore
//

import Foundation
import FirebaseFirestore

// MARK: - Katalog aktivitas

struct FirebaseActivityRepository: ActivityRepositoryProtocol {

    private var collection: CollectionReference {
        Firestore.firestore().collection("activities")
    }

    func fetchAllActivities() async throws -> [Activity] {
        let snapshot = try await collection.getDocuments()
        let decoder = Firestore.Decoder()
        return try snapshot.documents.map {
            try decoder.decode(Activity.self, from: $0.data())
        }
    }

    func fetchActivity(id: String) async throws -> Activity? {
        let doc = try await collection.document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(Activity.self, from: data)
    }
}

// MARK: - Log aktivitas

struct FirebaseActivityLogRepository: ActivityLogRepositoryProtocol {

    private func logs(_ userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users").document(userId)
            .collection("activityLogs")
    }

    func fetchLogs(userId: String, dayKey: String) async throws -> [ActivityLog] {
        let snapshot = try await logs(userId)
            .whereField("dayKey", isEqualTo: dayKey)
            .getDocuments()
        return try decode(snapshot)
    }

    func fetchLog(dedupKey: String) async throws -> ActivityLog? {
        // dedupKey berbentuk "userId_activityId_dayKey", jadi userId bisa
        // diambil dari depan — atau simpan userId di service kalau lebih jelas.
        guard let userId = dedupKey.split(separator: "_").first.map(String.init) else {
            return nil
        }
        let doc = try await logs(userId).document(dedupKey).getDocument()
        guard let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(ActivityLog.self, from: data)
    }

    func fetchMostRecentLog(userId: String, activityId: String) async throws -> ActivityLog? {
        let snapshot = try await logs(userId)
            .whereField("activityId", isEqualTo: activityId)
            .order(by: "loggedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        return try decode(snapshot).first
    }

    func fetchAllLogs(userId: String) async throws -> [ActivityLog] {
        let snapshot = try await logs(userId).order(by: "loggedAt").getDocuments()
        return try decode(snapshot)
    }

    func save(_ log: ActivityLog) async throws {
        let data = try Firestore.Encoder().encode(log)
        // Document ID = dedupKey → duplikat mustahil terjadi.
        try await logs(log.userId).document(log.dedupKey).setData(data)
    }

    private func decode(_ snapshot: QuerySnapshot) throws -> [ActivityLog] {
        let decoder = Firestore.Decoder()
        return try snapshot.documents.map {
            try decoder.decode(ActivityLog.self, from: $0.data())
        }
    }
}

// MARK: - UserState

struct FirebaseUserStateRepository: UserStateRepositoryProtocol {

    func fetchUserState(userId: String) async throws -> UserState {
        let doc = try await Firestore.firestore()
            .collection("users").document(userId).getDocument()

        guard let data = doc.data() else {
            // User baru — sama seperti perilaku repository mock.
            return UserState(userId: userId)
        }
        return try Firestore.Decoder().decode(UserState.self, from: data)
    }

    func save(_ state: UserState) async throws {
        let data = try Firestore.Encoder().encode(state)
        try await Firestore.firestore()
            .collection("users").document(state.userId).setData(data, merge: true)
    }
}
```

Sisanya — `FirebaseEventRepository`, `FirebaseEventLogRepository`,
`FirebaseBadgeRepository` — mengikuti pola yang sama persis.

`FirebaseProvincePriorityProvider` belum perlu; fitur provinsi masih ditunda.

---

## 9. Tiga jebakan yang pasti kamu temui

### Jebakan 1: `Activity` gagal di-decode dari katalog

Dokumen katalog tidak menyimpan `hasEvidence` dan `lastCompletedDate` — keduanya milik
progres user, bukan katalog. Tapi `Codable` bawaan **menolak** kalau field non-optional
tidak ada, dan `hasEvidence: Bool` itu non-optional.

**Gejalanya:** `keyNotFound(hasEvidence)` saat fetch aktivitas.

**Perbaikannya**, tambahkan ini ke `Models/Activity.swift`:

```swift
extension Activity {
    /// Dokumen katalog di Firestore tidak menyimpan progres user, jadi dua field
    /// itu diberi nilai default saat tidak ada.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            category: try c.decode(Category.self, forKey: .category),
            frictionLevel: try c.decode(FrictionLevel.self, forKey: .frictionLevel),
            evidenceStrength: try c.decode(EvidenceStrength.self, forKey: .evidenceStrength),
            cooldownDays: try c.decodeIfPresent(Int.self, forKey: .cooldownDays),
            basePoints: try c.decodeIfPresent(Int.self, forKey: .basePoints),
            hasEvidence: try c.decodeIfPresent(Bool.self, forKey: .hasEvidence) ?? false,
            lastCompletedDate: try c.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
        )
    }
}
```

Masalah yang sama berlaku untuk `Badge` (field `isUnlocked`) kalau katalog badge
disimpan tanpa status unlock.

### Jebakan 2: Query butuh index

`fetchMostRecentLog` memakai `whereField` **dan** `order(by:)` sekaligus. Firestore
butuh composite index untuk itu.

**Gejalanya:** error di console berisi tautan panjang ke Firebase Console.

**Perbaikannya:** klik tautan itu, lalu **Create Index**, tunggu beberapa menit. Firebase
sudah mengisikan konfigurasinya untukmu — tidak perlu diketik manual.

### Jebakan 3: `Date` vs `Timestamp`

`Firestore.Encoder` memetakan `Date` ke `Timestamp` secara otomatis, jadi tidak perlu
diapa-apakan. **Tapi** kalau kamu membuat dokumen manual lewat Console, pastikan
tipe fieldnya **timestamp**, bukan string. Dokumen bertipe string akan gagal di-decode.

Ini alasan langkah 6 menyarankan seeder lewat kode, bukan mengetik di Console.

---

## 10. Menukar implementasi di AppStore

Setelah `FirebaseRepositories.swift` jadi, buka `Services/AppStore.swift` dan ganti
enam baris pembuatan repository:

```swift
// SEBELUM
let activityRepository = MockActivityRepository()
let eventRepository = MockEventRepository()
let logRepository = MockActivityLogRepository(store: store)
let eventLogRepository = MockEventLogRepository(store: store)
let userStateRepository = MockUserStateRepository(store: store)
let badgeRepository = MockBadgeRepository(store: store)

// SESUDAH
let activityRepository = FirebaseActivityRepository()
let eventRepository = FirebaseEventRepository()
let logRepository = FirebaseActivityLogRepository()
let eventLogRepository = FirebaseEventLogRepository()
let userStateRepository = FirebaseUserStateRepository()
let badgeRepository = FirebaseBadgeRepository()
```

Lalu ganti userId hardcode:

```swift
// SEBELUM
init(userId: String = "demo-user", ...)

// SESUDAH — panggil di bootstrap()
func bootstrap(now: Date = Date()) async {
    do {
        let uid = try await AuthService.currentUserId()
        // ... pakai uid, bukan "demo-user"
    }
}
```

Dan matikan seed demo:

```swift
seedDemoDataIfEmpty: false
```

**Itu saja.** Tidak ada file di `Views/`, `Components/`, atau `Services/` selain
`AppStore` yang perlu disentuh. Enam service perhitungan tidak berubah sama sekali.

---

## 11. Menguji hasilnya

Urutan pengujian yang disarankan:

1. **Jalankan app** → cek di Console apakah dokumen `users/{uid}` muncul
2. **Tap satu aksi** → cek `users/{uid}/activityLogs/` bertambah satu dokumen
3. **Tap aksi yang sama lagi** → dokumen **tidak** bertambah, poin **tidak** naik
4. **Hapus app, install ulang, buka lagi** → poin masih ada
5. **Install di simulator kedua** dengan akun anonim berbeda → poinnya terpisah,
   tidak saling melihat

Kalau langkah 3 gagal (dokumen bertambah), berarti document ID tidak memakai
`dedupKey` — periksa `save()` di repository log.

Harness pengujian logic yang sudah ada tetap bisa dipakai dengan
`InMemoryKeyValueStore`, karena service-nya tidak tahu-menahu soal Firebase.

---

## 12. Remote Config untuk angka balancing

`PointsConfiguration` sudah `Codable` sejak awal, khusus untuk ini.

1. Console → **Run → Remote Config → Create configuration**
2. Parameter key: `points_configuration`
3. Default value (JSON): salin dari `PointsConfiguration.default`
4. Di app:

```swift
import FirebaseRemoteConfig

let remoteConfig = RemoteConfig.remoteConfig()
try await remoteConfig.fetchAndActivate()

let json = remoteConfig["points_configuration"].dataValue
let config = try JSONDecoder().decode(PointsConfiguration.self, from: json)
let store = AppStore(config: config)
```

Setelah itu kamu bisa mengubah cap harian, tier streak, atau parameter decay
**tanpa update App Store**.

---

## 13. Yang perlu dipikirkan sebelum rilis

**Poin dihitung di HP, bukan di server.** User yang paham teknis bisa memodifikasi app
dan mengirim poin palsu. Untuk aplikasi kebiasaan pribadi ini biasanya dapat diterima.
Tapi kalau nanti poin bisa ditukar hadiah bernilai, pindahkan perhitungannya ke Cloud
Functions — Security Rules saja tidak cukup, karena rules tidak bisa menghitung
`base × evidence × streak`.

**Kuota gratis Firestore** 50.000 baca dan 20.000 tulis per hari. Satu user aktif
memakai sekitar 5–15 tulis per hari, jadi masih sangat longgar untuk fase awal.
Yang boros justru **baca katalog**: 38 aktivitas dibaca setiap kali layar dibuka.
Solusinya aktifkan offline persistence supaya katalog di-cache:

```swift
let settings = FirestoreSettings()
settings.cacheSettings = PersistentCacheSettings()
Firestore.firestore().settings = settings
```

**Akun anonim bisa hilang** kalau user menghapus app. Sebelum rilis, tambahkan
Sign in with Apple dan tautkan ke akun anonim yang ada — `Auth.auth().currentUser?.link(with:)`
— supaya progres tidak hilang saat ganti HP.

**`GoogleService-Info.plist` jangan masuk repo publik.**

---

## Ringkasan

| Langkah | Hasil |
|---|---|
| 2–3 | Project Firebase terhubung ke Xcode |
| 4 | Firestore + Auth anonim aktif |
| 5–6 | Struktur koleksi dan katalog terisi |
| 7 | Data tiap user terlindungi |
| 8–9 | `FirebaseRepositories.swift` jadi |
| 10 | Enam baris ditukar di `AppStore` |
| 11 | Terbukti jalan |

Yang **tidak** berubah sepanjang panduan ini: seluruh `Views/`, seluruh `Components/`,
`PointsCalculationService`, `StreakService`, `DecayService`, `BadgeEvaluationService`,
`ActivityLoggingService`, dan `EventClaimService`.

Itulah gunanya protocol repository dibuat sejak awal.
