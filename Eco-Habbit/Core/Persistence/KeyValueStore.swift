//
//  KeyValueStore.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : —
//  Dipakai : semua repository di Repositories/
//

import Foundation

/// Penyimpanan Codable sederhana. Semua method `async` supaya implementasi
/// berbasis actor tidak perlu lock, dan supaya bentuknya sama dengan
/// repository yang nanti memanggil Firebase.
///
/// `T: Sendable` wajib, bukan opsional: nilainya melewati batas actor, dan tanpa
/// constraint ini Swift 6 menolak compile.
protocol KeyValueStoring: Sendable {
    func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?
    func save<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws
    func removeValue(forKey key: String) async throws
}

/// Menyimpan satu file JSON per key di Application Support.
///
/// Dipilih ketimbang UserDefaults karena isinya array log yang bisa tumbuh ribuan
/// entry; UserDefaults dimuat seluruhnya ke memori saat app start dan bukan tempat
/// untuk data sebesar itu.
nonisolated struct LocalJSONFileStore: KeyValueStoring {

    let directoryURL: URL

    /// Strategi tanggal `.iso8601` dipakai konsisten di encoder dan decoder.
    /// Default `.deferredToDate` menyimpan angka epoch yang tidak terbaca saat
    /// debug, dan ISO8601 juga yang dipakai Firestore untuk timestamp string.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Default menunjuk ke Application Support/SustainabilityTracker.
    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("SustainabilityTracker",
                                                            isDirectory: true)
        }
    }

    private func fileURL(forKey key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).json")
    }

    func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        let url = fileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let data = try Data(contentsOf: url)
        return try LocalJSONFileStore.makeDecoder().decode(T.self, from: data)
    }

    func save<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws {
        try FileManager.default.createDirectory(at: directoryURL,
                                                withIntermediateDirectories: true)

        let data = try LocalJSONFileStore.makeEncoder().encode(value)

        // `.atomic` menulis ke file sementara lalu me-rename. Tanpa itu, app yang
        // ditutup paksa di tengah penulisan meninggalkan JSON terpotong yang
        // gagal di-decode — seluruh riwayat user hilang, bukan cuma entry terakhir.
        try data.write(to: fileURL(forKey: key), options: .atomic)
    }

    func removeValue(forKey key: String) async throws {
        let url = fileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

/// Penyimpanan di memori untuk test dan SwiftUI preview.
///
/// Data tetap di-encode ke JSON meski tidak menyentuh disk, supaya test ikut
/// melewati jalur Codable yang sama seperti produksi — model yang gagal
/// di-serialize akan tertangkap di test, bukan setelah rilis.
actor InMemoryKeyValueStore: KeyValueStoring {

    private var storage: [String: Data] = [:]

    init() {}

    func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    func save<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        storage[key] = try encoder.encode(value)
    }

    func removeValue(forKey key: String) async throws {
        storage[key] = nil
    }
}
