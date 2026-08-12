# Kode yang disimpan tapi belum dipakai

Folder ini **di luar sync root Xcode** (`Eco-Habbit/`), jadi isinya tidak ikut
dikompilasi. File tetap `.swift` supaya syntax highlighting dan pencarian tetap jalan,
dan tetap masuk git supaya tidak hilang.

## BlobShape.swift + EarthGlobeView.swift

Bumi yang digambar sepenuhnya dengan kode SwiftUI, lengkap dengan aturan tampilan
per `EarthStage`: warna daratan berubah dari coklat kering ke hijau subur, lalu tunas,
pohon, dan tiga maskot muncul bertahap seiring naiknya stage.

**Kenapa tidak dipakai:** siluetnya tidak menyerupai ilustrasi bumi dari Sketch.
Bentuk benuanya dikarang dari nol karena `earth.svg` isinya PNG raster — tidak ada
outline vector yang bisa dijiplak. Untuk sekarang Dashboard memakai asset `earth`
langsung supaya tampilannya sesuai desain.

**Kapan ini berguna lagi:** kalau nanti bumi perlu berubah bentuk mengikuti stage,
bukan sekadar berganti gambar. Logika `EarthGlobeView.Appearance` bisa dipakai ulang
apa adanya — yang perlu diganti hanya sumber gambarnya, dari `BlobShape` menjadi
asset vector berlapis per elemen.

## Cara mengaktifkan kembali

Pindahkan kedua file ke `Eco-Habbit/Eco-Habbit/DesignSystem/`. Xcode akan otomatis
memasukkannya ke target karena folder itu disinkronkan — tidak perlu menyentuh
project.pbxproj. Lalu di `DashboardView`, ganti `Image(Tokens.Icons.earth)` kembali
menjadi `EarthGlobeView(stage:)`.
