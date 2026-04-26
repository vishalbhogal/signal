// CacheStore.swift
// Signal
//
// Generic caching protocol. Any concrete cache (memory or disk)
// must conform to this. The `Key` and `Value` generics mean one
// protocol definition works for any data type — no copy-paste.

import Foundation

// MARK: - Protocol

/// A type-safe read/write cache keyed by any Hashable type.
/// Generic constraints:
///   Key   — must be Hashable so it can be used in dictionaries
///   Value — must be Codable so MemoryCache and DiskCache can serialize it
protocol CacheStore {
    associatedtype Key: Hashable
    associatedtype Value: Codable

    /// Store a value. Replaces existing entry for the same key.
    func set(_ value: Value, forKey key: Key)

    /// Retrieve a value. Returns nil if key not found or entry expired.
    func get(forKey key: Key) -> Value?

    /// Remove a single entry.
    func remove(forKey key: Key)

    /// Wipe the entire cache (e.g. on logout).
    func clear()
}

// MARK: - Memory Cache

/// Fast in-memory cache backed by NSCache.
/// NSCache automatically evicts entries under memory pressure —
/// safer than a plain dictionary, which would grow unbounded.
final class MemoryCache<Key: Hashable, Value: Codable>: CacheStore {

    // NSCache requires AnyObject keys/values, so we wrap our types.
    private let cache = NSCache<WrappedKey, WrappedValue>()

    /// Limit how many objects NSCache holds before it starts evicting.
    init(countLimit: Int = 100) {
        cache.countLimit = countLimit
    }

    func set(_ value: Value, forKey key: Key) {
        cache.setObject(WrappedValue(value), forKey: WrappedKey(key))
    }

    func get(forKey key: Key) -> Value? {
        return cache.object(forKey: WrappedKey(key))?.value
    }

    func remove(forKey key: Key) {
        cache.removeObject(forKey: WrappedKey(key))
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - NSCache Wrapper Helpers
// NSCache only accepts AnyObject keys and values, not plain structs.
// These thin wrappers box our generic types into reference types.

private extension MemoryCache {

    /// Boxes our Hashable key into a reference type for NSCache.
    final class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }

        // NSCache uses hash + isEqual for key lookup.
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else { return false }
            return key == other.key
        }
    }

    /// Boxes our Codable value into a reference type for NSCache.
    final class WrappedValue: NSObject {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
}

// MARK: - Disk Cache

/// Persistent cache that serializes values as JSON files in the Caches directory.
/// Survives app restarts. Slower than MemoryCache — use for larger datasets.
final class DiskCache<Key: Hashable & CustomStringConvertible, Value: Codable>: CacheStore {

    // The folder where cache files are written.
    private let directory: URL

    init(namespace: String) {
        // Caches directory is the correct place for re-creatable data.
        // The OS can clear it under storage pressure — don't put critical data here.
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent(namespace)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func set(_ value: Value, forKey key: Key) {
        let url = fileURL(for: key)
        // JSONEncoder converts the Codable struct into Data, then we write to disk.
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
        // .atomic writes to a temp file first, then renames — prevents partial writes.
    }

    func get(forKey key: Key) -> Value? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // JSONDecoder reconstructs the struct from the raw bytes on disk.
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func remove(forKey key: Key) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Each key maps to a unique filename using the key's string description.
    private func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(key).json")
    }
}
