// CacheStore.swift
// Signal
//
// Created by Vishal Bhogal on 27/04/26.
// Generic caching protocol + three concrete implementations:
//   MemoryCache   — NSCache (RAM only, volatile)
//   DiskCache     — FileManager + JSON (persistent)
//   TwoLevelCache — L1 memory → L2 disk waterfall
//
// Every read and write is logged via os.Logger so you can watch the exact
// hit/miss path live in Xcode's console (Console.app filter: "Cache").

import Foundation
import os

private let cacheLog = Logger(subsystem: "com.signal", category: "Cache")

// MARK: - Protocol
protocol CacheStore {
    associatedtype Key: Hashable
    associatedtype Value: Codable

    func set(_ value: Value, forKey key: Key)
    func get(forKey key: Key) -> Value?
    func remove(forKey key: Key)
    func clear()
}

// MARK: - Memory Cache

final class MemoryCache<Key: Hashable, Value: Codable>: CacheStore {

    private let cache = NSCache<WrappedKey, WrappedValue>()

    // `name` labels this cache in logs so you can tell visit vs badge caches apart.
    private let name: String

    init(name: String = "unnamed", countLimit: Int = 100) {
        self.name = name
        cache.countLimit = countLimit
        cache.name = "com.signal.memory.\(name)"
    }

    func set(_ value: Value, forKey key: Key) {
        cache.setObject(WrappedValue(value), forKey: WrappedKey(key))
        cacheLog.debug("  [Memory:\(self.name)] WRITE  key='\(String(describing: key))'")
    }

    func get(forKey key: Key) -> Value? {
        if let hit = cache.object(forKey: WrappedKey(key))?.value {
            cacheLog.debug("  [Memory:\(self.name)] HIT    key='\(String(describing: key))'")
            return hit
        }
        cacheLog.debug("  [Memory:\(self.name)] MISS   key='\(String(describing: key))'")
        return nil
    }

    func remove(forKey key: Key) {
        cache.removeObject(forKey: WrappedKey(key))
        cacheLog.debug("  [Memory:\(self.name)] REMOVE key='\(String(describing: key))'")
    }

    func clear() {
        cache.removeAllObjects()
        cacheLog.info("  [Memory:\(self.name)] CLEARED all entries")
    }
}

// MARK: - NSCache Wrapper Helpers
// NSCache only accepts AnyObject keys and values, not plain structs.
// These thin wrappers box our generic types into reference types.

private extension MemoryCache {

    final class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else { return false }
            return key == other.key
        }
    }

    final class WrappedValue: NSObject {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
}

// MARK: - Disk Cache

/// Persistent cache that serializes values as JSON files on disk via FileManager.
/// Survives app restarts and NSCache evictions. Slower than MemoryCache.
///
/// Each key → one JSON file:
///   ~/Library/Caches/<namespace>/visitCount.json
///   ~/Library/Caches/<namespace>/earnedIDs.json
final class DiskCache<Key: Hashable & CustomStringConvertible, Value: Codable>: CacheStore {

    private let directory: URL
    private let name: String

    init(namespace: String) {
        self.name = namespace
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent(namespace)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheLog.info("  [Disk:\(namespace)] directory → \(self.directory.path)")
    }

    func set(_ value: Value, forKey key: Key) {
        let url = fileURL(for: key)
        guard let data = try? JSONEncoder().encode(value) else {
            cacheLog.error("  [Disk:\(self.name)] ENCODE FAILED  key='\(String(describing: key))'")
            return
        }
        try? data.write(to: url, options: .atomic)
        cacheLog.debug("  [Disk:\(self.name)]  WRITE  key='\(String(describing: key))'  \(data.count) bytes → \(url.lastPathComponent)")
    }

    func get(forKey key: Key) -> Value? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else {
            cacheLog.debug("  [Disk:\(self.name)]  MISS   key='\(String(describing: key))'  (file not found: \(url.lastPathComponent))")
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            cacheLog.error("  [Disk:\(self.name)]  READ FAILED  key='\(String(describing: key))'  path=\(url.path)")
            return nil
        }
        guard let value = try? JSONDecoder().decode(Value.self, from: data) else {
            cacheLog.error("  [Disk:\(self.name)]  DECODE FAILED  key='\(String(describing: key))'  \(data.count) bytes (corrupt file?)")
            return nil
        }

        cacheLog.debug("  [Disk:\(self.name)]  HIT    key='\(String(describing: key))'  \(data.count) bytes ← \(url.lastPathComponent)")
        return value
    }

    func remove(forKey key: Key) {
        let url = fileURL(for: key)
        try? FileManager.default.removeItem(at: url)
        cacheLog.debug("  [Disk:\(self.name)]  REMOVE key='\(String(describing: key))'  deleted \(url.lastPathComponent)")
    }

    func clear() {
        try? FileManager.default.removeItem(at: self.directory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        cacheLog.info("  [Disk:\(self.name)]  CLEARED all files in \(self.directory.lastPathComponent)/")
    }

    private func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(key).json")
    }
}

// MARK: - Two-Level Cache
//
// ─────────────────────────────────────────────────────────────────────────────
// L1/L2 architecture — same idea as a CPU cache hierarchy:
//
//   L1 — MemoryCache (NSCache)
//        • Microsecond reads — plain RAM lookup, no I/O
//        • Volatile — gone when the app is killed or under memory pressure
//
//   L2 — DiskCache (FileManager + JSON)
//        • Millisecond reads — disk read + JSON decode
//        • Persistent — survives app restarts
//
// READ waterfall (checked in order):
//   L1 hit  → return immediately, no disk I/O              [fastest]
//   L1 miss → L2 hit  → warm L1, return                   [one disk read]
//   L1 miss → L2 miss → return nil, caller uses default    [cold start]
//
// WRITE: always writes to both levels simultaneously.
// ─────────────────────────────────────────────────────────────────────────────

final class TwoLevelCache<Key: Hashable & CustomStringConvertible, Value: Codable>: CacheStore {

    private let memory: MemoryCache<Key, Value>
    private let disk: DiskCache<Key, Value>
    private let name: String

    init(namespace: String, memoryCountLimit: Int = 100) {
        self.name   = namespace
        self.memory = MemoryCache(name: "\(namespace).mem", countLimit: memoryCountLimit)
        self.disk   = DiskCache(namespace: namespace)
    }

    // MARK: - Write

    func set(_ value: Value, forKey key: Key) {
        cacheLog.info("📝 [Cache:\(self.name)] SET key='\(String(describing: key))'")
        memory.set(value, forKey: key)  // L1
        disk.set(value, forKey: key)    // L2
    }

    // MARK: - Read (the interesting part)

    func get(forKey key: Key) -> Value? {
        cacheLog.info("🔍 [Cache:\(self.name)] GET key='\(String(describing: key))'")

        // ── Step 1: L1 Memory ────────────────────────────────────────────────
        // NSCache lookup — O(1), no I/O, thread-safe.
        if let value = memory.get(forKey: key) {
            cacheLog.info("✅ [Cache:\(self.name)] L1 HIT  key='\(String(describing: key))' (memory — no disk I/O)")
            return value
        }

        // ── Step 2: L2 Disk ──────────────────────────────────────────────────
        // L1 had nothing. Try FileManager: check file exists → read bytes → decode JSON.
        if let value = disk.get(forKey: key) {
            // Promote to L1 so the next read this session is a fast memory hit.
            memory.set(value, forKey: key)
            cacheLog.info("📂 [Cache:\(self.name)] L2 HIT  key='\(String(describing: key))' (disk → L1 warmed)")
            return value
        }

        // ── Step 3: Total miss ────────────────────────────────────────────────
        // Data doesn't exist in either level. Caller must supply a default.
        cacheLog.info("❌ [Cache:\(self.name)] MISS    key='\(String(describing: key))' (not in memory or disk)")
        return nil
    }

    // MARK: - Remove / Clear

    func remove(forKey key: Key) {
        cacheLog.info("🗑 [Cache:\(self.name)] REMOVE key='\(String(describing: key))'")
        memory.remove(forKey: key)
        disk.remove(forKey: key)
    }

    func clear() {
        cacheLog.info("🧹 [Cache:\(self.name)] CLEAR all")
        memory.clear()
        disk.clear()
    }
}
